-----------------------------------------------------------
-- ENTITY LIGHTS TRACKING AND PROCESSING

-- generally should be called when an entity lost its light or has been destroyed
lord_illuminator.entity_clean_up = function(guid)
	if lord_illuminator.entity_collection[guid] then
		lord_illuminator.entity_collection[guid] = nil
	end
	
	if lord_illuminator.entity_light_positions[guid] then
		lord_illuminator.light_remove(lord_illuminator.entity_light_positions[guid])
		lord_illuminator.entity_light_positions[guid] = nil
	end

	if lord_illuminator.entity_positions[guid] then
		lord_illuminator.entity_positions[guid] = nil
	end
	
	if lord_illuminator.entity_handles_light[guid] then
		lord_illuminator.entity_handles_light[guid] = nil
	end
	
	if lord_illuminator.entity_light_level[guid] then
		lord_illuminator.entity_light_level[guid] = nil
	end
	
	if lord_illuminator.entity_force_update[guid] then
		lord_illuminator.entity_force_update[guid] = nil
	end
end

-- return string that is a registered lord_illuminator's light source name
-- return nil if no light source available (light level 0)
lord_illuminator.entity_light_get_name = function(guid)
	-- maximum light is 15 - Sun level
	if lord_illuminator.entity_light_level[guid] > 15 then
		lord_illuminator.entity_light_level[guid] = 15
		return "lord_illuminator:light_15"
	end
	if lord_illuminator.entity_light_level[guid] < 1 then
		lord_illuminator.entity_light_level[guid] = 0
		return nil
	end

	return "lord_illuminator:light_"..lord_illuminator.entity_light_level[guid]
end

-- return node position suitable for replacement with a light source node
lord_illuminator.entity_light_get_pos = function(entity_pos)
	-- can replace at feet?
	if lord_illuminator.can_replace_node(entity_pos) then
		return entity_pos
	end

	-- can replace at head?
	entity_pos.y = entity_pos.y + 1
	if lord_illuminator.can_replace_node(entity_pos) then
		return entity_pos
	end

	-- can replace somewhere near head?
	return core.find_node_near(entity_pos, 1, {"air", "group:lord_illuminator_light"})
end

-- main cycle for entities
lord_illuminator.entities_light_update = function(time_step)
	for guid, entity_object in pairs(lord_illuminator.entity_collection) do
		if lord_illuminator.entity_handles_light[guid] then
			local pos_old = lord_illuminator.entity_positions[guid]
			local pos_new = vector.round(vector.add(entity_object:get_pos(), vector.multiply(entity_object:get_velocity(), 2*time_step)))
			-- what light should be placed
			local light_name = lord_illuminator.entity_light_get_name(guid)
			-- where light should be placed
			local light_pos = lord_illuminator.entity_light_get_pos(pos_new)

			-- nowhere to place light - no need to proceed at all
			if not light_pos then
				goto entities_light_update_continue
			end

			if pos_old and pos_new and light_name then
				-- situation A: light node is present already - no need to proceed
				if light_name == core.get_node(light_pos).name then
					goto entities_light_update_continue
				else

					-- situation B: light node has been removed for some reason (by another player movement, for example)
					-- need to ignore vector.equals(pos_new, pos_old) condition below
					if lord_illuminator.entity_light_positions[guid] then
						if light_pos == lord_illuminator.entity_light_positions[guid] then
							lord_illuminator.entity_force_update[guid] = true
						end
					end
				end

				-- Situation: entity didn't move
				if vector.equals(pos_old, pos_new) then
					if lord_illuminator.entity_force_update[guid] then
						lord_illuminator.entity_force_update[guid] = false
					else
						goto entities_light_update_continue
					end
				end

				-- proceed with light update
				lord_illuminator.entity_positions[guid] = pos_new
				lord_illuminator.light_create(light_pos, light_name)

				-- remove light node the player has left behind
				if lord_illuminator.entity_light_positions[guid] then
					if not vector.equals(lord_illuminator.entity_light_positions[guid], light_pos) then
						lord_illuminator.light_remove(lord_illuminator.entity_light_positions[guid])
					end
				end

				lord_illuminator.entity_light_positions[guid] = light_pos
				goto entities_light_update_continue
			end
		end

		-- default behaviour: remove light at the entity position and clean up
		-- suppose there is no light left with the entity
		lord_illuminator.light_remove(pos_old)
		lord_illuminator.entity_light_positions[guid] = nil
		::entities_light_update_continue::
	end
end
