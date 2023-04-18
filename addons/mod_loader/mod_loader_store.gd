extends Node


# ModLoaderStore
# Singleton (autoload) for storing data. Should be added before ModLoader,
# as an autoload called `ModLoaderStore`


# Constants
# =============================================================================

const LOG_NAME = "ModLoader:Store"

# Vars
# =============================================================================

# Stores data for every found/loaded mod
var mod_data := {}

# Set to false after ModLoader._init()
# Helps to decide whether a script extension should go through the _handle_script_extensions process
var is_initializing := true

# Store all extenders paths
var script_extensions := []

# True if ModLoader has displayed the warning about using zipped mods
var has_shown_editor_zips_warning := false

# Keeps track of logged messages, to avoid flooding the log with duplicate notices
# Can also be used by mods, eg. to create an in-game developer console that
# shows messages
var logged_messages := {
	"all": {},
	"by_mod": {},
	"by_type": {
		"fatal-error": {},
		"error": {},
		"warning": {},
		"info": {},
		"success": {},
		"debug": {},
	}
}

# These variables handle various options, which can be changed either via
# Godot's GUI (with the options.tres resource file), or via CLI args.
# Usage: `ModLoaderStore.ml_options.KEY`
# See: res://addons/mod_loader/options/options.tres
# See: res://addons/mod_loader/classes/options_profile.gd
var ml_options := {
	enable_mods = true,
	log_level = ModLoaderLog.VERBOSITY_LEVEL.DEBUG,

	# Array of disabled mods (contains mod IDs as strings)
	disabled_mods = [],

	# If true, ModLoader will load mod ZIPs from the Steam workshop directory,
	# instead of the default location (res://mods)
	steam_workshop_enabled = false,

	# Overrides for the path mods/configs/workshop folders are loaded from.
	# Only applied if custom settings are provided, either via the options.tres
	# resource, or via CLI args. Note that CLI args can be tested in the editor
	# via: Project Settings > Display> Editor > Main Run Args
	override_path_to_mods = "",    # Default if unspecified: "res://mods"    -- get with ModLoaderUtils.get_path_to_mods()
	override_path_to_configs = "", # Default if unspecified: "res://configs" -- get with ModLoaderUtils.get_path_to_configs()

	# Can be used in the editor to load mods from your Steam workshop directory
	override_path_to_workshop = "",

	# If true, using deprecated funcs will trigger a warning, instead of a fatal
	# error. This can be helpful when developing mods that depend on a mod that
	# hasn't been updated to fix the deprecated issues yet
	ignore_deprecated_errors = false,

	# Array of mods that should be ignored when logging messages (contains mod IDs as strings)
	ignored_mod_names_in_log = [],
}


# Methods
# =============================================================================

func _init():
	_update_ml_options_from_options_resource()
	_update_ml_options_from_cli_args()


# Update ModLoader's options, via the custom options resource
func _update_ml_options_from_options_resource() -> void:
	# Path to the options resource
	# See: res://addons/mod_loader/classes/options_current.gd
	var ml_options_path := "res://addons/mod_loader/options/options.tres"

	# Get user options for ModLoader
	if File.new().file_exists(ml_options_path):
		var options_resource := load(ml_options_path)
		if not options_resource.current_options == null:
			var current_options: Resource = options_resource.current_options
			# Update from the options in the resource
			for key in ml_options:
				ml_options[key] = current_options[key]
	else:
		ModLoaderLog.fatal(str("A critical file is missing: ", ml_options_path), LOG_NAME)


# Update ModLoader's options, via CLI args
func _update_ml_options_from_cli_args() -> void:
	# Disable mods
	if ModLoaderUtils.is_running_with_command_line_arg("--disable-mods"):
		ml_options.enable_mods = false

	# Override paths to mods
	# Set via: --mods-path
	# Example: --mods-path="C://path/mods"
	var cmd_line_mod_path := ModLoaderUtils.get_cmd_line_arg_value("--mods-path")
	if cmd_line_mod_path:
		ml_options.override_path_to_mods = cmd_line_mod_path
		ModLoaderLog.info("The path mods are loaded from has been changed via the CLI arg `--mods-path`, to: " + cmd_line_mod_path, LOG_NAME)

	# Override paths to configs
	# Set via: --configs-path
	# Example: --configs-path="C://path/configs"
	var cmd_line_configs_path := ModLoaderUtils.get_cmd_line_arg_value("--configs-path")
	if cmd_line_configs_path:
		ml_options.override_path_to_configs = cmd_line_configs_path
		ModLoaderLog.info("The path configs are loaded from has been changed via the CLI arg `--configs-path`, to: " + cmd_line_configs_path, LOG_NAME)

	# Log level verbosity
	if ModLoaderUtils.is_running_with_command_line_arg("-vvv") or ModLoaderUtils.is_running_with_command_line_arg("--log-debug"):
		ml_options.log_level = ModLoaderLog.VERBOSITY_LEVEL.DEBUG
	elif ModLoaderUtils.is_running_with_command_line_arg("-vv") or ModLoaderUtils.is_running_with_command_line_arg("--log-info"):
		ml_options.log_level = ModLoaderLog.VERBOSITY_LEVEL.INFO
	elif ModLoaderUtils.is_running_with_command_line_arg("-v") or ModLoaderUtils.is_running_with_command_line_arg("--log-warning"):
		ml_options.log_level = ModLoaderLog.VERBOSITY_LEVEL.WARNING

	# Ignored mod_names in log
	var ignore_mod_names := ModLoaderUtils.get_cmd_line_arg_value("--log-ignore")
	if not ignore_mod_names == "":
		ml_options.ignored_mod_names_in_log = ignore_mod_names.split(",")
