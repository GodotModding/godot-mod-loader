extends SceneTree

const LOG_NAME := "ModLoader:Setup"

const settings := {
	"MOD_LOADER_AUTOLOAD": "autoload/ModLoader",
}

# see: [method ModLoaderUtils.register_global_classes_from_array]
const new_global_classes := [
	{
		"base": "Resource",
		"class": "ModData",
		"language": "GDScript",
		"path": "res://addons/mod_loader/mod_data.gd"
	}, {
		"base": "Node",
		"class": "ModLoaderUtils",
		"language": "GDScript",
		"path": "res://addons/mod_loader/mod_loader_utils.gd"
	}, {
		"base": "Resource",
		"class": "ModManifest",
		"language": "GDScript",
		"path": "res://addons/mod_loader/mod_manifest.gd"
	}
]

# IMPORTANT: use the ModLoaderUtils via this variable within this script!
# Otherwise, script compilation will break on first load since the class is not defined.
var modloaderutils: Node = load("res://addons/mod_loader/mod_loader_utils.gd").new()


func _init() -> void:
	try_setup_modloader()
	change_scene(ProjectSettings.get_setting("application/run/main_scene"))


# Set up the ModLoader, if it hasn't been set up yet
func try_setup_modloader() -> void:
	# Avoid doubling the setup work
	if is_loader_set_up():
		modloaderutils.log_info("ModLoader is available, mods can be loaded!", LOG_NAME)
		OS.set_window_title("%s (Modded)" % ProjectSettings.get_setting("application/config/name"))
		return
	
	setup_modloader()


# Set up the ModLoader as an autoload and register the other global classes.
# Saved as override.cfg besides the game executable to extend the existing project settings
func setup_modloader() -> void:
	modloaderutils.log_info("Setting up ModLoader", LOG_NAME)

	# Register all new helper classes as global
	modloaderutils.register_global_classes_from_array(new_global_classes)

	# We need the original autoloads to add them back after the ModLoader autoload
	var original_autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.name
		if name.begins_with("autoload/"):
			var value: String = ProjectSettings.get_setting(name)
			original_autoloads[name] = value
			
	# Remove all existing autoloads to add them after the ModLoader
	for autoload in original_autoloads.keys():
		ProjectSettings.clear(autoload)

	# Add ModLoader autoload (the * marks the path as autoload)
	ProjectSettings.set_setting(settings.MOD_LOADER_AUTOLOAD, "*res://addons/mod_loader/mod_loader.gd")
	
	# Add back all previous autoloads after the ModLoader is setup
	for autoload in original_autoloads.keys():
		ProjectSettings.set_setting(autoload, original_autoloads[autoload])
		
	ProjectSettings.save()

	modloaderutils.log_info("ModLoader is set up, but the game needs to be restarted", LOG_NAME)
	OS.alert("The Godot ModLoader has been set up. Restart the game to apply the changes. Confirm to quit.")
	quit()


func is_loader_set_up() -> bool:
	return ProjectSettings.has_setting(settings.MOD_LOADER_AUTOLOAD)
