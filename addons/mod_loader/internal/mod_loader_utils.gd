class_name ModLoaderUtils
extends Node


const LOG_NAME := "ModLoader:ModLoaderUtils"


# This is a dummy func. It is exclusively used to show notes in the code that
# stay visible after decompiling a PCK, as is primarily intended to assist new
# modders in understanding and troubleshooting issues
static func _code_note(_msg:String):
	pass


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


# Returns an empty Dictionary if the key does not exist or is not type of Dictionary
static func get_dict_from_dict(dict: Dictionary, key: String) -> Dictionary:
	if not dict.has(key):
		return {}

	if not dict[key] is Dictionary:
		return {}

	return dict[key]


# Works like [method Dictionary.has_all],
# but allows for more specific errors if a field is missing
static func dict_has_fields(dict: Dictionary, required_fields: Array) -> bool:
	var missing_fields := required_fields

	for key in dict.keys():
		if(required_fields.has(key)):
			missing_fields.erase(key)

	if missing_fields.size() > 0:
		ModLoaderLog.fatal("Dictionary is missing required fields: %s" % missing_fields, LOG_NAME)
		return false

	return true


# Register an array of classes to the global scope, since Godot only does that in the editor.
static func register_global_classes_from_array(new_global_classes: Array) -> void:
	var registered_classes: Array = ProjectSettings.get_setting("_global_script_classes")
	var registered_class_icons: Dictionary = ProjectSettings.get_setting("_global_script_class_icons")

	for new_class in new_global_classes:
		if not _is_valid_global_class_dict(new_class):
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
static func _is_valid_global_class_dict(global_class_dict: Dictionary) -> bool:
	var required_fields := ["base", "class", "language", "path"]
	if not global_class_dict.has_all(required_fields):
		ModLoaderLog.fatal("Global class to be registered is missing one of %s" % required_fields, LOG_NAME)
		return false

	if not _ModLoaderFile.file_exists(global_class_dict.path):
		ModLoaderLog.fatal('Class "%s" to be registered as global could not be found at given path "%s"' %
		[global_class_dict.class, global_class_dict.path], LOG_NAME)
		return false

	return true


# Returns the string in between two strings in a provided string
static func get_string_in_between(string: String, initial: String, ending: String) -> String:
	var start_index: int = string.find(initial)
	if start_index == -1:
		ModLoaderLog.error("Initial string not found.", LOG_NAME)
		return ""

	start_index += initial.length()

	var end_index: int = string.find(ending, start_index)
	if end_index == -1:
		ModLoaderLog.error("Ending string not found.", LOG_NAME)
		return ""

	var found_string: String = string.substr(start_index, end_index - start_index)

	return found_string


# Deprecated
# =============================================================================

# Logs the error in red and a stack trace. Prefixed FATAL-ERROR
# Stops the execution in editor
# Always logged
static func log_fatal(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoaderUtils.log_fatal", "ModLoaderLog.fatal", "6.0.0")
	ModLoaderLog.fatal(message, mod_name)


# Logs the message and pushed an error. Prefixed ERROR
# Always logged
static func log_error(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoaderUtils.log_error", "ModLoaderLog.error", "6.0.0")
	ModLoaderLog.error(message, mod_name)


# Logs the message and pushes a warning. Prefixed WARNING
# Logged with verbosity level at or above warning (-v)
static func log_warning(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoaderUtils.log_warning", "ModLoaderLog.warning", "6.0.0")
	ModLoaderLog.warning(message, mod_name)


# Logs the message. Prefixed INFO
# Logged with verbosity level at or above info (-vv)
static func log_info(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoaderUtils.log_info", "ModLoaderLog.info", "6.0.0")
	ModLoaderLog.info(message, mod_name)


# Logs the message. Prefixed SUCCESS
# Logged with verbosity level at or above info (-vv)
static func log_success(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoaderUtils.log_success", "ModLoaderLog.success", "6.0.0")
	ModLoaderLog.success(message, mod_name)


# Logs the message. Prefixed DEBUG
# Logged with verbosity level at or above debug (-vvv)
static func log_debug(message: String, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoaderUtils.log_debug", "ModLoaderLog.debug", "6.0.0")
	ModLoaderLog.debug(message, mod_name)


# Logs the message formatted with [method JSON.print]. Prefixed DEBUG
# Logged with verbosity level at or above debug (-vvv)
static func log_debug_json_print(message: String, json_printable, mod_name: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoaderUtils.log_debug_json_print", "ModLoaderLog.debug_json_print", "6.0.0")
	ModLoaderLog.debug_json_print(message, json_printable, mod_name)
