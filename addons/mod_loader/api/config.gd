# This Class provides functionality for working with per-mod Configurations.
class_name ModLoaderConfig
extends Object


const LOG_NAME := "ModLoader:Config"
const DEFAULT_CONFIG_NAME  := "default"


# Creates a new configuration for a mod.
#
# Parameters:
# - mod_id (String): The ID of the mod for which the configuration is being created.
# - config_name (String): The name of the configuration.
# - config_data (Dictionary): The configuration data to be stored in the new configuration.
#
# Returns:
# - ModConfig: The created ModConfig object if successful, or null otherwise.
static func create_config(mod_id: String, config_name: String, config_data: Dictionary) -> ModConfig:
	# Check if the config schema exists by retrieving the default config
	var default_config: ModConfig = get_default_config(mod_id)
	if not default_config:
		ModLoaderLog.error(
			"Failed to create config \"%s\". No config schema found for \"%s\"."
			% [config_name, mod_id], LOG_NAME
		)
		return null

	# Make sure the config name is not empty
	if config_name == "":
		ModLoaderLog.error(
			"Failed to create config \"%s\". The config name cannot be empty."
			% config_name, LOG_NAME
		)
		return null

	# Make sure the config name is unique
	if ModLoaderStore.mod_data[mod_id].configs.has(config_name):
		ModLoaderLog.error(
			"Failed to create config \"%s\". A config with the name \"%s\" already exists."
			% [config_name, config_name], LOG_NAME
		)
		return null

	# Create the config save path based on the config_name
	var config_file_path := _ModLoaderPath.get_path_to_mod_configs_dir(mod_id).plus_file("%s.json" % config_name)

	# Initialize a new ModConfig object with the provided parameters
	var mod_config := ModConfig.new(
		mod_id,
		config_data,
		config_file_path
	)

	# Check if the mod_config is valid
	if not mod_config.is_valid:
		return null

	# Store the mod_config in the mod's ModData
	ModLoaderStore.mod_data[mod_id].configs[config_name] = mod_config
	# Save the mod_config to a new config JSON file in the mod's config directory
	var is_save_success := mod_config.save_to_file()

	if not is_save_success:
		return null

	ModLoaderLog.debug("Created new config \"%s\" for mod \"%s\"" % [config_name, mod_id], LOG_NAME)

	return mod_config


# Updates an existing ModConfig object with new data and save the config file.
#
# Parameters:
# - config (ModConfig): The ModConfig object to be updated.
#
# Returns:
# - ModConfig: The updated ModConfig object if successful, or null otherwise.
static func update_config(config: ModConfig) -> ModConfig:
	# Validate the config and check for any validation errors
	var error_message := config.validate()

	# Check if the config is the "default" config, which cannot be modified
	if config.name == DEFAULT_CONFIG_NAME:
		ModLoaderLog.error("The \"default\" config cannot be modified. Please create a new config instead.", LOG_NAME)
		return null

	# Check if the config passed validation
	if not config.is_valid:
		ModLoaderLog.error("Update for config \"%s\" failed validation with error message \"%s\"" % [config.name, error_message], LOG_NAME)
		return null

	# Save the updated config to the config file
	var is_save_success := config.save_to_file()

	if not is_save_success:
		ModLoaderLog.error("Failed to save config \"%s\" to \"%s\"." % [config.name, config.save_path], LOG_NAME)
		return null

	# Return the updated config
	return config


# Deletes a ModConfig object and performs cleanup operations.
#
# Parameters:
# - config (ModConfig): The ModConfig object to be deleted.
#
# Returns:
# - bool: True if the deletion was successful, False otherwise.
static func delete_config(config: ModConfig) -> bool:
	# Check if the config is the "default" config, which cannot be deleted
	if config.name == DEFAULT_CONFIG_NAME:
		ModLoaderLog.error("Deletion of the default configuration is not allowed.", LOG_NAME)
		return false

	# Change the current config to the "default" config
	set_current_config(get_default_config(config.mod_id))

	# Remove the config file from the Mod Config directory
	var is_remove_success := config.remove_file()

	if not is_remove_success:
		return false

	# Remove the config from ModData
	ModLoaderStore.mod_data[config.mod_id].configs.erase(config.name)

	return true


# Sets the current configuration of a mod to the specified configuration.
#
# Parameters:
# - config (ModConfig): The ModConfig object to be set as current config.
static func set_current_config(config: ModConfig) -> void:
	ModLoaderStore.mod_data[config.mod_id].current_config = config


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


# Retrieves the schema for a specific property key.
#
# Parameters:
# - config (ModConfig): The ModConfig object from which to retrieve the schema.
# - prop (String): The property key for which to retrieve the schema.
#									 e.g. `parentProp.childProp.nthChildProp` || `propKey`
#
# Returns:
# - Dictionary: The schema dictionary for the specified property.
static func get_schema_for_prop(config: ModConfig, prop: String) -> Dictionary:
	# Split the property string into an array of property keys
	var prop_array := prop.split(".")

	# If the property array is empty, return the schema for the root property
	if prop_array.empty():
		return config.schema.properties[prop]

	# Traverse the schema dictionary to find the schema for the specified property
	var schema_for_prop := _traverse_schema(config.schema.properties, prop_array)

	# If the schema for the property is empty, log an error and return an empty dictionary
	if schema_for_prop.empty():
		ModLoaderLog.error("No Schema found for property \"%s\" in config \"%s\" for mod \"%s\"" % [prop, config.name, config.mod_id], LOG_NAME)
		return {}

	return schema_for_prop


# Recursively traverses the schema dictionary based on the provided prop_key_array
# and returns the corresponding schema for the target property.
#
# Parameters:
# - schema_prop: The current schema dictionary to traverse.
# - prop_key_array: An array containing the property keys representing the path to the target property.
#
# Returns:
# The schema dictionary corresponding to the target property specified by the prop_key_array.
# If the target property is not found, an empty dictionary is returned.
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


# Retrieves an Array of mods that have configuration files.
#
# Returns:
# An Array containing the mod data of mods that have configuration files.
static func get_mods_with_config() -> Array:
	# Create an empty array to store mods with configuration files
	var mods_with_config := []

	# Iterate over each mod in ModLoaderStore.mod_data
	for mod_id in ModLoaderStore.mod_data:
		# Retrieve the mod data for the current mod ID
		# *The ModData type cannot be used because ModData is not fully loaded when this code is executed.*
		var mod_data = ModLoaderStore.mod_data[mod_id]

		# Check if the mod has any configuration files
		if not mod_data.configs.empty():
			mods_with_config.push_back(mod_data)

	# Return the array of mods with configuration files
	return mods_with_config


# Retrieves the configurations dictionary for a given mod ID.
#
# Parameters:
# - mod_id: The ID of the mod for which to retrieve the configurations.
#
# Returns:
# A dictionary containing the configurations for the specified mod.
# If the mod ID is invalid or no configurations are found, an empty dictionary is returned.
static func get_configs(mod_id: String) -> Dictionary:
	# Check if the mod ID is invalid
	if not ModLoaderStore.mod_data.has(mod_id):
		ModLoaderLog.fatal("Mod ID \"%s\" not found" % [mod_id], LOG_NAME)
		return {}

	var config_dictionary: Dictionary = ModLoaderStore.mod_data[mod_id].configs

	# Check if there is no config file for the mod
	if config_dictionary.empty():
		ModLoaderLog.debug("No config for mod id \"%s\"" % mod_id, LOG_NAME, true)
		return {}

	return config_dictionary


# Retrieves the configuration for a specific mod and configuration name.
# Returns the configuration as a ModConfig object or null if not found.
#
# Parameters:
# - mod_id (String): The ID of the mod to retrieve the configuration for.
# - config_name (String): The name of the configuration to retrieve.
#
# Returns:
# The configuration as a ModConfig object or null if not found.
static func get_config(mod_id: String, config_name: String) -> ModConfig:
	var configs := get_configs(mod_id)

	if not configs.has(config_name):
		ModLoaderLog.error("No config with name \"%s\" found for mod_id \"%s\" " % [config_name, mod_id], LOG_NAME)
		return null

	return configs[config_name]


# Retrieves the default configuration for a specified mod ID.
#
# Parameters:
# - mod_id: The ID of the mod for which to retrieve the default configuration.
#
# Returns:
# The ModConfig object representing the default configuration for the specified mod.
# If the mod ID is invalid or no configuration is found, returns null.
#
static func get_default_config(mod_id: String) -> ModConfig:
	return get_config(mod_id, DEFAULT_CONFIG_NAME)


# Retrieves the currently active configuration for a specific mod
#
# Parameters:
# mod_id (String): The ID of the mod to retrieve the configuration for.
#
# Returns:
# The configuration as a ModConfig object or null if not found.
static func get_current_config(mod_id: String) -> ModConfig:
	var current_config_name := get_current_config_name(mod_id)
	var current_config := get_config(mod_id, current_config_name)

	return current_config


# Retrieves the name of the current configuration for a specific mod
# Returns an empty string if no configuration exists for the mod or the user profile has not been loaded
#
# Parameters:
# mod_id (String): The ID of the mod to retrieve the current configuration name for.
#
# Returns:
# The currently active configuration name for the given mod id or an empty string if not found.
static func get_current_config_name(mod_id: String) -> String:
	# Check if user profile has been loaded
	if not ModLoaderStore.current_user_profile or not ModLoaderStore.user_profiles.has(ModLoaderStore.current_user_profile.name):
		# Warn and return an empty string if the user profile has not been loaded
		ModLoaderLog.warning("Can't get current mod config for \"%s\", because no current user profile is present." % mod_id, LOG_NAME)
		return ""

	# Retrieve the current user profile from ModLoaderStore
	# *Can't use ModLoaderUserProfile because it causes a cyclic dependency*
	var current_user_profile = ModLoaderStore.current_user_profile

	# Check if the mod exists in the user profile's mod list and if it has a current config
	if not current_user_profile.mod_list.has(mod_id) or not current_user_profile.mod_list[mod_id].has("current_config"):
		# Log an error and return an empty string if the mod has no config file
		ModLoaderLog.error("Mod \"%s\" has no config file." % mod_id, LOG_NAME)
		return ""

	# Return the name of the current configuration for the mod
	return current_user_profile.mod_list[mod_id].current_config
