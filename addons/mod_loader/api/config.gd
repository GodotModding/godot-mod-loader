class_name ModLoaderConfig
extends Object

# Handles loading and saving per-mod JSON configs

const LOG_NAME := "ModLoader:Config"

enum MLConfigStatus {
	OK,                  # 0 = No errors
	NO_JSON_OK,          # 1 = No custom JSON (file probably does not exist). Uses defaults from manifest, if available
	INVALID_MOD_ID,      # 2 = Invalid mod ID
	NO_JSON_INVALID_KEY, # 3 = Invalid key, and no custom JSON was specified in the manifest defaults (`extra.godot.config_defaults`)
	INVALID_KEY          # 4 = Invalid key, although config data does exists
}


# Get the config data for a specific mod. Always returns a dictionary with two
# keys: `error` and `data`.
# Data (`data`) is either the full config, or data from a specific key if one was specified.
# Error (`error`) is 0 if there were no errors, or > 0 if the setting could not be retrieved:
static func get_mod_config(mod_dir_name: String = "", key: String = "") -> Dictionary:
	var status_code = MLConfigStatus.OK
	var status_msg := ""
	var data = {} # can be anything
	var defaults := {}

	# Invalid mod ID
	if not ModLoader.mod_data.has(mod_dir_name):
		status_code = MLConfigStatus.INVALID_MOD_ID
		status_msg = "Mod ID was invalid: %s" % mod_dir_name

	# Mod ID is valid
	if status_code == MLConfigStatus.OK:
		var mod := ModLoader.mod_data[mod_dir_name] as ModData
		var config_data := mod.config
		defaults = mod.manifest.config_defaults

		# No custom JSON file
		if config_data.size() == MLConfigStatus.OK:
			status_code = MLConfigStatus.NO_JSON_OK
			var noconfig_msg = "No config file for %s.json. " % mod_dir_name
			if key == "":
				data = defaults
				status_msg += str(noconfig_msg, "Using defaults (extra.godot.config_defaults)")
			else:
				if defaults.has(key):
					data = defaults[key]
					status_msg += str(noconfig_msg, "Using defaults for key '%s' (extra.godot.config_defaults.%s)" % [key, key])
				else:
					status_code = MLConfigStatus.NO_JSON_INVALID_KEY
					status_msg += str(
						"Could not get the requested data for %s: " % mod_dir_name,
						"Requested key '%s' is not present in the 'config_defaults' of the mod's manifest.json file (extra.godot.config_defaults.%s). " % [key, key]
					)

		# JSON file exists
		if status_code == MLConfigStatus.OK:
			if key == "":
				data = config_data
			else:
				if config_data.has(key):
					data = config_data[key]
				else:
					status_code = MLConfigStatus.INVALID_KEY
					status_msg = "Invalid key '%s' for mod ID: %s" % [key, mod_dir_name]

	# Log if any errors occured
	if not status_code == MLConfigStatus.OK:
		if status_code == MLConfigStatus.NO_JSON_OK:
			# No user config file exists. Low importance as very likely to trigger
			var full_msg = "Config JSON Notice: %s" % status_msg
			# Only log this once, to avoid flooding the log
			if not ModLoaderStore.logged_messages.all.has(full_msg.md5_text()):
				ModLoaderLog.debug(full_msg, mod_dir_name)
		else:
			# Code error (eg. invalid mod ID)
			ModLoaderLog.fatal("Config JSON Error (%s): %s" % [status_code, status_msg], mod_dir_name)

	return {
		"status_code": status_code,
		"status_msg": status_msg,
		"data": data,
	}


# Returns a bool indicating if a retrieved mod config is valid.
# Requires the full config object (ie. the dictionary that's returned by
# `get_mod_config`)
static func is_mod_config_data_valid(config_obj: Dictionary) -> bool:
	return config_obj.status_code <= MLConfigStatus.NO_JSON_OK


# Saves a full dictionary object to a mod's custom config file, as JSON.
# Overwrites any existing data in the file.
# Optionally updates the config object that's stored in memory (true by default).
# Returns a bool indicating success or failure.
# WARNING: Provides no validation
static func save_mod_config_dictionary(mod_id: String, data: Dictionary, update_config: bool = true) -> bool:
	# Use `get_mod_config` to check if a custom JSON file already exists.
	# This has the added benefit of logging a fatal error if mod_name is
	# invalid (as it already happens in `get_mod_config`)
	var config_obj := get_mod_config(mod_id)

	if not is_mod_config_data_valid(config_obj):
		ModLoaderLog.warning("Could not save the config JSON file because the config data was invalid", mod_id)
		return false

	var data_original: Dictionary = config_obj.data
	var data_new := {}

	# Merge
	if update_config:
		# Update the config held in memory
		data_original.merge(data, true)
		data_new = data_original
	else:
		# Don't update the config in memory
		data_new = data_original.duplicate(true)
		data_new.merge(data, true)

	var configs_path := ModLoaderUtils.get_path_to_configs()
	var json_path := configs_path.plus_file(mod_id + ".json")

	return ModLoaderUtils.save_dictionary_to_json_file(data_new, json_path)


# Saves a single settings to a mod's custom config file.
# Returns a bool indicating success or failure.
static func save_mod_config_setting(mod_id: String, key:String, value, update_config: bool = true) -> bool:
	var new_data = {
		key: value
	}

	return save_mod_config_dictionary(mod_id, new_data, update_config)
