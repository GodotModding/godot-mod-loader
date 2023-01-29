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

var info_label := Label.new()
var restart_timer := Timer.new()

var path := {}
var file_name := {}

func _init() -> void:
	modloaderutils.log_debug("ModLoader setup initialized", LOG_NAME)
	try_setup_modloader()
	var _error_change_scene_main = change_scene(ProjectSettings.get_setting("application/run/main_scene"))

func _iteration(_delta):
	# If the restart timer is started update the label to show that the game will be restarted
	if !restart_timer.is_stopped():
		info_label.text = "Mod Loader is installing - restarting in %s" % int(restart_timer.time_left)


# Set up the ModLoader, if it hasn't been set up yet
func try_setup_modloader() -> void:
	# Avoid doubling the setup work
	if is_loader_setup_applied():
		modloaderutils.log_info("ModLoader is available, mods can be loaded!", LOG_NAME)
		OS.set_window_title("%s (Modded)" % ProjectSettings.get_setting("application/config/name"))
		return

	# Add info label and restart timer to the scene tree
	setup_ui()

	setup_file_data()

	create_project_binary()

	inject_project_binary()

	# TODO: Remove unnecessary files after installation?

	setup_modloader()

	# If the loader is set up, notify the user that the game will restart
	if is_loader_set_up() and not is_loader_setup_applied():
		modloaderutils.log_info("ModLoader is set up, the game will be restarted", LOG_NAME)
		restart_timer.start(4)

		ProjectSettings.set_setting(settings.IS_LOADER_SETUP_APPLIED, true)
		var _error_save_custom_override = ProjectSettings.save_custom(modloaderutils.get_override_path())


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


# Reorders the autoloads in the project settings, to get the ModLoader on top.
# Then saves the project settings to a project.binary file inside the addons/mod_loader/ directory.
func create_project_binary() -> void:
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
	var _error_save_custom_project_binary = ProjectSettings.save_custom(path.game_base_dir + "addons/mod_loader/project.binary")


# Add modified binary to the pck
func inject_project_binary() -> void:
	var output_add_project_binary := []
	var _exit_code_add_project_binary := OS.execute(path.pck_tool, ["--pack", path.pck, "--action", "add", "--file", path.project_binary, "--remove-prefix", path.mod_loader_dir], true, output_add_project_binary)
	modloaderutils.log_debug_json_print("Adding custom project.binaray to res://", output_add_project_binary, LOG_NAME)


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


func setup_ui() -> void:
	# setup UI for installation visualization
	info_label.anchor_left = 0.5
	info_label.anchor_top = 0.5
	info_label.anchor_right = 0.5
	info_label.anchor_bottom = 0.5
	info_label.margin_left = -305.0
	info_label.margin_top = -13.0
	info_label.margin_right = 28.0
	info_label.margin_bottom = 1.0
	info_label.grow_horizontal = Label.GROW_DIRECTION_BOTH
	info_label.rect_scale = Vector2( 2, 2 )
	info_label.align = Label.ALIGN_CENTER
	info_label.valign = Label.ALIGN_CENTER
	info_label.text = "Mod Loader is installing - please wait.."
	root.add_child(info_label)

	restart_timer.one_shot = true
	root.add_child(restart_timer)
	var _error_connect_restart_timer_timeout = restart_timer.connect("timeout", self, "_on_restart_timer_timeout")


static func is_project_setting_true(project_setting: String) -> bool:
	return ProjectSettings.has_setting(project_setting) and\
		ProjectSettings.get_setting(project_setting)

# restart the game
func _on_restart_timer_timeout() -> void:
	# run the game again to apply the changed project settings
		var _exit_code_game_start = OS.execute(OS.get_executable_path(), ["--script", path.mod_loader_dir + "mod_loader_setup.gd", "--log-debug"], false)

		# quit the current execution
		quit()
