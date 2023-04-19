class_name ModLoaderUtils
extends Node


const LOG_NAME := "ModLoader:ModLoaderUtils"


# This is a dummy func. It is exclusively used to show notes in the code that
# stay visible after decompiling a PCK, as is primarily intended to assist new
# modders in understanding and troubleshooting issues
static func code_note(_msg:String):
	pass


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


# Returns an empty String if the key does not exist or is not type of String
static func get_string_from_dict(dict: Dictionary, key: String) -> String:
	if not dict.has(key):
		return ""

	if not dict[key] is String:
		return ""

	return dict[key]


# Returns an empty Array if the key does not exist or is not type of Array
static func get_array_from_dict(dict: Dictionary, key: String) -> Array:
	if not dict.has(key):
		return []

	if not dict[key] is Array:
		return []

	return dict[key]


# Works like [method Dictionary.has_all],
# but allows for more specific errors if a field is missing
static func dict_has_fields(dict: Dictionary, required_fields: Array) -> bool:
	var missing_fields := required_fields

	for key in dict.keys():
		if(required_fields.has(key)):
			missing_fields.erase(key)

	if missing_fields.size() > 0:
		ModLoaderLog.fatal("Mod manifest is missing required fields: %s" % missing_fields, LOG_NAME)
		return false

	return true


# Register an array of classes to the global scope, since Godot only does that in the editor.
static func register_global_classes_from_array(new_global_classes: Array) -> void:
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
	var required_fields := ["base", "class", "language", "path"]
	if not global_class_dict.has_all(required_fields):
		ModLoaderLog.fatal("Global class to be registered is missing one of %s" % required_fields, LOG_NAME)
		return false

	if not ModLoaderFile.file_exists(global_class_dict.path):
		ModLoaderLog.fatal('Class "%s" to be registered as global could not be found at given path "%s"' %
		[global_class_dict.class, global_class_dict.path], LOG_NAME)
		return false

	return true


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


# Deprecated
# =============================================================================

# Logs the error in red and a stack trace. Prefixed FATAL-ERROR
# Stops the execution in editor
# Always logged
static func log_fatal(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.log_fatal", "ModLoaderLog.fatal", "6.0.0")
	ModLoaderLog.fatal(message, mod_name)


# Logs the message and pushed an error. Prefixed ERROR
# Always logged
static func log_error(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.log_error", "ModLoaderLog.error", "6.0.0")
	ModLoaderLog.error(message, mod_name)


# Logs the message and pushes a warning. Prefixed WARNING
# Logged with verbosity level at or above warning (-v)
static func log_warning(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.log_warning", "ModLoaderLog.warning", "6.0.0")
	ModLoaderLog.warning(message, mod_name)


# Logs the message. Prefixed INFO
# Logged with verbosity level at or above info (-vv)
static func log_info(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.log_info", "ModLoaderLog.info", "6.0.0")
	ModLoaderLog.info(message, mod_name)


# Logs the message. Prefixed SUCCESS
# Logged with verbosity level at or above info (-vv)
static func log_success(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.log_success", "ModLoaderLog.success", "6.0.0")
	ModLoaderLog.success(message, mod_name)


# Logs the message. Prefixed DEBUG
# Logged with verbosity level at or above debug (-vvv)
static func log_debug(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.log_debug", "ModLoaderLog.debug", "6.0.0")
	ModLoaderLog.debug(message, mod_name)


# Logs the message formatted with [method JSON.print]. Prefixed DEBUG
# Logged with verbosity level at or above debug (-vvv)
static func log_debug_json_print(message: String, json_printable, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.log_debug_json_print", "ModLoaderLog.debug_json_print", "6.0.0")
	ModLoaderLog.debug_json_print(message, json_printable, mod_name)
