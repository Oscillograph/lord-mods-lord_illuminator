-----------------------------------------------------------
-- ENTITY LIGHTS TRACKING AND PROCESSING

-- generally should be called when an entity lost its light or has been destroyed
lord_illuminator.entity_clean_up = function(guid)
	if lord_illumunator.entity_collection[guid] then
		lord_illumunator.entity_collection[guid] = nil
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

-- main cycle for entities
lord_illuminator.entities_light_update = function(time_step)
	for guid, entity_object in ipairs(lord_illuminator.entity_collection) do
		if lord_illuminator.entity_handles_light[guid] then
			local pos_old = lord_illuminator.entity_positions[guid]
			local pos_new = vector.round(vector.add(entity_object:get_pos(), vector.multiply(entity_object:get_velocity(), 2*time_step)))
			-- what light should be placed
			local light_name = lord_illuminator.light_get_name(player)
			-- where light should be placed
			local light_pos = lord_illuminator.light_get_pos(pos_new)

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

				-- Situation: entity didn't move
				if vector.equal(pos_old, pos_new) then
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
