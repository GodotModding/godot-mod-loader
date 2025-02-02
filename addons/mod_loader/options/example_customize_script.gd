extends RefCounted
# This is an example script for the ModLoaderOptionsProfile customize_script_path.
# Ideally you position this script outside of the mod_loader dir to make the update process easier.


# This script is loaded after the `mod_loader_store.ml_options` has been initialized.
# The script is initialized with the ml_options as argument use it to apply any settings you cant
# apply with the editor UI.
func _init(ml_options: ModLoaderOptionsProfile) -> void:
	# Use OS.has_feature() to only apply changes to specific feature tags,
	# or create multiple cutomization scripts and set the paths arcordingly in the option profiles.
	if OS.has_feature("Steam"):
		pass
	elif OS.has_feature("Epic"):
		pass
	else:
		# Here the `custom_game_version_validation_callable` is set to use a custom validation function.
		ml_options.custom_game_version_validation_callable = custom_is_game_version_compatible


# This is the custom validation function
# See ModManifest._is_game_version_compatible() for the default validation.
func custom_is_game_version_compatible(manifest: ModManifest) -> bool:
	print("! ☞ﾟヮﾟ)☞ CUSTOM VALIDATION HERE ☜ﾟヮﾟ☜) !")

	var mod_id := manifest.get_mod_id()

	for version in manifest.compatible_game_version:
		if not version == "pizza":
			# Push warnings that are displayed after manifest validation has completed.
			manifest.validation_messages_warning.push_back(
			"The mod \"%s\" may not be compatible with the current game version.
			Enable at your own risk. (current game version: %s, mod compatible with game versions: %s)" %
			[mod_id, "MyGlobalVars.MyGameVersion", manifest.compatible_game_version]
			)
			return true

		if not version == "pineapple":
			# Push errors that are displayed after manifest validation has completed.
			manifest.validation_messages_error.push_back(
				"The mod \"%s\" is incompatible with the current game version.
				(current game version: %s, mod compatible with game versions: %s)" %
				[mod_id, "MyGlobalVars.MyGameVersion", manifest.compatible_game_version]
			)
			return false

	return true
