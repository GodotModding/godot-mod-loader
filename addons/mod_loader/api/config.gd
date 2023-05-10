class_name ModLoaderConfig
extends Object


# The `ModLoaderConfig` class provides functionality for loading and saving per-mod JSON configuration files.

const LOG_NAME := "ModLoader:Config"


# Sets the current configuration of a mod to the specified configuration.
# Returns true if the operation was successful, false otherwise.
#
# Parameters:
# - mod_id (String): The ID of the mod whose configuration is being set.
# - config_name (String): The name of the configuration to set as the current configuration for the mod.
#
# Returns:
# - bool: True if the operation was successful, false otherwise.
static func set_current_config(mod_id: String, config_name: String) -> bool:
	var config := get_config(mod_id, config_name)

	# Check if config exists
	if not config:
		return false

	ModLoaderStore.mod_data[mod_id].current_config = config

	return true


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


# Saves a full dictionary object to a mod's config file, as JSON.
static func save_mod_config(config_data: ModConfig) -> bool:
	return _ModLoaderFile.save_dictionary_to_json_file(config_data.data, config_data.save_path)
