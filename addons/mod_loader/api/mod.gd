# This Class provides helper functions to build mods.
class_name ModLoaderMod
extends Object


const LOG_NAME := "ModLoader:Mod"


# Install a script extension that extends a vanilla script.
# The child_script_path should point to your mod's extender script.
#
# Example: `"MOD/extensions/singletons/utils.gd"`
#
# Inside the extender script, include `extends {target}` where `{target}` is the vanilla path.
#
# Example: `extends "res://singletons/utils.gd"`.
#
# *Note: Your extender script doesn't have to follow the same directory path as the vanilla file,
# but it's good practice to do so.*
#
# Parameters:
# - child_script_path (String): The path to the mod's extender script.
#
# Returns: void
static func install_script_extension(child_script_path: String) -> void:

	var mod_id: String = _ModLoaderPath.get_mod_dir(child_script_path)
	var mod_data: ModData = get_mod_data(mod_id)
	if not ModLoaderStore.saved_extension_paths.has(mod_data.manifest.get_mod_id()):
		ModLoaderStore.saved_extension_paths[mod_data.manifest.get_mod_id()] = []
	ModLoaderStore.saved_extension_paths[mod_data.manifest.get_mod_id()].append(child_script_path)

	# If this is called during initialization, add it with the other
	# extensions to be installed taking inheritance chain into account
	if ModLoaderStore.is_initializing:
		ModLoaderStore.script_extensions.push_back(child_script_path)

	# If not, apply the extension directly
	else:
		_ModLoaderScriptExtension.apply_extension(child_script_path)


# Register an array of classes to the global scope since Godot only does that in the editor.
#
# Format: `{ "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }`
#
# *Note: You can find these easily in the project.godot file under `_global_script_classes`
# (but you should only include classes belonging to your mod)*
#
# Parameters:
# - new_global_classes (Array): An array of class definitions to be registered.
#
# Returns: void
static func register_global_classes_from_array(new_global_classes: Array) -> void:
	ModLoaderUtils.register_global_classes_from_array(new_global_classes)
	var _savecustom_error: int = ProjectSettings.save_custom(_ModLoaderPath.get_override_path())


# Add a translation file.
#
# *Note: The translation file should have been created in Godot already,
# such as when importing a CSV file. The translation file should be in the format `mytranslation.en.translation`.*
#
# Parameters:
# - resource_path (String): The path to the translation resource file.
#
# Returns: void
static func add_translation(resource_path: String) -> void:
	if not _ModLoaderFile.file_exists(resource_path):
		ModLoaderLog.fatal("Tried to load a position resource from a file that doesn't exist. The invalid path was: %s" % [resource_path], LOG_NAME)
		return

	var translation_object: Translation = load(resource_path)
	TranslationServer.add_translation(translation_object)
	ModLoaderLog.info("Added Translation from Resource -> %s" % resource_path, LOG_NAME)


# Refreshes a specific scene by marking it for refresh.
#
# This function is useful if a script extension is not automatically applied.
# This situation can occur when a script is attached to a preloaded scene.
# If you encounter issues where your script extension is not working as expected,
# try to identify the scene to which it is attached and use this method to refresh it.
# This will reload already loaded scenes and apply the script extension.
#
# Parameters:
# - scene_path (String): The path to the scene file to be refreshed.
#
# Returns: void
static func refresh_scene(scene_path: String) -> void:
	if scene_path in ModLoaderStore.scenes_to_refresh:
		return

	ModLoaderStore.scenes_to_refresh.push_back(scene_path)
	ModLoaderLog.debug("Added \"%s\" to be refreshed." % scene_path, LOG_NAME)


# Extends a specific scene by providing a callable function to modify it.
# The callable receives an instance of the vanilla_scene as the first parameter.
#
# Parameters:
# - scene_vanilla_path (String): The path to the vanilla scene file.
# - edit_callable (Callable): The callable function to modify the scene.
#
# Returns: void
static func extend_scene(scene_vanilla_path: String, edit_callable: Callable) -> void:
	if not ModLoaderStore.scenes_to_modify.has(scene_vanilla_path):
		ModLoaderStore.scenes_to_modify[scene_vanilla_path] = []

	ModLoaderStore.scenes_to_modify[scene_vanilla_path].push_back(edit_callable)


# Gets the ModData from the provided namespace
#
# Parameters:
# - mod_id (String): The ID of the mod.
#
# Returns:
# - ModData: The ModData associated with the provided mod_id, or null if the mod_id is invalid.
static func get_mod_data(mod_id: String) -> ModData:
	if not ModLoaderStore.mod_data.has(mod_id):
		ModLoaderLog.error("%s is an invalid mod_id" % mod_id, LOG_NAME)
		return null

	return ModLoaderStore.mod_data[mod_id]


# Gets the ModData of all loaded Mods as Dictionary.
#
# Returns:
# - Dictionary: A dictionary containing the ModData of all loaded mods.
static func get_mod_data_all() -> Dictionary:
	return ModLoaderStore.mod_data


# Returns the path to the directory where unpacked mods are stored.
#
# Returns:
# - String: The path to the unpacked mods directory.
static func get_unpacked_dir() -> String:
	return _ModLoaderPath.get_unpacked_mods_dir_path()


# Returns true if the mod with the given mod_id was successfully loaded.
#
# Parameters:
# - mod_id (String): The ID of the mod.
#
# Returns:
# - bool: true if the mod is loaded, false otherwise.
static func is_mod_loaded(mod_id: String) -> bool:
	if ModLoaderStore.is_initializing:
		ModLoaderLog.warning(
			"The ModLoader is not fully initialized. " +
			"Calling \"is_mod_loaded()\" in \"_init()\" may result in an unexpected return value as mods are still loading.",
			LOG_NAME
		)

	# If the mod is not present in the mod_data dictionary or the mod is flagged as not loadable.
	if not ModLoaderStore.mod_data.has(mod_id) or not ModLoaderStore.mod_data[mod_id].is_loadable:
		return false

	return true


# Returns true if the mod with the given mod_id was successfully loaded and is currently active.
#
# Parameters:
# - mod_id (String): The ID of the mod.
#
# Returns:
# - bool: true if the mod is loaded and active, false otherwise.
static func is_mod_active(mod_id: String) -> bool:
	return is_mod_loaded(mod_id) and ModLoaderStore.mod_data[mod_id].is_active
