class_name ModLoaderUserProfile
extends Object


# This Class provides methods for working with user profiles.

const LOG_NAME := "ModLoader:UserProfile"
const FILE_PATH_USER_PROFILES = "user://mod_user_profiles.json"


# API profile functions
# =============================================================================

# Enables a mod - it will be loaded on the next game start
static func enable_mod(mod_id: String, user_profile := ModLoaderStore.current_user_profile) -> bool:
	return _set_mod_state(mod_id, user_profile.name, true)


# Disables a mod - it will not be loaded on the next game start
static func disable_mod(mod_id: String, user_profile := ModLoaderStore.current_user_profile) -> bool:
	return _set_mod_state(mod_id, user_profile.name, false)


# Sets the current config for a mod in a user profiles mod_list.
static func set_mod_current_config(mod_id: String, mod_config: ModConfig, user_profile := ModLoaderStore.current_user_profile) -> bool:
	# Verify whether the mod_id is present in the profile's mod_list.
	if not _is_mod_id_in_mod_list(mod_id, user_profile.name):
		return false

	# Update the current config in the mod_list of the user profile
	user_profile.mod_list[mod_id].current_config = mod_config.name

	# Store the new profile in the json file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Set the \"current_config\" of \"%s\" to \"%s\" in user profile \"%s\" " % [mod_id, mod_config.name, user_profile.name], LOG_NAME)

	return is_save_success


# Creates a new user profile with the given name, using the currently loaded mods as the mod list.
static func create_profile(profile_name: String) -> bool:
	# Verify that the profile name is not already in use
	if ModLoaderStore.user_profiles.has(profile_name):
		ModLoaderLog.error("User profile with the name of \"%s\" already exists." % profile_name, LOG_NAME)
		return false

	var mod_list := _generate_mod_list()

	var new_profile := _create_new_profile(profile_name, mod_list)

	# If there was an error creating the new user profile return
	if not new_profile:
		return false

	# Set it as the current profile
	ModLoaderStore.current_user_profile = new_profile

	# Store the new profile in the ModLoaderStore
	ModLoaderStore.user_profiles[profile_name] = new_profile

	# Store the new profile in the json file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Created new user profile \"%s\"" % profile_name, LOG_NAME)

	return is_save_success


# Sets the current user profile to the profile with the specified profile_name.
static func set_profile(user_profile: ModUserProfile) -> bool:
	# Check if the profile name is unique
	if not ModLoaderStore.user_profiles.has(user_profile.name):
		ModLoaderLog.error("User profile with name \"%s\" not found." % user_profile.name, LOG_NAME)
		return false

	# Update the current_user_profile in the ModLoaderStore
	ModLoaderStore.current_user_profile = user_profile

	# Save changes in the json file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Current user profile set to \"%s\"" % user_profile.name, LOG_NAME)

	return is_save_success


# Deletes a user profile with the given profile_name.
static func delete_profile(user_profile: ModUserProfile) -> bool:
	# If the current_profile is about to get deleted log an error
	if ModLoaderStore.current_user_profile.name == user_profile.name:
		ModLoaderLog.error(str(
			"You cannot delete the currently selected user profile \"%s\" " +
			"because it is currently in use. Please switch to a different profile before deleting this one.") % user_profile.name,
		LOG_NAME)
		return false

	# Deleting the default profile is not allowed
	if user_profile.name == "default":
		ModLoaderLog.error("You can't delete the default profile", LOG_NAME)
		return false

	# Delete the user profile
	if not ModLoaderStore.user_profiles.erase(user_profile.name):
		# Erase returns false if the the key is not present in user_profiles
		ModLoaderLog.error("User profile with name \"%s\" not found." % user_profile.name, LOG_NAME)
		return false

	# Save profiles to the user profiles JSON file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Deleted user profile \"%s\"" % user_profile.name, LOG_NAME)

	return is_save_success


# Returns the current user profile
static func get_current() -> ModUserProfile:
	return ModLoaderStore.current_user_profile


# Return the user profile with the given name
static func get_profile(profile_name: String) -> ModUserProfile:
	if not ModLoaderStore.user_profiles.has(profile_name):
		ModLoaderLog.error("User profile with name \"%s\" not found." % profile_name, LOG_NAME)
		return null

	return ModLoaderStore.user_profiles[profile_name]


# Returns an array containing all user profiles stored in ModLoaderStore
static func get_all_as_array() -> Array:
	var user_profiles := []

	for user_profile_name in ModLoaderStore.user_profiles.keys():
		user_profiles.push_back(ModLoaderStore.user_profiles[user_profile_name])

	return user_profiles


# Internal profile functions
# =============================================================================

# Update the global list of disabled mods based on the current user profile
# The user profile will override the disabled_mods property that can be set via the options resource in the editor.
# Example: If "Mod-TestMod" is set in disabled_mods via the editor, the mod will appear disabled in the user profile.
# If the user then enables the mod in the profile the entry in disabled_mods will be removed.
static func _update_disabled_mods() -> void:
	var user_profile_disabled_mods := []
	var current_user_profile: ModUserProfile

	# Check if a current user profile is set
	if not ModLoaderStore.current_user_profile:
		ModLoaderLog.info("There is no current user profile. The \"default\" profile will be created.", LOG_NAME)
		return

	current_user_profile = get_current()

	# Iterate through the mod list in the current user profile to find disabled mods
	for mod_id in current_user_profile.mod_list:
		if not current_user_profile.mod_list[mod_id].is_active:
			user_profile_disabled_mods.push_back(mod_id)

	# Append the disabled mods to the global list of disabled mods
	ModLoaderStore.ml_options.disabled_mods.append_array(user_profile_disabled_mods)

	ModLoaderLog.debug(
		"Updated the global list of disabled mods \"%s\", based on the current user profile \"%s\""
		% [ModLoaderStore.ml_options.disabled_mods, current_user_profile.name],
	LOG_NAME)


# This function updates the mod lists of all user profiles with newly loaded mods that are not already present.
# It does so by comparing the current set of loaded mods with the mod list of each user profile, and adding any missing mods.
# Additionally, it checks for and deletes any mods from each profile's mod list that are no longer installed on the system.
static func _update_mod_lists() -> bool:
	var current_mod_list := _generate_mod_list()

	# Iterate over all user profiles
	for profile_name in ModLoaderStore.user_profiles.keys():
		var profile: ModUserProfile = ModLoaderStore.user_profiles[profile_name]

		# Merge the profiles mod_list with the previously created current_mod_list
		profile.mod_list.merge(current_mod_list)

		var update_mod_list := _update_mod_list(profile.mod_list)

		profile.mod_list = update_mod_list

	# Save the updated user profiles to the JSON file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Updated the mod lists of all user profiles", LOG_NAME)

	return is_save_success


# Updates the mod list by checking the validity of each mod entry and making necessary modifications.
static func _update_mod_list(mod_list: Dictionary, mod_data := ModLoaderStore.mod_data) -> Dictionary:
	var updated_mod_list := mod_list.duplicate(true)

	# Iterate over each mod ID in the mod list
	for mod_id in updated_mod_list:
		var mod_list_entry: Dictionary = updated_mod_list[mod_id]

		# If mod data is accessible and the mod is loaded
		if not mod_data.empty() and mod_data.has(mod_id):
			mod_list_entry = _generate_mod_list_entry(mod_id, true)

		# If mod data is accessible and the mod is not loaded
		if not mod_data.empty() and not mod_data.has(mod_id):
			# Check if the mod_dir for the mod-id exists
			if not _ModLoaderFile.dir_exists(_ModLoaderPath.get_unpacked_mods_dir_path() + mod_id):
				# If the mod directory doesn't exist,
				# the mod is no longer installed and can be removed from the mod list
				updated_mod_list.erase(mod_id)
				continue

		# Check if the current config doesn't exist
		# This can happen if the config file was manually deleted
		if mod_list_entry.has("current_config") and _ModLoaderPath.get_path_to_mod_config_file(mod_id, mod_list_entry.current_config).empty():
			# If the current config doesn't exist, reset it to the default configuration
			mod_list_entry.current_config = ModLoaderConfig.DEFAULT_CONFIG_NAME

		updated_mod_list[mod_id] = mod_list_entry

	return updated_mod_list


# Generates a dictionary with data to be stored for each mod.
static func _generate_mod_list() -> Dictionary:
	var mod_list := {}

	# Create a mod_list with the currently loaded mods
	for mod_id in ModLoaderStore.mod_data.keys():
		mod_list[mod_id] = _generate_mod_list_entry(mod_id, true)

	# Add the deactivated mods to the list
	for mod_id in ModLoaderStore.ml_options.disabled_mods:
		mod_list[mod_id] = _generate_mod_list_entry(mod_id, false)

	return mod_list


# Generates a mod list entry dictionary with the given mod ID and active status.
# If the mod has a config schema, sets the 'current_config' key to the current_config stored in the Mods ModData.
static func _generate_mod_list_entry(mod_id: String, is_active: bool) -> Dictionary:
	var mod_list_entry := {}

	mod_list_entry.is_active = is_active
	# Set the current_config if the mod has a config schema and is active
	if is_active and not ModLoaderConfig.get_config_schema(mod_id).empty():
		var current_config: ModConfig = ModLoaderStore.mod_data[mod_id].current_config
		if current_config and current_config.is_valid:
			# Set to the current_config name if valid
			mod_list_entry.current_config = current_config.name
		else:
			# If not valid revert to the default config
			mod_list_entry.current_config = ModLoaderConfig.DEFAULT_CONFIG_NAME

	return mod_list_entry


# Handles the activation or deactivation of a mod in a user profile.
static func _set_mod_state(mod_id: String, profile_name: String, activate: bool) -> bool:
	# Verify whether the mod_id is present in the profile's mod_list.
	if not _is_mod_id_in_mod_list(mod_id, profile_name):
		return false

	# Check if it is a locked mod
	if ModLoaderStore.mod_data.has(mod_id) and ModLoaderStore.mod_data[mod_id].is_locked:
		ModLoaderLog.error(
			"Unable to disable mod \"%s\" as it is marked as locked. Locked mods: %s"
			% [mod_id, ModLoaderStore.ml_options.locked_mods],
		LOG_NAME)
		return false

	# Handle mod state
	ModLoaderStore.user_profiles[profile_name].mod_list[mod_id].is_active = activate

	# Save profiles to the user profiles JSON file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Mod activation state changed: mod_id=%s activate=%s profile_name=%s" % [mod_id, activate, profile_name], LOG_NAME)

	return is_save_success


# Checks whether a given mod_id is present in the mod_list of the specified user profile.
# Returns True if the mod_id is present, False otherwise.
static func _is_mod_id_in_mod_list(mod_id: String, profile_name: String) -> bool:
	# Get the user profile
	var user_profile := get_profile(profile_name)
	if not user_profile:
		# Return false if there is an error getting the user profile
		return false

	# Return false if the mod_id is not in the profile's mod_list
	if not user_profile.mod_list.has(mod_id):
		ModLoaderLog.error("Mod id \"%s\" not found in the \"mod_list\" of user profile \"%s\"." % [mod_id, profile_name], LOG_NAME)
		return false

	# Return true if the mod_id is in the profile's mod_list
	return true


# Creates a new Profile with the given name and mod list.
# Returns the newly created Profile object.
static func _create_new_profile(profile_name: String, mod_list: Dictionary) -> ModUserProfile:
	var new_profile := ModUserProfile.new()

	# If no name is provided, log an error and return null
	if profile_name == "":
		ModLoaderLog.error("Please provide a name for the new profile", LOG_NAME)
		return null

	# Set the profile name
	new_profile.name = profile_name

	# If no mods are specified in the mod_list, log a warning and return the new profile
	if mod_list.keys().size() == 0:
		ModLoaderLog.warning("No mod_ids inside \"mod_list\" for user profile \"%s\" " % profile_name, LOG_NAME)
		return new_profile

	# Set the mod_list
	new_profile.mod_list = _update_mod_list(mod_list)

	return new_profile


# Loads user profiles from the JSON file and adds them to ModLoaderStore.
static func _load() -> bool:
	# Load JSON data from the user profiles file
	var data := _ModLoaderFile.get_json_as_dict(FILE_PATH_USER_PROFILES)

	# If there is no data, log an error and return
	if data.empty():
		ModLoaderLog.error("No profile file found at \"%s\"" % FILE_PATH_USER_PROFILES, LOG_NAME)
		return false

	# Set the current user profile to the one specified in the data
	var current_user_profile: ModUserProfile = ModUserProfile.new()
	current_user_profile.name = data.current_profile
	current_user_profile.mod_list = data.profiles[data.current_profile].mod_list
	ModLoaderStore.current_user_profile = current_user_profile

	# Loop through each profile in the data and add them to ModLoaderStore
	for profile_name in data.profiles.keys():
		# Get the profile data from the JSON object
		var profile_data: Dictionary = data.profiles[profile_name]

		# Create a new profile object and add it to ModLoaderStore.user_profiles
		var new_profile := _create_new_profile(profile_name, profile_data.mod_list)
		ModLoaderStore.user_profiles[profile_name] = new_profile

	return true


# Saves the user profiles in the ModLoaderStore to the user profiles JSON file.
static func _save() -> bool:
	# Initialize a dictionary to hold the serialized user profiles data
	var save_dict := {
		"current_profile": "",
		"profiles": {}
	}

	# Set the current profile name in the save_dict
	save_dict.current_profile = ModLoaderStore.current_user_profile.name

	# Serialize the mod_list data for each user profile and add it to the save_dict
	for profile_name in ModLoaderStore.user_profiles.keys():
		var profile: ModUserProfile = ModLoaderStore.user_profiles[profile_name]

		# Init the profile dict
		save_dict.profiles[profile.name] = {}
		# Init the mod_list dict
		save_dict.profiles[profile.name].mod_list = profile.mod_list

	# Save the serialized user profiles data to the user profiles JSON file
	return _ModLoaderFile.save_dictionary_to_json_file(save_dict, FILE_PATH_USER_PROFILES)
