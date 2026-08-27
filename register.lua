-- glue the mod logic to the game engine API
core.register_globalstep(function(time_step)
	lord_illuminator.time_passed = lord_illuminator.time_passed + time_step
	if lord_illuminator.time_passed > lord_illuminator.time_step then
		lord_illuminator.time_passed = 0
		for _, player in pairs(core.get_connected_players()) do
			lord_illuminator.player_light_update(player, time_step)
		end
	end
end)

if lord_illuminator.enable_entities then
	core.register_globalstep(function(time_step)
		lord_illuminator.time_passed = lord_illuminator.time_passed + time_step
		if lord_illuminator.time_passed > lord_illuminator.time_step then
			lord_illuminator.time_passed = 0
			lord_illuminator.entities_light_update(time_step)
		end
	end)
end

core.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	if not lord_illuminator.player_positions[player_name] then
		lord_illuminator.player_positions[player_name] = player:get_pos()
		lord_illuminator.player_force_update[player_name] = true
	end
end)

core.register_on_leaveplayer(function(player)
	lord_illuminator.clean_up(player)
end)

core.register_lbm({
	label = "lord_illuminator light sources removal",
	name = "lord_illuminator:cleanup",
	nodenames = {"group:lord_illuminator_light"},
	run_at_every_load = true,
	action = function(pos)
		core.set_node(pos, {name = "air"})
	end,
})


-- register light sources for every light level
for i = 1, 15 do
	core.register_node("lord_illuminator:light_"..i, {
		drawtype = "airlike",
		paramtype = "light",
		light_source = i,
		sunlight_propagates = true,
		walkable = false,
		pointable = false,
		buildable_to = true,
		groups = {
			not_in_creative_inventory = 1,
			not_blocking_trains = 1,
			lord_illuminator_light = 1,
		},
		drop = "",
		on_timer = lord_illuminator.light_timeout,
	})
end
