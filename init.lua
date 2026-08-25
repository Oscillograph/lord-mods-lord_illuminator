-- Heavily inspired by https://github.com/mt-mods/illumination
-- Light source can be created only in place of "air" node. Otherwise it will cause problems gameplay-wise.
-- Light source operation must be light for the server.

local lord_illuminator = {}			-- the mod namespace

lord_illuminator.time_step = 0.2 		-- how often light sources should be updated
lord_illuminator.light_lifetime = 0.5 	-- how long light sources live in seconds

-- local database designed for search in O(1)
local player_light_level = {}		-- indexed by player name, updated on timer
local player_handles_light = {}		-- indexed by player name, boolean, updated on timer
local player_positions = {}			-- indexed by player name
local player_force_update = {}		-- indexed by player_name, updated once in light_update()
local light_positions = {} 			-- indexed by player name
lord_illuminator.time_passed = 0	-- local timer, cleaned up everytime it reaches lord_illuminator.time_step

lord_illuminator.light_create = function(pos, player)
	local node_name = core.get_node(pos).name
	if node_name ~= "air" then
		return 
	end
end

lord_illuminator.can_replace_node = function(pos)
	local node_name = core.get_node(pos).name
	if node_name then
		-- only air is acceptable for replacement
		if node_name == "air" then
			return true
		end
		-- we can replace our own light source
		-- TODO: make sure 2 or more players' light sources don't conflict here
		if core.get_item_group(node_name, "lord_illuminator_light") > 0 then
			return true
		end
	end
	-- cannot replace a node by default. Period.
	return false
end

lord_illuminator.player_wields_light = function(player)
	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	-- make sure player holds an item that provides illumination
	local item = player:get_wielded_item():get_name()
	local item_def = core.registered_items[item]
	if item_def then
		if item_def.light_source then
			-- player has just switched an item!
			if player_handles_light[player_name] == false or player_light_level[player_name] ~= item_def.light_source then
				player_force_update[player_name] = true
			end
			
			player_handles_light[player_name] = true
			player_light_level[player_name] = item_def.light_source
		else
			player_handles_light[player_name] = false
		end
	else
		-- undefined item is not a light source
		player_handles_light[player_name] = false
	end

	return player_handles_light[player_name]
end

lord_illuminator.light_get_name = function(player)
	local player_name = player:get_player_name()

	-- maximum light is 15 - Sun level
	if player_light_level[player_name] > 15 then
		player_light_level[player_name] = 15
		return "lord_illuminator:light_15"
	end
	if player_light_level[player_name] < 1 then
		player_light_level[player_name] = 0
		return nil
	end
	
	return "lord_illuminator:light_"..player_light_level[player_name]
end

lord_illuminator.light_get_pos = function(pos)
	-- can replace at feet?
	if lord_illuminator.can_replace_node(pos) then
		return pos
	end

	-- can replace at head?
	pos.y = pos.y + 1
	if lord_illuminator.can_replace_node(pos) then
		return pos
	end

	-- can replace nearby?
	-- TODO: make sure 2 or more players' light sources don't conflict here
	return core.find_node_near(pos, 1, {"air", "group:lord_illuminator_light"})
end

lord_illuminator.light_remove = function(pos, player)
	if pos then
		if core.get_item_group(core.get_node(pos).name, "lord_illuminator_light") > 0 then
			-- if light sources are to vanish instantly
			if not lord_illuminator.light_lifetime or lord_illuminator.light_lifetime == 0 then
				core.set_node(pos, {name = "air"})
				return
			end

			-- if light sources have a lifetime
			core.get_node_timer(pos):start(lord_illuminator.light_lifetime)
		end
	end
end

lord_illuminator.light_update = function(player, time_step)
	local player_name = player:get_player_name()

	-- if the player has just logged in
	if not player_positions[player_name] then
		player_positions[player_name] = player:get_pos()

		return
	end

	-- if player has no light yet
	if not lord_illuminator.player_wields_light(player) then
		if light_positions[player_name] then
			lord_illuminator.light_remove(light_positions[player_name], player)
			light_positions[player_name] = nil
		end

		return
	end

	local light_name = lord_illuminator.light_get_name(player)

	local pos_old = player_positions[player_name]
	local pos_new = vector.round(vector.add(player:get_pos(), vector.multiply(player:get_velocity(), 2*time_step)))

	if pos_old and pos_new and light_name then
		if light_name == core.get_node(pos_new).name then
			return
		end

		-- player didn't move - why?
		if vector.equals(pos_new, pos_old) then
			-- just logged in - it's ok
			if player_force_update[player_name] then
				player_force_update[player_name] = false
			else
				return
			end
		end

		-- proceed with light update
		player_positions[player_name] = pos_new
		local light_pos = lord_illuminator.light_get_pos(pos_new)
		if light_pos then
			-- place light node
			core.set_node(light_pos, {name = light_name})
--			core.log("action", player_name.." is bound to "..light_name.." at ("..light_pos.x.."; "..light_pos.y.."; "..light_pos.z..")")
			-- prevent light node from vanishing while player is at its pos
			core.get_node_timer(light_pos):stop()

			-- remove light node the player left behind
			if light_positions[player_name] and not vector.equals(light_positions[player_name], light_pos) then
				lord_illuminator.light_remove(light_positions[player_name], player)
			end
			
			light_positions[player_name] = light_pos
			return
		end
	end

	-- suppose there is no light left with the player
	lord_illuminator.light_remove(pos_old)
	light_positions[player_name] = nil
end

lord_illuminator.light_timeout = function(pos)
	core.set_node(pos, {name = "air"})
end

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

core.register_globalstep(function(time_step)
	lord_illuminator.time_passed = lord_illuminator.time_passed + time_step
	if lord_illuminator.time_passed > lord_illuminator.time_step then
		lord_illuminator.time_passed = 0
		for _, player in pairs(core.get_connected_players()) do
			lord_illuminator.light_update(player, time_step)
		end
	end
end)

core.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	if not player_positions[player_name] then
		player_positions[player_name] = player:get_pos()
		player_force_update[player_name] = true
	end
end)

core.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	if light_positions[player_name] then
		lord_illuminator.light_remove(light_positions[player_name])
	end
	light_positions[player_name] = nil
end)

-- cleanup unneeded light sources
core.register_lbm({
	label = "lord_illuminator light sources removal",
	name = "lord_illuminator:cleanup",
	nodenames = {"group:lord_illuminator_light"},
	run_at_every_load = true,
	action = function(pos)
		core.set_node(pos, {name = "air"})
	end,
})