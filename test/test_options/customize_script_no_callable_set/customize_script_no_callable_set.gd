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
		pass
		# Set `custom_game_version_validation_callable` to use a custom validation function.
		#ml_options.custom_game_version_validation_callable = custom_is_game_version_compatible


# Custom validation function
# See `ModManifest._is_game_version_compatible()` for the default validation logic.
func custom_is_game_version_compatible(manifest: ModManifest) -> bool:
	manifest.validation_messages_warning.push_back("! ☞ﾟヮﾟ)☞ CUSTOM VALIDATION HERE ☜ﾟヮﾟ☜) !")
	return true
