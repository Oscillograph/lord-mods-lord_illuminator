-----------------------------------------------------------
-- GENERAL STUFF

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
			local node_timer = core.get_node_timer(pos)
			if not node_timer:is_started() then
				node_timer:start(lord_illuminator.light_lifetime)
			end
		end
	end
end

-- return true		if node can be replaced with lord_illuminator:light_X (where X is a number)
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

-- remove light which lifetime has ended - it is a light that is tracked only by the game engine
lord_illuminator.light_timeout = function(pos)
	core.set_node(pos, {name = "air"})
end
