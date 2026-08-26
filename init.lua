-- Heavily inspired by https://github.com/mt-mods/illumination
-- Light source can be created only in place of "air" node. Otherwise it will cause problems gameplay-wise.

lord_illuminator = {}			-- the mod namespace

lord_illuminator.time_step = 0.2 		-- how often light sources should be updated
lord_illuminator.light_lifetime = 0.5 	-- how long light sources live in seconds

-- internal database
local player_light_level = {}		-- indexed by player name, updated on timer
local player_handles_light = {}		-- indexed by player name, boolean, updated on timer
local player_force_update = {}		-- indexed by player_name, updated once in light_update()
local player_positions = {}			-- indexed by player name, updated regularly in light_update()
local light_positions = {} 			-- indexed by player name, updated regularly in light_update()
lord_illuminator.time_passed = 0	-- local timer, cleaned up everytime it reaches lord_illuminator.time_step


-- create a light source node with given name "light_name" at a given position "pos"
lord_illuminator.light_create = function(light_pos, light_name)
	local node_name = core.get_node(light_pos).name
	if node_name ~= "air" and core.get_item_group(node_name, "lord_illuminator_light") == 0 then
		return 
	end

	core.set_node(light_pos, {name = light_name})
	-- prevent light node from vanishing right after it has been placed
	core.get_node_timer(light_pos):stop()
end

-- remove a light source node at given position "pos"
lord_illuminator.light_remove = function(pos)
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

-- should be called when a player is leaving game to properly remove light and free space in the mod's database
lord_illuminator.clean_up = function(player)
	local player_name = player:get_player_name()
	
	if light_positions[player_name] then
		lord_illuminator.light_remove(light_positions[player_name])
		light_positions[player_name] = nil
	end

	if player_positions[player_name] then
		player_positions[player_name] = nil
	end
	
	if player_handles_light[player_name] then
		player_handles_light[player_name] = nil
	end
	
	if player_light_level[player_name] then
		player_light_level[player_name] = nil
	end
	
	if player_force_update[player_name] then
		player_force_update[player_name] = nil
	end
end

-- return true		if node can be replaced by lord_illuminator:light_X (where X is a number)
-- return false		if otherwise
lord_illuminator.can_replace_node = function(pos)
	local node_name = core.get_node(pos).name
	if node_name then
		-- only air is acceptable for replacement
		if node_name == "air" then
			return true
		end
		-- can replace lord_illuminator's light source
		if core.get_item_group(node_name, "lord_illuminator_light") > 0 then
			return true
		end
	end
	-- cannot replace a node by default. Period.
	return false
end

-- return true		if item wielded is a light source
-- return false		if item wielded is not a light source
lord_illuminator.player_wields_light = function(player)
	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	-- make sure player holds an item that provides illumination
	local item = player:get_wielded_item():get_name()
	if item then
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
	else
		-- no item
		player_handles_light[player_name] = false
	end

	return player_handles_light[player_name]
end

-- return string that is a registered lord_illuminator's light source name
-- return nil if no light source available (light level 0)
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

-- return node position suitable for replacement with a light source node
lord_illuminator.light_get_pos = function(player_pos)
	-- can replace at feet?
	if lord_illuminator.can_replace_node(player_pos) then
		return player_pos
	end

	-- can replace at head?
	player_pos.y = player_pos.y + 1
	if lord_illuminator.can_replace_node(player_pos) then
		return player_pos
	end

	-- can replace somewhere near head?
	return core.find_node_near(player_pos, 1, {"air", "group:lord_illuminator_light"})
end

-- main cycle
lord_illuminator.light_update = function(player, time_step)
	local player_name = player:get_player_name()

	-- situation: if the player has just logged in we should only register initial coordinates
	if not player_positions[player_name] then
		player_positions[player_name] = player:get_pos()
		return
	end

	-- situation: if player has no light we should not update it
	if not lord_illuminator.player_wields_light(player) then
		if light_positions[player_name] then
			lord_illuminator.light_remove(light_positions[player_name])
			light_positions[player_name] = nil
		end
		return
	end

	-- where the player has been before
	local pos_old = player_positions[player_name]
	-- where the player is right now
--	local pos_new = player:get_pos() -- makes light flicker when source is being changed
	local pos_new = vector.round(vector.add(player:get_pos(), vector.multiply(player:get_velocity(), 2*time_step)))
	-- what light should be placed
	local light_name = lord_illuminator.light_get_name(player)
	-- where light should be placed
	local light_pos = lord_illuminator.light_get_pos(pos_new)

	-- nowhere to place light - no need to proceed at all
	if not light_pos then
		return
	end

	if pos_old and pos_new and light_name then
		-- situation A: light node is present already - no need to proceed
		if light_name == core.get_node(light_pos).name then
			return
		else
			-- situation B: light node has been removed for some reason (by another player movement, for example)
			-- need to ignore vector.equals(pos_new, pos_old) condition below
			if light_positions[player_name] then
				if light_pos == light_positions[player_name] then
					player_force_update[player_name] = true
				end
			end
		end

		-- situation: player didn't move
		if vector.equals(pos_new, pos_old) then
			if player_force_update[player_name] then
				player_force_update[player_name] = false
			else
				return
			end
		end

		-- proceed with light update
		player_positions[player_name] = pos_new
		lord_illuminator.light_create(light_pos, light_name)

		-- remove light node the player has left behind
		if light_positions[player_name] then
			if not vector.equals(light_positions[player_name], light_pos) then
				lord_illuminator.light_remove(light_positions[player_name])
			end
		end

		light_positions[player_name] = light_pos
		return
	end

	-- default behaviour: remove light at the player position and clean up
	-- suppose there is no light left with the player
	lord_illuminator.light_remove(pos_old)
	light_positions[player_name] = nil
end

-- remove light which lifetime has ended - it is a light that is tracked only by the game engine
lord_illuminator.light_timeout = function(pos)
	core.set_node(pos, {name = "air"})
end


-- glue the mod logic to the game engine API
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