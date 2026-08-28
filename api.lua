-- IMPORTANT NOTE: an entity can have only one light source
-- An attempt to register one entity two times or more without unregistering first will most likely cause the mod to behave interesting.
-- I mean: "Oh, god, oh, god, the server's gonna crash"

-- should be called when an entity obtains light source
-- @param entity_object    EntityObj    entity object
-- @param light_level      Int          1..15
-- @param light_turned_on  Boolean      true if light is on, false otherwise
lord_illuminator.entity_register = function(entity_object, light_level, light_turned_on)
	if entity_object then
		local guid = entity_object:get_guid()
		lord_illuminator.entity_collection[guid]	= entity_object
		lord_illuminator.entity_positions[guid]		= entity_object:get_pos()
		lord_illuminator.entity_light_level[guid]	= light_level
		lord_illuminator.entity_handles_light[guid]	= light_turned_on
	end
end

-- should be called when an entity loses light source
-- @param entity_object    EntityObj    entity object
lord_illuminator.entity_unregister = function(entity_object)
	if entity_object then
		local guid = entity_object:get_guid()
		lord_illuminator.entity_clean_up(guid)
	end
end

-- means to turn entity luminance on and off
-- @param entity_object    EntityObj    entity object
-- @param light_turned_on  Boolean      true if light is on, false otherwise
lord_illuminator.entity_light_switch = function(entity_object, light_turned_on)
	if entity_object then
		local guid = entity_object:get_guid()
		lord_illuminator.entity_handles_light[guid] = light_turned_on
	end
end

-- means to change light intensity
-- @param entity_object    EntityObj    entity object
-- @param light_level      Int          1..15
lord_illuminator.entity_light_level_change = function(entity_object, light_level)
	if entity_object then
		local guid = entity_object:get_guid()
		lord_illuminator.entity_light_level[guid]	= light_level
	end
end
