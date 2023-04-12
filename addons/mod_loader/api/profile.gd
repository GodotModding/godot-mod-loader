class_name ModLoaderUserProfile
extends Object


# This Class provides methods for working with user profiles.

class Profile:
	var name := ""
	var mod_list := {}


# API profile functions
# =============================================================================

static func enable_mod(mod_id: String, profile: String = "Default") -> void:
	pass


static func disable_mod(mod_id: String, profile: String = "Default") -> void:
	pass


static func create(name: String) -> void:
	var new_profile = Profile.new()
	new_profile.name = name

	# Add all currently loaded mods to the mod_list
	for mod_id in ModLoader.mod_data.keys():
		new_profile.mod_list[mod_id] = true

	# Set it as the current profile
	ModLoaderStore.current_user_profile = name

	# Store the new profile in the ModLoaderStore
	ModLoaderStore.user_profiles.push_back(new_profile)

	# Store the new profile in the json file
	_save()


static func update(profile: String) -> void:
	pass


static func delete(profile: String) -> void:
	pass


# Internal profile functions
# =============================================================================

static func _load() -> void:
	pass


static func _save() -> void:
	var save_dict := {
		"current_profile": "",
		"profiles": {}
	}

	save_dict.current_profile = ModLoaderStore.current_user_profile

	for profile in ModLoaderStore.user_profiles:
		save_dict.profiles[profile.name] = {}
		save_dict.profiles[profile.name].mod_list = {}

		for mod_id in profile.mod_list:
			var is_activated: bool = profile.mod_list[mod_id]
			save_dict.profiles[profile.name].mod_list[mod_id] = is_activated

	var _success = ModLoaderUtils.save_dictionary_to_json_file(save_dict, "user://mod_user_profiles.json")

