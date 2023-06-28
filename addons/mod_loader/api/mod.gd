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

	var mod_id: String = ModLoaderUtils.get_string_in_between(child_script_path, "res://mods-unpacked/", "/")
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
		ModLoaderLog.fatal("Tried to load a translation resource from a file that doesn't exist. The invalid path was: %s" % [resource_path], LOG_NAME)
		return

	var translation_object: Translation = load(resource_path)
	TranslationServer.add_translation(translation_object)
	ModLoaderLog.info("Added Translation from Resource -> %s" % resource_path, LOG_NAME)


# Appends a new node to a modified scene.
#
# Parameters:
# - modified_scene (Node): The modified scene where the node will be appended.
# - node_name (String): (Optional) The name of the new node. Default is an empty string.
# - node_parent (Node): (Optional) The parent node where the new node will be added. Default is null (direct child of modified_scene).
# - instance_path (String): (Optional) The path to a scene resource that will be instantiated as the new node.
#   Default is an empty string resulting in a `Node` instance.
# - is_visible (bool): (Optional) If true, the new node will be visible. Default is true.
#
# Returns: void
static func append_node_in_scene(modified_scene: Node, node_name: String = "", node_parent = null, instance_path: String = "", is_visible: bool = true) -> void:
	var new_node: Node
	if not instance_path == "":
		new_node = load(instance_path).instance()
	else:
		new_node = Node.instance()
	if not node_name == "":
		new_node.name = node_name
	if is_visible == false:
		new_node.visible = false
	if not node_parent == null:
		var tmp_node: Node = modified_scene.get_node(node_parent)
		tmp_node.add_child(new_node)
		new_node.set_owner(modified_scene)
	else:
		modified_scene.add_child(new_node)
		new_node.set_owner(modified_scene)


# Saves a modified scene to a file.
#
# Parameters:
# - modified_scene (Node): The modified scene instance to be saved.
# - scene_path (String): The path to the scene file that will be replaced.
#
# Returns: void
static func save_scene(modified_scene: Node, scene_path: String) -> void:
	var packed_scene := PackedScene.new()
	var _pack_error := packed_scene.pack(modified_scene)
	ModLoaderLog.debug("packing scene -> %s" % packed_scene, LOG_NAME)
	packed_scene.take_over_path(scene_path)
	ModLoaderLog.debug("save_scene - taking over path - new path -> %s" % packed_scene.resource_path, LOG_NAME)
	ModLoaderStore.saved_objects.append(packed_scene)


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
