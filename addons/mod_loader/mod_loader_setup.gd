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
		"path": "res://addons/mod_loader/classes/mod_data.gd"
	}, {
		"base": "Node",
		"class": "ModLoaderUtils",
		"language": "GDScript",
		"path": "res://addons/mod_loader/mod_loader_utils.gd"
	}, {
		"base": "Resource",
		"class": "ModManifest",
		"language": "GDScript",
		"path": "res://addons/mod_loader/classes/mod_manifest.gd"
	}, {
		"base": "Resource",
		"class": "ScriptExtensionData",
		"language": "GDScript",
		"path": "res://addons/mod_loader/classes/script_extension_data.gd"
	}, {
		"base": "Resource",
		"class": "ModLoaderCurrentOptions",
		"language": "GDScript",
		"path": "res://addons/mod_loader/classes/options_current.gd"
	}, {
		"base": "Resource",
		"class": "ModLoaderOptionsProfile",
		"language": "GDScript",
		"path": "res://addons/mod_loader/classes/options_profile.gd"
	}, {
		"base": "Node",
		"class": "ModLoaderSteam",
		"language": "GDScript",
		"path": "res://addons/mod_loader/api/third_party/steam.gd"
	}, {
		"base": "Node",
		"class": "ModLoaderDeprecated",
		"language": "GDScript",
		"path": "res://addons/mod_loader/api/deprecated.gd"
	}
]

# IMPORTANT: use the ModLoaderUtils via this variable within this script!
# Otherwise, script compilation will break on first load since the class is not defined.
var modloaderutils: Node = load("res://addons/mod_loader/mod_loader_utils.gd").new()

var path := {}
var file_name := {}
var is_only_setup: bool = modloaderutils.is_running_with_command_line_arg("--only-setup")
var is_setup_create_override_cfg : bool = modloaderutils.is_running_with_command_line_arg("--setup-create-override-cfg")


func _init() -> void:
	modloaderutils.log_debug("ModLoader setup initialized", LOG_NAME)

	var mod_loader_index: int = modloaderutils.get_autoload_index("ModLoader")

	# Avoid doubling the setup work
	# Checks if the ModLoader Node is in the root of the scene tree
	# and if the IS_LOADER_SETUP_APPLIED project setting is there
	if mod_loader_index == 0:
		modded_start()
		return

	# Check if --setup-create-override-cfg is passed,
	# in that case the ModLoader just has to be somewhere in the autoloads.
	if is_setup_create_override_cfg and mod_loader_index != -1:
		modded_start()
		return

	setup_modloader()


# ModLoader already setup - switch to the main scene
func modded_start() -> void:
	modloaderutils.log_info("ModLoader is available, mods can be loaded!", LOG_NAME)

	OS.set_window_title("%s (Modded)" % ProjectSettings.get_setting("application/config/name"))

	var _error_change_scene_main := change_scene(ProjectSettings.get_setting("application/run/main_scene"))


# Set up the ModLoader as an autoload and register the other global classes.
func setup_modloader() -> void:
	modloaderutils.log_info("Setting up ModLoader", LOG_NAME)

	# Setup path and file_name dict with all required paths and file names.
	setup_file_data()

	# Register all new helper classes as global
	modloaderutils.register_global_classes_from_array(new_global_classes)

	# Add ModLoader autoload (the * marks the path as autoload)
	reorder_autoloads()
	ProjectSettings.set_setting(settings.IS_LOADER_SET_UP, true)

	# The game needs to be restarted first, before the loader is truly set up
	# Set this here and check it elsewhere to prompt the user for a restart
	ProjectSettings.set_setting(settings.IS_LOADER_SETUP_APPLIED, false)

	if is_setup_create_override_cfg:
		handle_override_cfg()
	else:
		handle_project_binary()

	# ModLoader is set up. A game restart is required to apply the ProjectSettings.
	modloaderutils.log_info("ModLoader is set up, a game restart is required.", LOG_NAME)

	match true:
		# If the --only-setup cli argument is passed, quit with exit code 0
		is_only_setup:
			quit(0)
		# If no cli argument is passed, show message with OS.alert() and user has to restart the game
		_:
			OS.alert("The Godot ModLoader has been set up. Restart the game to apply the changes. Confirm to quit.")
			quit(0)


# Reorders the autoloads in the project settings, to get the ModLoader on top.
func reorder_autoloads() -> void:
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


# Saves the ProjectSettings to a override.cfg file in the base game directory.
func handle_override_cfg() -> void:
	modloaderutils.log_debug("using the override.cfg file", LOG_NAME)
	var _save_custom_error: int = ProjectSettings.save_custom(modloaderutils.get_override_path())


# Creates the project.binary file, adds it to the pck and removes the no longer needed project.binary file.
func handle_project_binary() -> void:
	modloaderutils.log_debug("injecting the project.binary file", LOG_NAME)
	create_project_binary()
	inject_project_binary()
	clean_up_project_binary_file()


# Saves the project settings to a project.binary file inside the addons/mod_loader/ directory.
func create_project_binary() -> void:
	var _error_save_custom_project_binary = ProjectSettings.save_custom(path.game_base_dir + "addons/mod_loader/project.binary")


# Add modified binary to the pck
func inject_project_binary() -> void:
	var output_add_project_binary := []
	var _exit_code_add_project_binary := OS.execute(path.pck_tool, ["--pack", path.pck, "--action", "add", "--file", path.project_binary, "--remove-prefix", path.mod_loader_dir], true, output_add_project_binary)
	modloaderutils.log_debug_json_print("Adding custom project.binary to res://", output_add_project_binary, LOG_NAME)


# Removes the project.binary file
func clean_up_project_binary_file() -> void:
	var dir = Directory.new()
	dir.remove(path.project_binary)


# Initialize the path and file_name dictionary
func setup_file_data() -> void:
	# C:/path/to/game/game.exe
	path.exe = OS.get_executable_path()
	# C:/path/to/game/
	path.game_base_dir = modloaderutils.get_local_folder_dir()
	# C:/path/to/game/addons/mod_loader
	path.mod_loader_dir = path.game_base_dir + "addons/mod_loader/"
	# C:/path/to/game/addons/mod_loader/vendor/godotpcktool/godotpcktool.exe
	path.pck_tool = path.mod_loader_dir + "vendor/godotpcktool/godotpcktool.exe"
	# can be supplied to override the exe_name
	file_name.cli_arg_exe = modloaderutils.get_cmd_line_arg_value("--exe-name")
	# can be supplied to override the pck_name
	file_name.cli_arg_pck = modloaderutils.get_cmd_line_arg_value("--pck-name")
	# game - or use the value of cli_arg_exe_name if there is one
	file_name.exe = modloaderutils.get_file_name_from_path(path.exe, true, true) if file_name.cli_arg_exe == '' else file_name.cli_arg_exe
	# game - or use the value of cli_arg_pck_name if there is one
	# using exe_path.get_file() instead of exe_name
	# so you don't override the pck_name with the --exe-name cli arg
	# the main pack name is the same as the .exe name
	# if --main-pack cli arg is not set
	file_name.pck = modloaderutils.get_file_name_from_path(path.exe, true, true)  if file_name.cli_arg_pck == '' else file_name.cli_arg_pck
	# C:/path/to/game/game.pck
	path.pck = path.game_base_dir.plus_file(file_name.pck + '.pck')
	# C:/path/to/game/addons/mod_loader/project.binary
	path.project_binary = path.mod_loader_dir + "project.binary"

	modloaderutils.log_debug_json_print("path: ", path, LOG_NAME)
	modloaderutils.log_debug_json_print("file_name: ", file_name, LOG_NAME)
