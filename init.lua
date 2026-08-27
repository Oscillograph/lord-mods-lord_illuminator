-- Heavily inspired by https://github.com/mt-mods/illumination
-- Light source can be created only in place of "air" node. Otherwise it will cause problems gameplay-wise.

lord_illuminator = {}			-- the mod namespace

local modpath = core.get_modpath(core.get_current_modname())

dofile(modpath.."/config.lua")
dofile(modpath.."/general_functions.lua")

-- internal online player database
lord_illuminator.player_light_level = {}		-- indexed by player name, updated on timer
lord_illuminator.player_handles_light = {}		-- indexed by player name, boolean, updated on timer
lord_illuminator.player_force_update = {}		-- indexed by player_name, updated once in light_update()
lord_illuminator.player_positions = {}			-- indexed by player name, updated regularly in light_update()
lord_illuminator.player_light_positions = {} 	-- indexed by player name, updated regularly in light_update()

dofile(modpath.."/player_functions.lua")

-- WIP: entities which have luminance
if lord_illuminator.enable_entities then
	lord_illuminator.entity_collection = {}			-- indexed by entity guid, entity objects that are being tracked and processed
	lord_illuminator.entity_light_level = {}		-- indexed by entity guid, updated on timer
	lord_illuminator.entity_handles_light = {}		-- indexed by entity guid, boolean, updated on timer
	lord_illuminator.entity_force_update = {}		-- indexed by entity guid, updated once in light_update()
	lord_illuminator.entity_positions = {}			-- indexed by entity guid, updated regularly in light_update()
	lord_illuminator.entity_light_positions = {} 	-- indexed by entity guid, updated regularly in light_update()

	dofile(modpath.."/entity_functions.lua")
end

lord_illuminator.time_passed = 0				-- local timer, cleaned up everytime it reaches lord_illuminator.time_step

dofile(modpath.."/api.lua")
dofile(modpath.."/register.lua")
