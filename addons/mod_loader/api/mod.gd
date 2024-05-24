class_name ModLoaderMod
extends Object
##
## This Class provides helper functions to build mods.
##
## @tutorial(Script Extensions):	https://github.com/GodotModding/godot-mod-loader/wiki/Script-Extensions
## @tutorial(Mod Structure):		https://github.com/GodotModding/godot-mod-loader/wiki/Mod-Structure
## @tutorial(Mod Files):			https://github.com/GodotModding/godot-mod-loader/wiki/Mod-Files


const LOG_NAME := "ModLoader:Mod"


## Installs a script extension that extends a vanilla script.[br]
## The [code]child_script_path[/code] should point to your mod's extender script.[br]
## Example: [code]"MOD/extensions/singletons/utils.gd"[/code][br]
## Inside the extender script, include [code]extends {target}[/code] where [code]{target}[/code] is the vanilla path.[br]
## Example: [code]extends "res://singletons/utils.gd"[/code].[br]
##
## [b]Note:[/b] Your extender script doesn't have to follow the same directory path as the vanilla file,
## but it's good practice to do so.[br]
##
## [br][b]Parameters:[/b][br]
## - [code]child_script_path[/code] (String): The path to the mod's extender script.[br]
##
## [br][b]Returns:[/b] [code]void[/code][br]
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


## Registers an array of classes to the global scope since Godot only does that in the editor.[br]
##
## Format: [code]{ "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }[/code][br]
##
## [b]Note:[/b] You can find these easily in the project.godot file under `_global_script_classes`
## (but you should only include classes belonging to your mod)[br]
##
## [br][b]Parameters:[/b][br]
## - [code]new_global_classes[/code] (Array): An array of class definitions to be registered.[br]
##
## [br][b]Returns:[/b] [code]void[/code][br]
static func register_global_classes_from_array(new_global_classes: Array) -> void:
	ModLoaderUtils.register_global_classes_from_array(new_global_classes)
	var _savecustom_error: int = ProjectSettings.save_custom(_ModLoaderPath.get_override_path())


## Adds a translation file.[br]
##[br]
## [i]Note: The translation file should have been created in Godot already,
## such as when importing a CSV file. The translation file should be in the format  [code]mytranslation.en.translation[/code].[/i][br]
##
## [br][b]Parameters:[/b][br]
## - [code]resource_path[/code] (String): The path to the translation resource file.[br]
##
## [br][b]Returns:[/b] [code]void[/code][br]
static func add_translation(resource_path: String) -> void:
	if not _ModLoaderFile.file_exists(resource_path):
		ModLoaderLog.fatal("Tried to load a position resource from a file that doesn't exist. The invalid path was: %s" % [resource_path], LOG_NAME)
		return

	var translation_object: Translation = load(resource_path)
	TranslationServer.add_translation(translation_object)
	ModLoaderLog.info("Added Translation from Resource -> %s" % resource_path, LOG_NAME)

## [i]Note: This function requires Godot 4.3 or higher.[/i][br]
##[br]
## Refreshes a specific scene by marking it for refresh.[br]
##[br]
## This function is useful if a script extension is not automatically applied.
## This situation can occur when a script is attached to a preloaded scene.
## If you encounter issues where your script extension is not working as expected,
## try to identify the scene to which it is attached and use this method to refresh it.
## This will reload already loaded scenes and apply the script extension.
##[br]
## [br][b]Parameters:[/b][br]
## - [code]scene_path[/code] (String): The path to the scene file to be refreshed.
##[br]
## [br][b]Returns:[/b] [code]void[/code][br]
static func refresh_scene(scene_path: String) -> void:
	if scene_path in ModLoaderStore.scenes_to_refresh:
		return

	ModLoaderStore.scenes_to_refresh.push_back(scene_path)
	ModLoaderLog.debug("Added \"%s\" to be refreshed." % scene_path, LOG_NAME)


## Extends a specific scene by providing a callable function to modify it.
## The callable receives an instance of the "vanilla_scene" as the first parameter.[br]
##
## [br][b]Parameters:[/b][br]
## - [code]scene_vanilla_path[/code] (String): The path to the vanilla scene file.[br]
## - [code]edit_callable[/code] (Callable): The callable function to modify the scene.[br]
##
## [br][b]Returns:[/b] [code]void[/code][br]
static func extend_scene(scene_vanilla_path: String, edit_callable: Callable) -> void:
	if not ModLoaderStore.scenes_to_modify.has(scene_vanilla_path):
		ModLoaderStore.scenes_to_modify[scene_vanilla_path] = []

	ModLoaderStore.scenes_to_modify[scene_vanilla_path].push_back(edit_callable)


## Gets the [ModData] from the provided namespace.[br]
##
## [br][b]Parameters:[/b][br]
## - [code]mod_id[/code] (String): The ID of the mod.[br]
##
## [br][b]Returns:[/b][br]
## - [ModData]: The [ModData] associated with the provided [code]mod_id[/code], or null if the [code]mod_id[/code] is invalid.[br]
static func get_mod_data(mod_id: String) -> ModData:
	if not ModLoaderStore.mod_data.has(mod_id):
		ModLoaderLog.error("%s is an invalid mod_id" % mod_id, LOG_NAME)
		return null

	return ModLoaderStore.mod_data[mod_id]


## Gets the [ModData] of all loaded Mods as [Dictionary].[br]
##
## [br][b]Returns:[/b][br]
## - [Dictionary]: A dictionary containing the [ModData] of all loaded mods.[br]
static func get_mod_data_all() -> Dictionary:
	return ModLoaderStore.mod_data


## Returns the path to the directory where unpacked mods are stored.[br]
##
## [br][b]Returns:[/b][br]
## - [String]: The path to the unpacked mods directory.[br]
static func get_unpacked_dir() -> String:
	return _ModLoaderPath.get_unpacked_mods_dir_path()


## Returns true if the mod with the given [code]mod_id[/code] was successfully loaded.[br]
##
## [br][b]Parameters:[/b][br]
## - [code]mod_id[/code] (String): The ID of the mod.[br]
##
## [br][b]Returns:[/b][br]
## - [bool]: true if the mod is loaded, false otherwise.[br]
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
