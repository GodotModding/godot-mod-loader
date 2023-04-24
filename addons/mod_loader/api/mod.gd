class_name ModLoaderMod
extends Object

# Helper functions to build mods

const LOG_NAME := "ModLoader:Mod"


# Add a script that extends a vanilla script. `child_script_path` should point
# to your mod's extender script, eg "MOD/extensions/singletons/utils.gd".
# Inside that extender script, it should include "extends {target}", where
# {target} is the vanilla path, eg: `extends "res://singletons/utils.gd"`.
# Note that your extender script doesn't have to follow the same directory path
# as the vanilla file, but it's good practice to do so.
static func install_script_extension(child_script_path:String) -> void:

	# If this is called during initialization, add it with the other
	# extensions to be installed taking inheritance chain into account
	if ModLoaderStore.is_initializing:
		ModLoaderStore.script_extensions.push_back(child_script_path)

	# If not, apply the extension directly
	else:
		_ModLoaderScriptExtension.apply_extension(child_script_path)


static func uninstall_script_extension(extension_script_path: String) -> void:
	# Currently this is the only thing we do, but it is better to expose
	# this function like this for further changes
	_ModLoaderScriptExtension.remove_specific_extension_from_script(extension_script_path)


# This function should be called only when actually necessary
# as it can break the game and require a restart for mods
# that do not fully use the systems put in place by the mod loader,
# so anything that just uses add_node, move_node ecc...
# To not have your mod break on reload please use provided functions
# like ModLoader::save_scene, ModLoader::append_node_in_scene and
# all the functions that will be added in the next versions
# Used to reload already present mods and load new ones
func reload_mods() -> void:

	# Currently this is the only thing we do, but it is better to expose
	# this function like this for further changes
	ModLoader._reload_mods()


# Register an array of classes to the global scope, since Godot only does that in the editor.
# Format: { "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }
# You can find these easily in the project.godot file under "_global_script_classes"
# (but you should only include classes belonging to your mod)
static func register_global_classes_from_array(new_global_classes: Array) -> void:
	ModLoaderUtils.register_global_classes_from_array(new_global_classes)
	var _savecustom_error: int = ProjectSettings.save_custom(_ModLoaderPath.get_override_path())


# Add a translation file, eg "mytranslation.en.translation". The translation
# file should have been created in Godot already: When you import a CSV, such
# a file will be created for you.
static func add_translation_from_resource(resource_path: String) -> void:
	if not _ModLoaderFile.file_exists(resource_path):
		ModLoaderLog.fatal("Tried to load a translation resource from a file that doesn't exist. The invalid path was: %s" % [resource_path], LOG_NAME)
		return

	var translation_object: Translation = load(resource_path)
	TranslationServer.add_translation(translation_object)
	ModLoaderLog.info("Added Translation from Resource -> %s" % resource_path, LOG_NAME)


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


static func save_scene(modified_scene: Node, scene_path: String) -> void:
	var packed_scene := PackedScene.new()
	var _pack_error := packed_scene.pack(modified_scene)
	ModLoaderLog.debug("packing scene -> %s" % packed_scene, LOG_NAME)
	packed_scene.take_over_path(scene_path)
	ModLoaderLog.debug("save_scene - taking over path - new path -> %s" % packed_scene.resource_path, LOG_NAME)
	ModLoaderStore.saved_objects.append(packed_scene)


static func get_unpacked_dir() -> String:
	return _ModLoaderPath.get_unpacked_mods_dir_path()
