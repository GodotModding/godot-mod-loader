extends SceneTree

const LOG_NAME := "ModLoader:Setup"

const settings := {
	"IS_LOADER_SETUP_APPLIED": "application/run/is_loader_setup_applied",
	"IS_LOADER_SET_UP": "application/run/is_loader_set_up",
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
	modloaderutils.log_debug("Mod-Loader setup initialized", LOG_NAME)
	try_setup_modloader()
	change_scene(ProjectSettings.get_setting("application/run/main_scene"))


# Set up the ModLoader, if it hasn't been set up yet
func try_setup_modloader() -> void:
	# Avoid doubling the setup work
	if is_loader_setup_applied():
		modloaderutils.log_info("ModLoader is available, mods can be loaded!", LOG_NAME)
		OS.set_window_title("%s (Modded)" % ProjectSettings.get_setting("application/config/name"))
		return

	var pck_name : String = modloaderutils.get_cmd_line_arg_value("--pck-name")
	var exe_path : String = modloaderutils.get_local_folder_dir()
	modloaderutils.log_debug("exe_path -> " + exe_path, LOG_NAME)

# remove and re-add autoloads
	var original_autoloads := {}
	for prop in ProjectSettings.get_property_list():
			var name: String = prop.name
			if name.begins_with("autoload/"):
					var value: String = ProjectSettings.get_setting(name)
					original_autoloads[name] = value

	for autoload in original_autoloads.keys():
			ProjectSettings.set_setting(autoload, null)

	# add ModLoader autoload (the * marks the path as autoload)
	ProjectSettings.set_setting("autoload/ModLoader", "*" + "res://addons/mod_loader/mod_loader.gd")

	# add all previous autoloads back again
	for autoload in original_autoloads.keys():
			ProjectSettings.set_setting(autoload, original_autoloads[autoload])

	# save the current project settings to a new project.binary
	ProjectSettings.save_custom(exe_path + "addons/mod_loader/project.binary")

	# C:/path/to/game/addons/mod_loader
	var mod_loader_dir_path := exe_path + "addons/mod_loader"
	modloaderutils.log_debug("mod_loader_dir_path -> " + mod_loader_dir_path, LOG_NAME)

	# C:/path/to/game/addons/mod_loader/godotpcktool/godotpcktool.exe
	var pck_tool_path := mod_loader_dir_path + "/godotpcktool/godotpcktool.exe"
	modloaderutils.log_debug("pck_tool_path -> " + pck_tool_path, LOG_NAME)

	# TODO: Pck potentially embedded in the games .exe
	# C:/path/to/game/game.pck
	var pck_path := exe_path + pck_name
	modloaderutils.log_debug("pck_path -> " + pck_path, LOG_NAME)

	# C:/path/to/game/addons/mod_loader/project.binary
	var project_binary_path := mod_loader_dir_path + "/project.binary"
	modloaderutils.log_debug("project_binary_path -> " + project_binary_path, LOG_NAME)

	# Create a backup of the original pck
	var output_backup_pck := []
	var _exit_code_backup_pck := OS.execute(pck_tool_path, ["--pack", pck_path, "--action", "repack", " " + pck_name + "_backup"])
	modloaderutils.log_debug(output_backup_pck, LOG_NAME)
	modloaderutils.log_debug_json_print("Creating a backup of the original pck", output_backup_pck, LOG_NAME)

	# Add modified binary to the pck
	var output_add_project_binary := []
	var _exit_code_add_project_binary := OS.execute(pck_tool_path, ["--pack", pck_path, "--action", "add", "--file", project_binary_path, "--remove-prefix", mod_loader_dir_path], true, output_add_project_binary)
	modloaderutils.log_debug_json_print("Adding custom project.binaray to res://", output_add_project_binary, LOG_NAME)

	# TODO: Remove unnecessary files after installation?

	setup_modloader()

	# If the loader is set up, but the override is not applied yet,
	# prompt the user to quit and restart the game.
	if is_loader_set_up() and not is_loader_setup_applied():
		modloaderutils.log_info("ModLoader is set up, the game will be restarted", LOG_NAME)

		ProjectSettings.set_setting(settings.IS_LOADER_SETUP_APPLIED, true)
		ProjectSettings.save_custom(modloaderutils.get_override_path())

		# run the game again to apply the changed project settings
		var _exit_code_game_start = OS.execute(exe_path + "Brotato.exe", ["--script", "addons/mod_loader/mod_loader_setup.gd", '--pck-name="Brotato.pck"', "--log-debug"], false)

		# quit the current execution
		quit()


# Set up the ModLoader as an autoload and register the other global classes.
# Saved as override.cfg besides the game executable to extend the existing project settings
func setup_modloader() -> void:
	modloaderutils.log_info("Setting up ModLoader", LOG_NAME)

	# Register all new helper classes as global
	modloaderutils.register_global_classes_from_array(new_global_classes)

	# Add ModLoader autoload (the * marks the path as autoload)
	ProjectSettings.set_setting(settings.MOD_LOADER_AUTOLOAD, "*res://addons/mod_loader/mod_loader.gd")
	ProjectSettings.set_setting(settings.IS_LOADER_SET_UP, true)

	# The game needs to be restarted first, bofore the loader is truly set up
	# Set this here and check it elsewhere to prompt the user for a restart
	ProjectSettings.set_setting(settings.IS_LOADER_SETUP_APPLIED, false)

	ProjectSettings.save_custom(modloaderutils.get_override_path())
	modloaderutils.log_info("ModLoader setup complete", LOG_NAME)


func is_loader_set_up() -> bool:
	return is_project_setting_true(settings.IS_LOADER_SET_UP)


func is_loader_setup_applied() -> bool:
	if not root.get_node_or_null("/root/ModLoader") == null:
		if not is_project_setting_true(settings.IS_LOADER_SETUP_APPLIED):
			modloaderutils.log_info("ModLoader is already set up. No self setup required.", LOG_NAME)
		return true
	return false


static func is_project_setting_true(project_setting: String) -> bool:
	return ProjectSettings.has_setting(project_setting) and\
		ProjectSettings.get_setting(project_setting)



