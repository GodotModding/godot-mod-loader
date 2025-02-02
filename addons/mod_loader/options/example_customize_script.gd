extends RefCounted

# This is an example script for the ModLoaderOptionsProfile `customize_script_path`.
# Ideally, place this script outside the `mod_loader` directory to simplify the update process.

# This script is loaded after `mod_loader_store.ml_options` has been initialized.
# It receives `ml_options` as an argument, allowing you to apply settings
# that cannot be configured through the editor UI.
func _init(ml_options: ModLoaderOptionsProfile) -> void:
	# Use OS.has_feature() to apply changes only for specific platforms,
	# or create multiple customization scripts and set their paths accordingly in the option profiles.
	if OS.has_feature("Steam"):
		pass
	elif OS.has_feature("Epic"):
		pass
	else:
		# Set `custom_game_version_validation_callable` to use a custom validation function.
		ml_options.custom_game_version_validation_callable = custom_is_game_version_compatible

# Custom validation function
# See `ModManifest._is_game_version_compatible()` for the default validation logic.
func custom_is_game_version_compatible(manifest: ModManifest) -> bool:
	print("! ☞ﾟヮﾟ)☞ CUSTOM VALIDATION HERE ☜ﾟヮﾟ☜) !")

	var mod_id := manifest.get_mod_id()

	for version in manifest.compatible_game_version:
		if not version == "pizza":
			# Push a warning message displayed after manifest validation is complete.
			manifest.validation_messages_warning.push_back(
				"The mod \"%s\" may not be compatible with the current game version.
				Enable at your own risk. (Current game version: %s, mod compatible with game versions: %s)" %
				[mod_id, "MyGlobalVars.MyGameVersion", manifest.compatible_game_version]
			)
			return true

		if not version == "pineapple":
			# Push an error message displayed after manifest validation is complete.
			manifest.validation_messages_error.push_back(
				"The mod \"%s\" is incompatible with the current game version.
				(Current game version: %s, mod compatible with game versions: %s)" %
				[mod_id, "MyGlobalVars.MyGameVersion", manifest.compatible_game_version]
			)
			return false

	return true
