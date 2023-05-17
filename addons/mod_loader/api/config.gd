class_name ModLoaderConfig
extends Object


# The `ModLoaderConfig` class provides functionality for loading and saving per-mod JSON configuration files.

const LOG_NAME := "ModLoader:Config"


static func get_mods_with_config() -> Array:
	var mods_with_config := []

	for mod_id in ModLoaderStore.mod_data:
		var mod_data = ModLoaderStore.mod_data[mod_id]
		if not mod_data.configs.empty():
			mods_with_config.push_back(mod_data)

	return mods_with_config


static func create_config(mod_id: String, config_name: String, config_data: Dictionary) -> bool:
	# Check if Config Schema exists
	# If this is the case, the "default" config is in the Mods ModData
	var default_config: ModConfig = get_config(mod_id, "default")
	if not default_config:
		ModLoaderLog.error(
			"Failed to create config \"%s\". No config schema found for \"%s\"."
			% [config_name, mod_id], LOG_NAME
		)
		return false

	# Make sure the config name is not empty
	if config_name == "":
		ModLoaderLog.error(
			"Failed to create config \"%s\". The config name cannot be empty."
			% config_name, LOG_NAME
		)
		return false

	# Make sure the config name is unique
	if ModLoaderStore.mod_data[mod_id].configs.has(config_name):
		ModLoaderLog.error(
			"Failed to create config \"%s\". A config with the name \"%s\" already exists."
			% [config_name, config_name], LOG_NAME
		)
		return false

	# Create config save path based on the config_name
	var config_file_path := _ModLoaderPath.get_path_to_mod_configs(mod_id).plus_file("%s.json" % config_name)

	# Init a new ModConfig Object
	var mod_config := ModConfig.new(
		mod_id,
		config_data,
		config_file_path
	)

	if not mod_config.is_valid:
		return false

	# If config is valid
	# Store it in the ModData
	ModLoaderStore.mod_data[mod_id].configs[config_name] = mod_config
	# Save it to a new config json file in the mods config directory
	var is_save_success := mod_config.save_to_disc()

	if is_save_success:
		ModLoaderLog.debug("Created new config \"%s\" for mod \"%s\"" % [config_name, mod_id], LOG_NAME)

	return is_save_success


static func delete_config(config: ModConfig) -> bool:
	# Check if default config
	if config.name == "default":
		ModLoaderLog.error("Can't delete the default config", LOG_NAME)
		return false

	# Change current config to "default"
	set_current_config(get_config(config.mod_id, "default"))

	# Remove config file from Mod Config dir
	var is_remove_success := config.remove_from_disc()

	if not is_remove_success:
		return false

	# Remove config from ModData
	ModLoaderStore.mod_data[config.mod_id].configs.erase(config.name)

	return true


# Sets the current configuration of a mod to the specified configuration.
# Returns true if the operation was successful, false otherwise.
#
# Parameters:
# - mod_id (String): The ID of the mod whose configuration is being set.
# - config_name (String): The name of the configuration to set as the current configuration for the mod.
#
# Returns:
# - bool: True if the operation was successful, false otherwise.
static func set_current_config(config: ModConfig) -> void:
	ModLoaderStore.mod_data[config.mod_id].current_config = config


static func get_config_data(mod_id: String, config_name: String) -> Dictionary:
	return get_config(mod_id, config_name).data


# Returns the schema for the specified mod id.
# If no configuration file exists for the mod, an empty dictionary is returned.
#
# Parameters:
# - mod_id (String): the ID of the mod to get the configuration schema for
#
# Returns:
# - A dictionary representing the schema for the mod's configuration file
static func get_config_schema(mod_id: String) -> Dictionary:
	# Get all config files for the specified mod
	var mod_configs := get_configs(mod_id)

	# If no config files were found, return an empty dictionary
	if mod_configs.empty():
		return {}

	# The schema is the same for all config files, so we just return the schema of the default config file
	return mod_configs.default.schema


static func get_schema_for_prop(config: ModConfig, prop: String) -> Dictionary:
	var prop_array := prop.split(".")

	if prop_array.empty():
		return config.schema.properties[prop]

	var schema_for_prop := _traverse_schema(config.schema.properties, prop_array)
	if schema_for_prop.empty():
		ModLoaderLog.error("No Schema found for property \"%s\" in config \"%s\" for mod \"%s\"" % [prop, config.name, config.mod_id], LOG_NAME)
		return {}

	return schema_for_prop


# Traverses the schema dictionary based on the provided property_key_array and returns the corresponding schema.
static func _traverse_schema(schema_prop: Dictionary, prop_key_array: Array) -> Dictionary:
	# Return the current schema_prop if the prop_key_array is empty (reached the destination property)
	if prop_key_array.empty():
		return schema_prop

	# Get and remove the first prop_key in the array
	var prop_key: String = prop_key_array.pop_front()

	# Check if the searched property exists
	if not schema_prop.has(prop_key):
		return {}

	schema_prop = schema_prop[prop_key]
	# If the schema_prop has a 'type' key, is of type 'object', and there are more property keys remaining
	if schema_prop.has("type") and schema_prop.type == "object" and not prop_key_array.empty():
		# Set the properties of the object as the current 'schema_prop'
		schema_prop = schema_prop.properties

	schema_prop = _traverse_schema(schema_prop, prop_key_array)

	return schema_prop


# Retrieves the configuration data for a specific mod and configuration name.
# Returns the configuration data as a ModConfig object or null if not found.
#
# Parameters:
# - mod_id (String): The ID of the mod to retrieve the configuration for.
# - config_name (String): The name of the configuration to retrieve.
#
# Returns:
# The configuration data as a ModConfig object or null if not found.
static func get_config(mod_id: String, config_name: String) -> ModConfig:
	var configs = get_configs(mod_id)

	if not configs.has(config_name):
		ModLoaderLog.error("No config with name \"%s\" found for mod_id \"%s\" " % [config_name, mod_id], LOG_NAME)
		return null

	return configs[config_name]


# Retrieves an array of configuration data for a specific mod.
#
# Parameters:
# mod_id (String): The ID of the mod to retrieve configuration data for.
#
# Returns:
# Dictionary: An Dictionary of `ModConfig` objects containing the configuration data for the specified mod.
#
# Raises:
# ModLoaderFatalError: If the specified mod ID is invalid and no configuration data can be retrieved.
#
# Description:
# This function retrieves a Dictionary of `ModConfig` objects containing configuration data for the specified mod ID.
# If the mod ID is not valid or no configuration data is available for the specified mod, an empty array is returned.
# The `ModConfig` object contains the name and schema of the configuration file, as well as the current configuration values.
# Multiple `ModConfig` objects can exist for a single mod, each representing a different configuration file.
# The returned array contains all of the `ModConfig` objects for the specified mod.
static func get_configs(mod_id: String) -> Dictionary:
	# Check if the mod ID is invalid
	if not ModLoaderStore.mod_data.has(mod_id):
		ModLoaderLog.fatal("Mod ID \"%s\" not found" % [mod_id], LOG_NAME)
		return {}

	var config_dictionary = ModLoaderStore.mod_data[mod_id].configs

	# Check if there is no config file for the mod
	if config_dictionary.empty():
		ModLoaderLog.debug("No config for mod id \"%s\"" % mod_id, LOG_NAME, true)
		return {}

	return config_dictionary


# Retrieves the currently active configuration for a specific mod
#
# Parameters:
# mod_id (String): The ID of the mod to retrieve configuration data for.
# Returns:
# The configuration data as a ModConfig object or null if not found.
static func get_current_config(mod_id: String) -> ModConfig:
	var current_config_name := get_current_config_name(mod_id)
	var current_config := get_config(mod_id, current_config_name)

	return current_config


static func get_default_config(mod_id: String) -> ModConfig:
	return get_config(mod_id, "default")


# Retrieves the name of the current configuration for a specific mod
# Returns an empty string if no configuration exists for the mod or the user profile has not been loaded
#
# Parameters:
# mod_id (String): The ID of the mod to retrieve the current configuration name for.
# Returns:
# The currently active configuration name for the given mod id or an empty string if not found.
static func get_current_config_name(mod_id: String) -> String:
	# Check if user profile has been loaded
	if not ModLoaderStore.user_profiles.has(ModLoaderStore.current_user_profile):
		# Warn and return an empty string if the user profile has not been loaded
		ModLoaderLog.warning("Can't get current mod config for \"%s\", because no current user profile is present." % mod_id, LOG_NAME)
		return ""

	# Retrieve the current user profile from ModLoaderStore
	# *Can't use ModLoaderUserProfile because it causes a cyclic dependency*
	var current_user_profile = ModLoaderStore.user_profiles[ModLoaderStore.current_user_profile]

	# Check if the mod exists in the user profile's mod list and if it has a current config
	if not current_user_profile.mod_list.has(mod_id) or not current_user_profile.mod_list[mod_id].has("current_config"):
		# Log an error and return an empty string if the mod has no config file
		ModLoaderLog.error("Mod \"%s\" has no config file." % mod_id, LOG_NAME)
		return ""

	# Return the name of the current configuration for the mod
	return current_user_profile.mod_list[mod_id].current_config
