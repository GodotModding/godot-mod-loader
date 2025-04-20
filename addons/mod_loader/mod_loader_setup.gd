extends SceneTree

const LOG_NAME := "ModLoader:Setup"

const settings := {
	"IS_LOADER_SETUP_APPLIED": "application/run/is_loader_setup_applied",
	"IS_LOADER_SET_UP": "application/run/is_loader_set_up",
	"MOD_LOADER_AUTOLOAD": "autoload/ModLoader",
}

# IMPORTANT: use the ModLoaderLog via this variable within this script!
# Otherwise, script compilation will break on first load since the class is not defined.
var ModLoaderSetupLog: Object = load("res://addons/mod_loader/setup/setup_log.gd")
var ModLoaderSetupUtils: Object = load("res://addons/mod_loader/setup/setup_utils.gd")

var path := {}
var file_name := {}
var is_only_setup: bool = ModLoaderSetupUtils.is_running_with_command_line_arg("--only-setup")
var is_setup_create_override_cfg: bool = ModLoaderSetupUtils.is_running_with_command_line_arg(
	"--setup-create-override-cfg"
)
var pck_explorer_not_found: bool = false


func _init() -> void:
	ModLoaderSetupLog.debug("ModLoader setup initialized", LOG_NAME)

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
	ModLoaderSetupLog.info("ModLoader is available, mods can be loaded!", LOG_NAME)

	root.set_title("%s (Modded)" % ProjectSettings.get_setting("application/config/name"))

	change_scene_to_file.call_deferred(ProjectSettings.get_setting("application/run/main_scene"))


# Set up the ModLoader as an autoload and register the other global classes.
func setup_modloader() -> void:
	ModLoaderSetupLog.info("Setting up ModLoader", LOG_NAME)

	# Setup path and file_name dict with all required paths and file names.
	setup_file_data()

	# Add ModLoader autoload (the * marks the path as autoload)
	reorder_autoloads()
	ProjectSettings.set_setting(settings.IS_LOADER_SET_UP, true)

	# The game needs to be restarted first, before the loader is truly set up
	# Set this here and check it elsewhere to prompt the user for a restart
	ProjectSettings.set_setting(settings.IS_LOADER_SETUP_APPLIED, false)

	if is_setup_create_override_cfg:
		handle_override_cfg()
	else:
		handle_injection()

	# ModLoader is set up. A game restart is required to apply the ProjectSettings.
	ModLoaderSetupLog.info("ModLoader is set up, a game restart is required.", LOG_NAME)

	match true:
		# If the --only-setup cli argument is passed, quit with exit code 0
		is_only_setup:
			quit(0)
		# If GodotPCKExplorer executable doesn't exist, quit with exit code 1
		pck_explorer_not_found:
			quit(1)
		# If no cli argument is passed, show message with OS.alert() and user has to restart the game
		_:
			OS.alert(
				"The Godot ModLoader has been set up. The game needs to be restarted to apply the changes. Confirm to restart."
			)
			restart()


# Reorders the autoloads in the project settings, to get the ModLoader on top.
func reorder_autoloads() -> void:
	# remove and re-add autoloads
	var original_autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.name
		if name.begins_with("autoload/"):
			var value: String = ProjectSettings.get_setting(name)
			original_autoloads[name] = value

	ModLoaderSetupLog.info(
		"Start reorder autoloads current state: %s" % JSON.stringify(original_autoloads, "\t")
	)

	for autoload in original_autoloads.keys():
		ProjectSettings.set_setting(autoload, null)

	# Add ModLoaderStore autoload (the * marks the path as autoload)
	ProjectSettings.set_setting(
		"autoload/ModLoaderStore", "*" + "res://addons/mod_loader/mod_loader_store.gd"
	)

	# Add ModLoader autoload (the * marks the path as autoload)
	ProjectSettings.set_setting("autoload/ModLoader", "*" + "res://addons/mod_loader/mod_loader.gd")

	# add all previous autoloads back again
	for autoload in original_autoloads.keys():
		ProjectSettings.set_setting(autoload, original_autoloads[autoload])

	var new_autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.name
		if name.begins_with("autoload/"):
			var value: String = ProjectSettings.get_setting(name)
			new_autoloads[name] = value

	ModLoaderSetupLog.info(
		"Reorder autoloads completed - new state: %s" % JSON.stringify(new_autoloads, "\t")
	)


# Saves the ProjectSettings to a override.cfg file in the base game directory.
func handle_override_cfg() -> void:
	ModLoaderSetupLog.debug("using the override.cfg file", LOG_NAME)

	# Make the '.godot' dir public as 'godot' and copy all files to the public dir.
	make_project_data_public()

	# Combine mod_loader and game global classes
	var global_script_class_cache_combined := get_combined_global_script_class_cache()
	global_script_class_cache_combined.save("res://godot/global_script_class_cache.cfg")

	var _save_custom_error: int = ProjectSettings.save_custom(
		ModLoaderSetupUtils.get_override_path()
	)


# Creates the project.binary file, adds it to the pck and removes the no longer needed project.binary file.
func handle_injection() -> void:
	# If GodotPCKExplorer executable doesn't exist, we can't continue
	if not FileAccess.file_exists(path.pck_explorer):
		ModLoaderSetupLog.error("GodotPCKExplorer executable isn't present, cannot continue with injection", LOG_NAME)
		OS.alert(
				"The GodotPCKExplorer executable isn't present under addons/mod_loader/vendor/GodotPCKExplorer, cannot inject ModLoader into pck file"
		)
		pck_explorer_not_found = true
		return

	ModLoaderSetupLog.debug("Start injection", LOG_NAME)
	# Create temp dir
	ModLoaderSetupLog.debug('Creating temp dir at "%s"' % path.temp_dir_path, LOG_NAME)
	DirAccess.make_dir_recursive_absolute(path.temp_dir_path)

	# Create project.binary
	ModLoaderSetupLog.debug(
		'Storing project.binary at "%s"' % path.temp_project_binary_path, LOG_NAME
	)
	var _error_save_custom_project_binary = ProjectSettings.save_custom(
		path.temp_project_binary_path
	)
	# Create combined global class cache cfg
	var combined_global_script_class_cache_file := get_combined_global_script_class_cache()
	ModLoaderSetupLog.debug(
		'Storing global_script_class_cache at "%s"' % path.temp_global_script_class_cache_path,
		LOG_NAME
	)
	# Create the .godot dir inside the temp dir
	DirAccess.make_dir_recursive_absolute(path.temp_dir_path.path_join(".godot"))
	# Save the global class cache config file
	combined_global_script_class_cache_file.save(path.temp_global_script_class_cache_path)
	get_pck_version()
	# Check if .pck is embedded split it from the .exe
	if not FileAccess.file_exists(path.pck):
		split_pck()

	inject()

	# Rename vanilla
	DirAccess.rename_absolute(
		path.pck,
		path.pck.trim_suffix("%s.pck" % file_name.pck).path_join("%s-vanilla.pck" % file_name.pck)
	)
	ModLoaderSetupLog.debug(
		(
			'Renamed "%s" to "%s"'
			% [
				path.pck,
				path.pck.trim_suffix("%s.pck" % file_name.pck).path_join(
					"%s-vanilla.pck" % file_name.pck
				)
			]
		),
		LOG_NAME
	)
	# Rename modded
	DirAccess.rename_absolute(
		path.game_base_dir.path_join("%s-modded.pck" % file_name.pck),
		"%s.pck" % path.game_base_dir.path_join(file_name.pck)
	)
	ModLoaderSetupLog.debug(
		(
			'Renamed "%s" to "%s"'
			% [
				path.game_base_dir.path_join("%s-modded.pck" % file_name.pck),
				"%s.pck" % path.game_base_dir.path_join(file_name.pck)
			]
		),
		LOG_NAME
	)

	clean_up()


func get_pck_version() -> String:
	var engine_version_info := Engine.get_version_info()
	# Godot 4 pck version always starts with a 2 (at least for now).
	var pck_version := (
		"2.%s.%s.%s"
		% [engine_version_info.major, engine_version_info.minor, engine_version_info.patch]
	)
	ModLoaderSetupLog.debug("The pck version is: %s" % pck_version, LOG_NAME)
	return pck_version


# Add modified binary to the pck
func inject(pck_version: String = get_pck_version()) -> void:
	var arguments := [
		"-pc",
		path.pck,
		path.temp_dir_path,
		path.game_base_dir.path_join("%s-modded.pck" % file_name.pck),
		pck_version
	]
	ModLoaderSetupLog.debug(
		"Injecting temp dir content into .pck: %s %s", [path.pck_explorer, arguments], LOG_NAME
	)
	# For unknown reasons the output only displays a single "[" - so only the executed arguments are logged.
	var _exit_code_inject := OS.execute(path.pck_explorer, arguments)


func split_pck() -> void:
	var arguments := ["-s", path.exe]
	ModLoaderSetupLog.debug(
		"Splitting .pck from .exe: %s %s", [path.pck_explorer, arguments], LOG_NAME
	)
	# For unknown reasons the output only displays a single "[" - so only the executed arguments are logged.
	var _exit_code_split_pck := OS.execute(path.pck_explorer, arguments)


# Removes the temp files
func clean_up() -> void:
	ModLoaderSetupLog.debug("Start clean up", LOG_NAME)
	DirAccess.remove_absolute(path.temp_project_binary_path)
	ModLoaderSetupLog.debug('Removed: "%s"' % path.temp_project_binary_path, LOG_NAME)
	DirAccess.remove_absolute(path.temp_global_script_class_cache_path)
	ModLoaderSetupLog.debug('Removed: "%s"' % path.temp_global_script_class_cache_path, LOG_NAME)
	DirAccess.remove_absolute(path.temp_dir_path.path_join(".godot"))
	ModLoaderSetupLog.debug('Removed: "%s"' % path.temp_dir_path.path_join(".godot"), LOG_NAME)
	DirAccess.remove_absolute(path.temp_dir_path)
	ModLoaderSetupLog.debug('Removed: "%s"' % path.temp_dir_path, LOG_NAME)
	ModLoaderSetupLog.debug("Clean up completed", LOG_NAME)


# Initialize the path and file_name dictionary
func setup_file_data() -> void:
	# C:/path/to/game/game.exe
	path.exe = OS.get_executable_path()
	# C:/path/to/game/
	path.game_base_dir = ModLoaderSetupUtils.get_local_folder_dir()
	# C:/path/to/game/addons/mod_loader
	path.mod_loader_dir = path.game_base_dir + "addons/mod_loader/"
	path.pck_explorer = (
		path.mod_loader_dir
		+ get_pck_explorer_path()
	)
	# ! pck explorer doesn't like trailing `/` in a path !
	path.temp_dir_path = path.mod_loader_dir + "setup/temp"
	path.temp_project_binary_path = path.temp_dir_path + "/project.binary"
	path.temp_global_script_class_cache_path = (
		path.temp_dir_path
		+ "/.godot/global_script_class_cache.cfg"
	)

	# can be supplied to override the exe_name
	file_name.cli_arg_exe = ModLoaderSetupUtils.get_cmd_line_arg_value("--exe-name")
	# can be supplied to override the pck_name
	file_name.cli_arg_pck = ModLoaderSetupUtils.get_cmd_line_arg_value("--pck-name")
	# game - or use the value of cli_arg_exe_name if there is one
	file_name.exe = (
		ModLoaderSetupUtils.get_file_name_from_path(path.exe, false, true)
		if file_name.cli_arg_exe == ""
		else file_name.cli_arg_exe
	)
	# game - or use the value of cli_arg_pck_name if there is one
	# using exe_path.get_file() instead of exe_name
	# so you don't override the pck_name with the --exe-name cli arg
	# the main pack name is the same as the .exe name
	# if --main-pack cli arg is not set
	file_name.pck = (
		ModLoaderSetupUtils.get_file_name_from_path(path.exe, false, true)
		if file_name.cli_arg_pck == ""
		else file_name.cli_arg_pck
	)
	# C:/path/to/game/game.pck
	path.pck = path.game_base_dir.path_join(file_name.pck + ".pck")

	ModLoaderSetupLog.debug_json_print("path: ", path, LOG_NAME)
	ModLoaderSetupLog.debug_json_print("file_name: ", file_name, LOG_NAME)


func make_project_data_public() -> void:
	ModLoaderSetupLog.info("Register Global Classes", LOG_NAME)
	ProjectSettings.set_setting("application/config/use_hidden_project_data_directory", false)

	var godot_files = ModLoaderSetupUtils.get_flat_view_dict("res://.godot")

	ModLoaderSetupLog.info('Copying all files from "res://.godot" to "res://godot".', LOG_NAME)

	for file in godot_files:
		ModLoaderSetupUtils.copy_file(
			file, file.trim_prefix("res://.godot").insert(0, "res://godot")
		)


func get_combined_global_script_class_cache() -> ConfigFile:
	ModLoaderSetupLog.info("Load mod loader class cache", LOG_NAME)
	var global_script_class_cache_mod_loader := ConfigFile.new()
	global_script_class_cache_mod_loader.load(
		"res://addons/mod_loader/setup/global_script_class_cache_mod_loader.cfg"
	)

	ModLoaderSetupLog.info("Load game class cache", LOG_NAME)
	var global_script_class_cache_game := ConfigFile.new()
	global_script_class_cache_game.load("res://.godot/global_script_class_cache.cfg")

	ModLoaderSetupLog.info("Create new class cache", LOG_NAME)
	var global_classes_mod_loader := global_script_class_cache_mod_loader.get_value("", "list")
	var global_classes_game := global_script_class_cache_game.get_value("", "list")

	ModLoaderSetupLog.info("Combine class cache", LOG_NAME)
	var global_classes_combined := []
	global_classes_combined.append_array(global_classes_mod_loader)
	global_classes_combined.append_array(global_classes_game)

	ModLoaderSetupLog.info("Save combined class cache", LOG_NAME)
	var global_script_class_cache_combined := ConfigFile.new()
	global_script_class_cache_combined.set_value("", "list", global_classes_combined)

	return global_script_class_cache_combined


func get_pck_explorer_path() -> String:
	var pck_explorer_path := "vendor/GodotPCKExplorer/GodotPCKExplorer.Console"

	if OS.get_name() == "Windows":
		return "%s.exe" % pck_explorer_path

	return pck_explorer_path


func restart() -> void:
	OS.set_restart_on_exit(true)
	quit()
