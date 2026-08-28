-- how often light sources should be updated
lord_illuminator.time_step 			= (tonumber(core.settings:get("lord_illuminator_time_step")) or 0.2)
-- how long light sources live in seconds; put 0 or nil to make light vanish instantly
lord_illuminator.light_lifetime		= (tonumber(core.settings:get("lord_illuminator_light_lifetime")) or 0.5)
-- give specific entities luminance, track and process them (may lower performance)
lord_illuminator.enable_entities	= (core.settings:get_bool("lord_illuminator_enable_entities") or false)
