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
		"base": "Object",
		"class": "ModLoaderConfig",
		"language": "GDScript",
		"path": "res://addons/mod_loader/api/config.gd"
	}, {
		"base": "Node",
		"class": "ModLoaderDeprecated",
		"language": "GDScript",
		"path": "res://addons/mod_loader/api/deprecated.gd"
	}, {
		"base": "Object",
		"class": "ModLoaderGodot",
		"language": "GDScript",
		"path": "res://addons/mod_loader/api/godot.gd"
	}, {
		"base": "Node",
		"class": "ModLoaderSteam",
		"language": "GDScript",
		"path": "res://addons/mod_loader/api/third_party/steam.gd"
	}, {
		"base": "Object",
		"class": "ModLoaderLog",
		"language": "GDScript",
		"path": "res://addons/mod_loader/api/log.gd"
	}
]

# IMPORTANT: use the ModLoaderLog via this variable within this script!
# Otherwise, script compilation will break on first load since the class is not defined.
var ModLoaderLog: Object = load("res://addons/mod_loader/api/log.gd")

var path := {}
var file_name := {}
var is_only_setup: bool = ModLoaderSetupUtils.is_running_with_command_line_arg("--only-setup")
var is_setup_create_override_cfg : bool = ModLoaderSetupUtils.is_running_with_command_line_arg("--setup-create-override-cfg")


func _init() -> void:
	ModLoaderLog.debug("ModLoader setup initialized", LOG_NAME)

	var mod_loader_index: int = ModLoaderSetupUtils.get_autoload_index("ModLoader")
	var mod_loader_store_index: int = ModLoaderSetupUtils.get_autoload_index("ModLoaderStore")

	# Avoid doubling the setup work
	# Checks if the ModLoaderStore is the first autoload and ModLoader the second
	if mod_loader_store_index == 0 and mod_loader_index == 1:
		modded_start()
		return

	# Check if --setup-create-override-cfg is passed,
	# in that case the ModLoader and ModLoaderStore just have to be somewhere in the autoloads.
	if is_setup_create_override_cfg and mod_loader_index != -1 and mod_loader_store_index != -1:
		modded_start()
		return

	setup_modloader()


# ModLoader already setup - switch to the main scene
func modded_start() -> void:
	ModLoaderLog.info("ModLoader is available, mods can be loaded!", LOG_NAME)

	OS.set_window_title("%s (Modded)" % ProjectSettings.get_setting("application/config/name"))

	var _error_change_scene_main := change_scene(ProjectSettings.get_setting("application/run/main_scene"))


# Set up the ModLoader as an autoload and register the other global classes.
func setup_modloader() -> void:
	ModLoaderLog.info("Setting up ModLoader", LOG_NAME)

	# Setup path and file_name dict with all required paths and file names.
	setup_file_data()

	# Register all new helper classes as global
	ModLoaderSetupUtils.register_global_classes_from_array(new_global_classes)

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
	ModLoaderLog.info("ModLoader is set up, a game restart is required.", LOG_NAME)

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

	# Add ModLoaderStore autoload (the * marks the path as autoload)
	ProjectSettings.set_setting("autoload/ModLoaderStore", "*" + "res://addons/mod_loader/mod_loader_store.gd")

	# Add ModLoader autoload (the * marks the path as autoload)
	ProjectSettings.set_setting("autoload/ModLoader", "*" + "res://addons/mod_loader/mod_loader.gd")

	# add all previous autoloads back again
	for autoload in original_autoloads.keys():
			ProjectSettings.set_setting(autoload, original_autoloads[autoload])


# Saves the ProjectSettings to a override.cfg file in the base game directory.
func handle_override_cfg() -> void:
	ModLoaderLog.debug("using the override.cfg file", LOG_NAME)
	var _save_custom_error: int = ProjectSettings.save_custom(ModLoaderSetupUtils.get_override_path())


# Creates the project.binary file, adds it to the pck and removes the no longer needed project.binary file.
func handle_project_binary() -> void:
	ModLoaderLog.debug("injecting the project.binary file", LOG_NAME)
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
	ModLoaderLog.debug_json_print("Adding custom project.binary to res://", output_add_project_binary, LOG_NAME)


# Removes the project.binary file
func clean_up_project_binary_file() -> void:
	var dir = Directory.new()
	dir.remove(path.project_binary)


# Initialize the path and file_name dictionary
func setup_file_data() -> void:
	# C:/path/to/game/game.exe
	path.exe = OS.get_executable_path()
	# C:/path/to/game/
	path.game_base_dir = ModLoaderSetupUtils.get_local_folder_dir()
	# C:/path/to/game/addons/mod_loader
	path.mod_loader_dir = path.game_base_dir + "addons/mod_loader/"
	# C:/path/to/game/addons/mod_loader/vendor/godotpcktool/godotpcktool.exe
	path.pck_tool = path.mod_loader_dir + "vendor/godotpcktool/godotpcktool.exe"
	# can be supplied to override the exe_name
	file_name.cli_arg_exe = ModLoaderSetupUtils.get_cmd_line_arg_value("--exe-name")
	# can be supplied to override the pck_name
	file_name.cli_arg_pck = ModLoaderSetupUtils.get_cmd_line_arg_value("--pck-name")
	# game - or use the value of cli_arg_exe_name if there is one
	file_name.exe = ModLoaderSetupUtils.get_file_name_from_path(path.exe, true, true) if file_name.cli_arg_exe == '' else file_name.cli_arg_exe
	# game - or use the value of cli_arg_pck_name if there is one
	# using exe_path.get_file() instead of exe_name
	# so you don't override the pck_name with the --exe-name cli arg
	# the main pack name is the same as the .exe name
	# if --main-pack cli arg is not set
	file_name.pck = ModLoaderSetupUtils.get_file_name_from_path(path.exe, true, true)  if file_name.cli_arg_pck == '' else file_name.cli_arg_pck
	# C:/path/to/game/game.pck
	path.pck = path.game_base_dir.plus_file(file_name.pck + '.pck')
	# C:/path/to/game/addons/mod_loader/project.binary
	path.project_binary = path.mod_loader_dir + "project.binary"

	ModLoaderLog.debug_json_print("path: ", path, LOG_NAME)
	ModLoaderLog.debug_json_print("file_name: ", file_name, LOG_NAME)


class ModLoaderSetupUtils:
	# Get the path to a local folder. Primarily used to get the  (packed) mods
	# folder, ie "res://mods" or the OS's equivalent, as well as the configs path
	static func get_local_folder_dir(subfolder: String = "") -> String:
		var game_install_directory := OS.get_executable_path().get_base_dir()

		if OS.get_name() == "OSX":
			game_install_directory = game_install_directory.get_base_dir().get_base_dir()

		# Fix for running the game through the Godot editor (as the EXE path would be
		# the editor's own EXE, which won't have any mod ZIPs)
		# if OS.is_debug_build():
		if OS.has_feature("editor"):
			game_install_directory = "res://"

		return game_install_directory.plus_file(subfolder)


	# Provide a path, get the file name at the end of the path
	static func get_file_name_from_path(path: String, make_lower_case := true, remove_extension := false) -> String:
		var file_name := path.get_file()

		if make_lower_case:
			file_name = file_name.to_lower()

		if remove_extension:
			file_name = file_name.trim_suffix("." + file_name.get_extension())

		return file_name


	# Get an array of all autoloads -> ["autoload/AutoloadName", ...]
	static func get_autoload_array() -> Array:
		var autoloads := []

		# Get all autoload settings
		for prop in ProjectSettings.get_property_list():
			var name: String = prop.name
			if name.begins_with("autoload/"):
				autoloads.append(name.trim_prefix("autoload/"))

		return autoloads


	# Get the index of a specific autoload
	static func get_autoload_index(autoload_name: String) -> int:
		var autoloads := get_autoload_array()
		var autoload_index := autoloads.find(autoload_name)

		return autoload_index


	# Get the path where override.cfg will be stored.
	# Not the same as the local folder dir (for mac)
	static func get_override_path() -> String:
		var base_path := ""
		if OS.has_feature("editor"):
			base_path = ProjectSettings.globalize_path("res://")
		else:
			# this is technically different to res:// in macos, but we want the
			# executable dir anyway, so it is exactly what we need
			base_path = OS.get_executable_path().get_base_dir()

		return base_path.plus_file("override.cfg")


	# Register an array of classes to the global scope, since Godot only does that in the editor.
	static func register_global_classes_from_array(new_global_classes: Array) -> void:
		var ModLoaderLog: Object = load("res://addons/mod_loader/api/log.gd")
		var registered_classes: Array = ProjectSettings.get_setting("_global_script_classes")
		var registered_class_icons: Dictionary = ProjectSettings.get_setting("_global_script_class_icons")

		for new_class in new_global_classes:
			if not is_valid_global_class_dict(new_class):
				continue
			for old_class in registered_classes:
				if old_class.class == new_class.class:
					if OS.has_feature("editor"):
						ModLoaderLog.info('Class "%s" to be registered as global was already registered by the editor. Skipping.' % new_class.class, LOG_NAME)
					else:
						ModLoaderLog.info('Class "%s" to be registered as global already exists. Skipping.' % new_class.class, LOG_NAME)
					continue

			registered_classes.append(new_class)
			registered_class_icons[new_class.class] = "" # empty icon, does not matter

		ProjectSettings.set_setting("_global_script_classes", registered_classes)
		ProjectSettings.set_setting("_global_script_class_icons", registered_class_icons)


	# Checks if all required fields are in the given [Dictionary]
	# Format: { "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }
	static func is_valid_global_class_dict(global_class_dict: Dictionary) -> bool:
		var ModLoaderLog: Object = load("res://addons/mod_loader/api/log.gd")
		var required_fields := ["base", "class", "language", "path"]
		if not global_class_dict.has_all(required_fields):
			ModLoaderLog.fatal("Global class to be registered is missing one of %s" % required_fields, LOG_NAME)
			return false

		var file = File.new()
		if not file.file_exists(global_class_dict.path):
			ModLoaderLog.fatal('Class "%s" to be registered as global could not be found at given path "%s"' %
			[global_class_dict.class, global_class_dict.path], LOG_NAME)
			return false

		return true


	# Check if the provided command line argument was present when launching the game
	static func is_running_with_command_line_arg(argument: String) -> bool:
		for arg in OS.get_cmdline_args():
			if argument == arg.split("=")[0]:
				return true

		return false


	# Get the command line argument value if present when launching the game
	static func get_cmd_line_arg_value(argument: String) -> String:
		var args := get_fixed_cmdline_args()

		for arg_index in args.size():
			var arg := args[arg_index] as String

			var key := arg.split("=")[0]
			if key == argument:
				# format: `--arg=value` or `--arg="value"`
				if "=" in arg:
					var value := arg.trim_prefix(argument + "=")
					value = value.trim_prefix('"').trim_suffix('"')
					value = value.trim_prefix("'").trim_suffix("'")
					return value

				# format: `--arg value` or `--arg "value"`
				elif arg_index +1 < args.size() and not args[arg_index +1].begins_with("--"):
					return args[arg_index + 1]

		return ""


	static func get_fixed_cmdline_args() -> PoolStringArray:
		return fix_godot_cmdline_args_string_space_splitting(OS.get_cmdline_args())


	# Reverses a bug in Godot, which splits input strings at spaces even if they are quoted
	# e.g. `--arg="some value" --arg-two 'more value'` becomes `[ --arg="some, value", --arg-two, 'more, value' ]`
	static func fix_godot_cmdline_args_string_space_splitting(args: PoolStringArray) -> PoolStringArray:
		if not OS.has_feature("editor"): # only happens in editor builds
			return args
		if OS.has_feature("Windows"): # windows is unaffected
			return args

		var fixed_args := PoolStringArray([])
		var fixed_arg := ""
		# if we encounter an argument that contains `=` followed by a quote,
		# or an argument that starts with a quote, take all following args and
		# concatenate them into one, until we find the closing quote
		for arg in args:
			var arg_string := arg as String
			if '="' in arg_string or '="' in fixed_arg or \
					arg_string.begins_with('"') or fixed_arg.begins_with('"'):
				if not fixed_arg == "":
					fixed_arg += " "
				fixed_arg += arg_string
				if arg_string.ends_with('"'):
					fixed_args.append(fixed_arg.trim_prefix(" "))
					fixed_arg = ""
					continue
			# same thing for single quotes
			elif "='" in arg_string or "='" in fixed_arg \
					or arg_string.begins_with("'") or fixed_arg.begins_with("'"):
				if not fixed_arg == "":
					fixed_arg += " "
				fixed_arg += arg_string
				if arg_string.ends_with("'"):
					fixed_args.append(fixed_arg.trim_prefix(" "))
					fixed_arg = ""
					continue

			else:
				fixed_args.append(arg_string)

		return fixed_args
