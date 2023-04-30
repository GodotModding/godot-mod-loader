class_name ModLoaderConfig
extends Object

# Handles loading and saving per-mod JSON configs

const LOG_NAME := "ModLoader:Config"

enum ML_CONFIG_STATUS {
	OK,                  # 0 = No errors
	NO_JSON_OK,          # 1 = No custom JSON (file probably does not exist). Uses defaults from manifest, if available
	INVALID_MOD_ID,      # 2 = Invalid mod ID
	NO_JSON_INVALID_KEY, # 3 = Invalid key, and no custom JSON was specified in the manifest defaults (`extra.godot.config_defaults`)
	INVALID_KEY          # 4 = Invalid key, although config data does exists
}


# Retrieves the configuration data for a specific mod.
# Returns a dictionary with three keys:
# - "status_code": an integer indicating the status of the request
# - "status_msg": a string containing a message explaining the status code
# - "data": the configuration data
#
# Parameters:
# - mod_dir_name: the name of the mod's directory / id
#
# Status Codes:
# - ML_CONFIG_STATUS.OK: the request was successful and the configuration data is included in the "data" key
# - ML_CONFIG_STATUS.INVALID_MOD_ID: the mod ID is not valid, and the "status_msg" key contains an error message
# - ML_CONFIG_STATUS.NO_JSON_OK: there is no configuration file for the mod, the "data" key contains an empty dictionary
#
# Returns:
# A dictionary with three keys: "status_code", "status_msg", and "data"
static func get_mod_config(mod_dir_name: String) -> Dictionary:
	var status_code = ML_CONFIG_STATUS.OK
	var status_msg := ""
	var data = {} # can be anything

	# Check if the mod ID is invalid
	if not ModLoaderStore.mod_data.has(mod_dir_name):
		status_code = ML_CONFIG_STATUS.INVALID_MOD_ID
		status_msg = "Mod ID was invalid: %s" % mod_dir_name

	# Mod ID is valid
	if status_code == ML_CONFIG_STATUS.OK:
		var mod := ModLoaderStore.mod_data[mod_dir_name] as ModData
		var config_data := mod.config

		# Check if there is no config file for the mod
		if config_data.size() == 0:
			status_code = ML_CONFIG_STATUS.NO_JSON_OK
			status_msg = "No config file for %s.json. " % mod_dir_name

		# Config file exists
		if status_code == ML_CONFIG_STATUS.OK:
				data = config_data

	# Log any errors that occurred
	if not status_code == ML_CONFIG_STATUS.OK:
		if status_code == ML_CONFIG_STATUS.NO_JSON_OK:
			# The mod has no user config file, which is not a critical error
			var full_msg = "Config JSON Notice: %s" % status_msg
			# Only log this once, to avoid flooding the log
			ModLoaderLog.debug(full_msg, mod_dir_name, true)
		else:
			# The error is critical (e.g. invalid mod ID)
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
	return config_obj.status_code <= ML_CONFIG_STATUS.NO_JSON_OK


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

	var configs_path := _ModLoaderPath.get_path_to_configs()
	var json_path := configs_path.plus_file(mod_id + ".json")

	return _ModLoaderFile.save_dictionary_to_json_file(data_new, json_path)


# Saves a single settings to a mod's custom config file.
# Returns a bool indicating success or failure.
static func save_mod_config_setting(mod_id: String, key:String, value, update_config: bool = true) -> bool:
	var new_data = {
		key: value
	}

	return save_mod_config_dictionary(mod_id, new_data, update_config)
