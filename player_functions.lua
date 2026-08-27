-----------------------------------------------------------
-- PLAYER LIGHTS TRACKING AND PROCESSING

-- should be called when a player is leaving game to properly remove light and free space in the mod's database
lord_illuminator.clean_up = function(player)
	local player_name = player:get_player_name()
	
	if lord_illuminator.player_light_positions[player_name] then
		lord_illuminator.light_remove(lord_illuminator.player_light_positions[player_name])
		lord_illuminator.player_light_positions[player_name] = nil
	end

	if lord_illuminator.player_positions[player_name] then
		lord_illuminator.player_positions[player_name] = nil
	end
	
	if lord_illuminator.player_handles_light[player_name] then
		lord_illuminator.player_handles_light[player_name] = nil
	end
	
	if lord_illuminator.player_light_level[player_name] then
		lord_illuminator.player_light_level[player_name] = nil
	end
	
	if lord_illuminator.player_force_update[player_name] then
		lord_illuminator.player_force_update[player_name] = nil
	end
end

-- return true		if item is a light source
-- return false		if item is not a light source
lord_illuminator.player_wields_light = function(player)
	local player_name = player:get_player_name()
	local player_pos = player:get_pos()

	-- make sure player holds an item that has luminance
	local item = player:get_wielded_item():get_name()
	if item then
		local item_def = core.registered_items[item]
		if item_def then
			if item_def.light_source then
				-- Situation: player has just switched an item!
				if lord_illuminator.player_handles_light[player_name] == false or lord_illuminator.player_light_level[player_name] ~= item_def.light_source then
					lord_illuminator.player_force_update[player_name] = true
				end

				lord_illuminator.player_handles_light[player_name] = true
				lord_illuminator.player_light_level[player_name] = item_def.light_source
			else
				lord_illuminator.player_handles_light[player_name] = false
			end
		else
			-- undefined item is not a light source
			lord_illuminator.player_handles_light[player_name] = false
		end
	else
		-- no item
		lord_illuminator.player_handles_light[player_name] = false
	end

	return lord_illuminator.player_handles_light[player_name]
end

-- return string that is a registered lord_illuminator's light source name
-- return nil if no light source available (light level 0)
lord_illuminator.light_get_name = function(player)
	local player_name = player:get_player_name()

	-- maximum light is 15 - Sun level
	if lord_illuminator.player_light_level[player_name] > 15 then
		lord_illuminator.player_light_level[player_name] = 15
		return "lord_illuminator:light_15"
	end
	if lord_illuminator.player_light_level[player_name] < 1 then
		lord_illuminator.player_light_level[player_name] = 0
		return nil
	end

	return "lord_illuminator:light_"..lord_illuminator.player_light_level[player_name]
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

-- main cycle for players
lord_illuminator.player_light_update = function(player, time_step)
	local player_name = player:get_player_name()

	-- situation: if the player has just logged in we should only register initial coordinates
	if not lord_illuminator.player_positions[player_name] then
		lord_illuminator.player_positions[player_name] = player:get_pos()
		return
	end

	-- situation: if player has no light we should not update it
	if not lord_illuminator.player_wields_light(player) then
		if lord_illuminator.player_light_positions[player_name] then
			lord_illuminator.light_remove(lord_illuminator.player_light_positions[player_name])
			lord_illuminator.player_light_positions[player_name] = nil
		end
		return
	end

	-- where the player has been before
	local pos_old = lord_illuminator.player_positions[player_name]
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
			if lord_illuminator.player_light_positions[player_name] then
				if light_pos == lord_illuminator.player_light_positions[player_name] then
					lord_illuminator.player_force_update[player_name] = true
				end
			end
		end

		-- situation: player didn't move
		if vector.equals(pos_new, pos_old) then
			if lord_illuminator.player_force_update[player_name] then
				lord_illuminator.player_force_update[player_name] = false
			else
				return
			end
		end

		-- proceed with light update
		lord_illuminator.player_positions[player_name] = pos_new
		lord_illuminator.light_create(light_pos, light_name)

		-- remove light node the player has left behind
		if lord_illuminator.player_light_positions[player_name] then
			if not vector.equals(lord_illuminator.player_light_positions[player_name], light_pos) then
				lord_illuminator.light_remove(lord_illuminator.player_light_positions[player_name])
			end
		end

		lord_illuminator.player_light_positions[player_name] = light_pos
		return
	end

	-- default behaviour: remove light at the player position and clean up
	-- suppose there is no light left with the player
	lord_illuminator.light_remove(pos_old)
	lord_illuminator.player_light_positions[player_name] = nil
end
