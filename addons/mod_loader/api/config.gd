class_name ModLoaderConfig
extends Object

# Handles loading and saving per-mod JSON configs

const LOG_NAME := "ModLoader:Config"


# Retrieves the configuration data for a specific mod
static func get_mod_config(mod_id: String) -> Dictionary:
	# Check if the mod ID is invalid
	if not ModLoaderStore.mod_data.has(mod_id):
		ModLoaderLog.fatal("Mod ID \"%s\" not found" % [mod_id], LOG_NAME)
		return {}

	var config_data = ModLoaderStore.mod_data[mod_id].config

	# Check if there is no config file for the mod
	if not config_data:
		ModLoaderLog.debug("No config for mod id \"%s\"" % mod_id, LOG_NAME, true)
		return {}

	return config_data


static func is_mod_config_data_valid(config_data: ModConfig):
	var json_schema := JSONSchema.new()
	var error := json_schema.validate(config_data.get_data_as_string(), config_data.get_schema_as_string())


static func update_mod_config(mod_id: String, data: Dictionary) -> void:
	# Update the config held in memory
	ModLoaderStore.mod_data[mod_id].config.merge(data, true)


# Saves a full dictionary object to a mod's config file, as JSON.
static func save_mod_config(config_data: ModConfig) -> bool:
	return _ModLoaderFile.save_dictionary_to_json_file(config_data.data, config_data.save_path)
