class_name ModLoaderUserProfile
extends Object


# This Class provides methods for working with user profiles.

const LOG_NAME := "ModLoader:UserProfile"
const FILE_PATH_USER_PROFILES = "user://mod_user_profiles.json"

class Profile:
	extends Reference

	var name := ""
	var mod_list := {}


# API profile functions
# =============================================================================

# Enables a mod - it will be loaded on the next game start
static func enable_mod(mod_id: String, profile_name := ModLoaderStore.current_user_profile) -> bool:
	return _set_mod_state(mod_id, profile_name, true)


# Disables a mod - it will not be loaded on the next game start
static func disable_mod(mod_id: String, profile_name := ModLoaderStore.current_user_profile) -> bool:
	return _set_mod_state(mod_id, profile_name, false)


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
	ModLoaderStore.current_user_profile = profile_name

	# Store the new profile in the ModLoaderStore
	ModLoaderStore.user_profiles[profile_name] = new_profile

	# Store the new profile in the json file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Created new user profile \"%s\"" % profile_name, LOG_NAME)

	return is_save_success


# Sets the current user profile to the specified profile_name.
static func set_profile(profile_name: String) -> bool:
	# Check if there is a user profile with the specified name
	if not ModLoaderStore.user_profiles.has(profile_name):
		ModLoaderLog.error("User profile with name \"%s\" not found." % profile_name, LOG_NAME)
		return false

	# Update the current_user_profile in the ModLoaderStore
	ModLoaderStore.current_user_profile = profile_name

	# Save changes in the json file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Current user profile set to \"%s\"" % profile_name, LOG_NAME)

	return is_save_success


# Deletes a user profile with the given profile_name.
static func delete_profile(profile_name: String) -> bool:
	# If the current_profile is about to get deleted change it to default
	if ModLoaderStore.current_user_profile == profile_name:
		ModLoaderLog.error(str(
			"You cannot delete the currently selected user profile \"%s\" " +
			"because it is currently in use. Please switch to a different profile before deleting this one.") % profile_name,
		LOG_NAME)
		return false

	# Deleting the default profile is not allowed
	if profile_name == "default":
		ModLoaderLog.error("You can't delete the default profile", LOG_NAME)
		return false

	# Delete the user profile
	if not ModLoaderStore.user_profiles.erase(profile_name):
		# Erase returns false if the the key is not present in user_profiles
		ModLoaderLog.error("User profile with name \"%s\" not found." % profile_name, LOG_NAME)
		return false

	# Save profiles to the user profiles JSON file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Deleted user profile \"%s\"" % profile_name, LOG_NAME)

	return is_save_success


# Returns the current user profile
static func get_current() -> Profile:
	return ModLoaderStore.user_profiles[ModLoaderStore.current_user_profile]


# Return the user profile with the given name
static func get_profile(profile_name: String) -> Profile:
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
	var current_user_profile: Profile

	# Check if a current user profile is set
	if ModLoaderStore.current_user_profile == "":
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
		var profile: Profile = ModLoaderStore.user_profiles[profile_name]

		# Merge the profiles mod_list with the previously created current_mod_list
		profile.mod_list.merge(current_mod_list)

		# Delete no longer installed mods
		for mod_id in profile.mod_list:
			# Check if the mod_dir for the mod-id exists
			if not _ModLoaderFile.dir_exists(_ModLoaderPath.get_unpacked_mods_dir_path() + mod_id):
				# if not the mod is no longer installed and can be removed
				profile.mod_list.erase(mod_id)

	# Save the updated user profiles to the JSON file
	var is_save_success := _save()

	if is_save_success:
		ModLoaderLog.debug("Updated the mod lists of all user profiles", LOG_NAME)

	return is_save_success


# Generates a dictionary containing a list of currently loaded and deactivated mods.
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
# If the mod has a config schema, sets the 'current_config' key to 'default'.
static func _generate_mod_list_entry(mod_id: String, is_active: bool) -> Dictionary:
	var mod_list_entry := {}

	mod_list_entry.is_active = is_active
	# Set the current_config if the mod has a config schema
	if not ModLoaderConfig.get_mod_config_schema(mod_id).empty():
		mod_list_entry.current_config = "default"

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
static func _create_new_profile(profile_name: String, mod_list: Dictionary) -> Profile:
	var new_profile := Profile.new()

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
	new_profile.mod_list = mod_list

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
	ModLoaderStore.current_user_profile = data.current_profile

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
	save_dict.current_profile = ModLoaderStore.current_user_profile

	# Serialize the mod_list data for each user profile and add it to the save_dict
	for profile_name in ModLoaderStore.user_profiles.keys():
		var profile: Profile = ModLoaderStore.user_profiles[profile_name]

		# Init the profile dict
		save_dict.profiles[profile.name] = {}
		# Store the mod_list dict
		save_dict.profiles[profile.name].mod_list = profile.mod_list

	# Save the serialized user profiles data to the user profiles JSON file
	return _ModLoaderFile.save_dictionary_to_json_file(save_dict, FILE_PATH_USER_PROFILES)
