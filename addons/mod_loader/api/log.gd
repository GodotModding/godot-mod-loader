# This Class provides methods for logging, retrieving logged data, and internal methods for working with log files.
class_name ModLoaderLog
extends Node

# Path to the latest log file.
const MOD_LOG_PATH := "user://logs/modloader.log"

const LOG_NAME := "ModLoader:Log"

enum VERBOSITY_LEVEL {
	ERROR,
	WARNING,
	INFO,
	DEBUG,
}

# This Sub-Class represents a log entry in ModLoader.
class ModLoaderLogEntry:
	extends Resource

	# Name of the mod or ModLoader class this entry refers to.
	var mod_name: String

	# The message of the log entry.
	var message: String

	# The log type, which indicates the verbosity level of this entry.
	var type: String

	# The readable format of the time when this log entry was created.
	# Used for printing in the log file and output.
	var time: String

	# The timestamp when this log entry was created.
	# Used for comparing and sorting log entries by time.
	var time_stamp: int

	# An array of ModLoaderLogEntry objects.
	# If the message has been logged before, it is added to the stack.
	var stack := []


	# Initialize a ModLoaderLogEntry object with provided values.
	#
	# Parameters:
	# - _mod_name (String): Name of the mod or ModLoader class this entry refers to.
	# - _message (String): The message of the log entry.
	# - _type (String): The log type, which indicates the verbosity level of this entry.
	# - _time (String): The readable format of the time when this log entry was created.
	#
	# Returns: void
	func _init(_mod_name: String, _message: String, _type: String, _time: String) -> void:
		mod_name = _mod_name
		message = _message
		type = _type
		time = _time
		time_stamp = Time.get_ticks_msec()


	# Get the log entry as a formatted string.
	#
	# Returns: String
	func get_entry() -> String:
		return str(time, get_prefix(), message)


	# Get the prefix string for the log entry, including the log type and mod name.
	#
	# Returns: String
	func get_prefix() -> String:
		return "%s %s: " % [type.to_upper(), mod_name]


	# Generate an MD5 hash of the log entry (prefix + message).
	#
	# Returns: String
	func get_md5() -> String:
		return str(get_prefix(), message).md5_text()


	# Get all log entries, including the current entry and entries in the stack.
	#
	# Returns: Array
	func get_all_entries() -> Array:
		var entries := [self]
		entries.append_array(stack)

		return entries


# API log functions - logging
# =============================================================================


# Logs the error in red and a stack trace. Prefixed FATAL-ERROR.
#
# *Note: Stops the execution in editor*
#
# Parameters:
# - message (String): The message to be logged as an error.
# - mod_name (String): The name of the mod or ModLoader class associated with this log entry.
# - only_once (bool): (Optional) If true, the log entry will only be logged once, even if called multiple times. Default is false.
#
# Returns: void
static func fatal(message: String, mod_name: String, only_once := false) -> void:
	_log(message, mod_name, "fatal-error", only_once)


# Logs the message and pushes an error. Prefixed ERROR.
#
# *Note: Always logged*
#
# Parameters:
# - message (String): The message to be logged as an error.
# - mod_name (String): The name of the mod or ModLoader class associated with this log entry.
# - only_once (bool): (Optional) If true, the log entry will only be logged once, even if called multiple times. Default is false.
#
# Returns: void
static func error(message: String, mod_name: String, only_once := false) -> void:
	_log(message, mod_name, "error", only_once)


# Logs the message and pushes a warning. Prefixed WARNING.
#
# *Note: Logged with verbosity level at or above warning (-v).*
#
# Parameters:
# - message (String): The message to be logged as a warning.
# - mod_name (String): The name of the mod or ModLoader class associated with this log entry.
# - only_once (bool): (Optional) If true, the log entry will only be logged once, even if called multiple times. Default is false.
#
# Returns: void
static func warning(message: String, mod_name: String, only_once := false) -> void:
	_log(message, mod_name, "warning", only_once)


# Logs the message. Prefixed INFO.
#
# *Note: Logged with verbosity level at or above info (-vv).*
#
# Parameters:
# - message (String): The message to be logged as an information.
# - mod_name (String): The name of the mod or ModLoader class associated with this log entry.
# - only_once (bool): (Optional) If true, the log entry will only be logged once, even if called multiple times. Default is false.
#
# Returns: void
static func info(message: String, mod_name: String, only_once := false) -> void:
	_log(message, mod_name, "info", only_once)


# Logs the message. Prefixed SUCCESS.
#
# *Note: Logged with verbosity level at or above info (-vv).*
#
# Parameters:
# - message (String): The message to be logged as a success.
# - mod_name (String): The name of the mod or ModLoader class associated with this log entry.
# - only_once (bool): (Optional) If true, the log entry will only be logged once, even if called multiple times. Default is false.
#
# Returns: void
static func success(message: String, mod_name: String, only_once := false) -> void:
	_log(message, mod_name, "success", only_once)


# Logs the message. Prefixed DEBUG.
#
# *Note: Logged with verbosity level at or above debug (-vvv).*
#
# Parameters:
# - message (String): The message to be logged as a debug.
# - mod_name (String): The name of the mod or ModLoader class associated with this log entry.
# - only_once (bool): (Optional) If true, the log entry will only be logged once, even if called multiple times. Default is false.
#
# Returns: void
static func debug(message: String, mod_name: String, only_once := false) -> void:
	_log(message, mod_name, "debug", only_once)


# Logs the message formatted with [method JSON.print]. Prefixed DEBUG.
#
# *Note: Logged with verbosity level at or above debug (-vvv).*
#
# Parameters:
# - message (String): The message to be logged as a debug.
# - json_printable (Variant): The variable to be formatted and printed using [method JSON.print].
# - mod_name (String): The name of the mod or ModLoader class associated with this log entry.
# - only_once (bool): (Optional) If true, the log entry will only be logged once, even if called multiple times. Default is false.
#
# Returns: void
static func debug_json_print(message: String, json_printable, mod_name: String, only_once := false) -> void:
	message = "%s\n%s" % [message, JSON.print(json_printable, "  ")]
	_log(message, mod_name, "debug", only_once)


# API log functions - stored logs
# =============================================================================


# Returns an array of log entries as a resource.
#
# Returns:
# - Array: An array of log entries represented as resource.
static func get_all_as_resource() -> Array:
	return get_all()


# Returns an array of log entries as a string.
#
# Returns:
# - Array: An array of log entries represented as strings.
static func get_all_as_string() -> Array:
	var log_entries := get_all()
	return get_all_entries_as_string(log_entries)


# Returns an array of log entries as a resource for a specific mod_name.
#
# Parameters:
# - mod_name (String): The name of the mod or ModLoader class associated with the log entries.
#
# Returns:
# - Array: An array of log entries represented as resource for the specified mod_name.
static func get_by_mod_as_resource(mod_name: String) -> Array:
	return get_by_mod(mod_name)


# Returns an array of log entries as a string for a specific mod_name.
#
# Parameters:
# - mod_name (String): The name of the mod or ModLoader class associated with the log entries.
#
# Returns:
# - Array: An array of log entries represented as strings for the specified mod_name.
static func get_by_mod_as_string(mod_name: String) -> Array:
	var log_entries := get_by_mod(mod_name)
	return get_all_entries_as_string(log_entries)


# Returns an array of log entries as a resource for a specific type.
#
# Parameters:
# - type (String): The log type associated with the log entries.
#
# Returns:
# - Array: An array of log entries represented as resource for the specified type.
static func get_by_type_as_resource(type: String) -> Array:
	return get_by_type(type)


# Returns an array of log entries as a string for a specific type.
#
# Parameters:
# - type (String): The log type associated with the log entries.
#
# Returns:
# - Array: An array of log entries represented as strings for the specified type.
static func get_by_type_as_string(type: String) -> Array:
	var log_entries := get_by_type(type)
	return get_all_entries_as_string(log_entries)


# Returns an array of all log entries.
#
# Returns:
# - Array: An array of all log entries.
static func get_all() -> Array:
	var log_entries := []

	# Get all log entries
	for entry_key in ModLoaderStore.logged_messages.all.keys():
		var entry: ModLoaderLogEntry = ModLoaderStore.logged_messages.all[entry_key]
		log_entries.append_array(entry.get_all_entries())

	# Sort them by time
	log_entries.sort_custom(ModLoaderLogCompare, "time")

	return log_entries


# Returns an array of log entries for a specific mod_name.
#
# Parameters:
# - mod_name (String): The name of the mod or ModLoader class associated with the log entries.
#
# Returns:
# - Array: An array of log entries for the specified mod_name.
static func get_by_mod(mod_name: String) -> Array:
	var log_entries := []

	if not ModLoaderStore.logged_messages.by_mod.has(mod_name):
		error("\"%s\" not found in logged messages." % mod_name, LOG_NAME)
		return []

	for entry_key in ModLoaderStore.logged_messages.by_mod[mod_name].keys():
		var entry: ModLoaderLogEntry = ModLoaderStore.logged_messages.by_mod[mod_name][entry_key]
		log_entries.append_array(entry.get_all_entries())

	return log_entries


# Returns an array of log entries for a specific type.
#
# Parameters:
# - type (String): The log type associated with the log entries.
#
# Returns:
# - Array: An array of log entries for the specified type.
static func get_by_type(type: String) -> Array:
	var log_entries := []

	for entry_key in ModLoaderStore.logged_messages.by_type[type].keys():
		var entry: ModLoaderLogEntry = ModLoaderStore.logged_messages.by_type[type][entry_key]
		log_entries.append_array(entry.get_all_entries())

	return log_entries


# Returns an array of log entries represented as strings.
#
# Parameters:
# - log_entries (Array): An array of ModLoaderLogEntry Objects.
#
# Returns:
# - Array: An array of log entries represented as strings.
static func get_all_entries_as_string(log_entries: Array) -> Array:
	var log_entry_strings := []

	# Get all the strings
	for entry in log_entries:
		log_entry_strings.push_back(entry.get_entry())

	return log_entry_strings


# Internal log functions
# =============================================================================

static func _log(message: String, mod_name: String, log_type: String = "info", only_once := false) -> void:
	if _is_mod_name_ignored(mod_name):
		return

	var time := "%s   " % _get_time_string()
	var log_entry := ModLoaderLogEntry.new(mod_name, message, log_type, time)

	if only_once and _is_logged_before(log_entry):
		return

	if ModLoaderStore:
		_store_log(log_entry)

	# Check if the scene_tree is available
	if Engine.get_main_loop():
		ModLoader.emit_signal("logged", log_entry)

	_code_note(str(
		"If you are seeing this after trying to run the game, there is an error in your mod somewhere.",
		"Check the Debugger tab (below) to see the error.",
		"Click through the files listed in Stack Frames to trace where the error originated.",
		"View Godot's documentation for more info:",
		"https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html#doc-debugger-panel"
	))

	match log_type.to_lower():
		"fatal-error":
			push_error(message)
			_write_to_log_file(log_entry.get_entry())
			_write_to_log_file(JSON.print(get_stack(), "  "))
			assert(false, message)
		"error":
			printerr(message)
			push_error(message)
			_write_to_log_file(log_entry.get_entry())
		"warning":
			if _get_verbosity() >= VERBOSITY_LEVEL.WARNING:
				print(log_entry.get_prefix() + message)
				push_warning(message)
				_write_to_log_file(log_entry.get_entry())
		"info", "success":
			if _get_verbosity() >= VERBOSITY_LEVEL.INFO:
				print(log_entry.get_prefix() + message)
				_write_to_log_file(log_entry.get_entry())
		"debug":
			if _get_verbosity() >= VERBOSITY_LEVEL.DEBUG:
				print(log_entry.get_prefix() + message)
				_write_to_log_file(log_entry.get_entry())


static func _is_mod_name_ignored(mod_log_name: String) -> bool:
	if not ModLoaderStore:
		return false

	var ignored_mod_log_names := ModLoaderStore.ml_options.ignored_mod_names_in_log as Array

	# No ignored mod names
	if ignored_mod_log_names.size() == 0:
		return false

	# Directly match a full mod log name. ex: "ModLoader:Deprecated"
	if mod_log_name in ignored_mod_log_names:
		return true

	# Match a mod log name with a wildcard. ex: "ModLoader:*"
	for ignored_mod_name in ignored_mod_log_names:
		if ignored_mod_name.ends_with("*"):
			if mod_log_name.begins_with(ignored_mod_name.trim_suffix("*")):
				return true

	# No match
	return false


static func _get_verbosity() -> int:
	if not ModLoaderStore:
		return VERBOSITY_LEVEL.DEBUG
	return ModLoaderStore.ml_options.log_level


static func _store_log(log_entry: ModLoaderLogEntry) -> void:
	var existing_entry: ModLoaderLogEntry

	# Store in all
	# If it's a new entry
	if not ModLoaderStore.logged_messages.all.has(log_entry.get_md5()):
		ModLoaderStore.logged_messages.all[log_entry.get_md5()] = log_entry
	# If it's a existing entry
	else:
		existing_entry = ModLoaderStore.logged_messages.all[log_entry.get_md5()]
		existing_entry.time = log_entry.time
		existing_entry.stack.push_back(log_entry)

	# Store in by_mod
	# If the mod is not yet in "by_mod" init the entry
	if not ModLoaderStore.logged_messages.by_mod.has(log_entry.mod_name):
		ModLoaderStore.logged_messages.by_mod[log_entry.mod_name] = {}

	ModLoaderStore.logged_messages.by_mod[log_entry.mod_name][log_entry.get_md5()] = log_entry if not existing_entry else existing_entry

	# Store in by_type
	ModLoaderStore.logged_messages.by_type[log_entry.type.to_lower()][log_entry.get_md5()] = log_entry if not existing_entry else existing_entry


static func _is_logged_before(entry: ModLoaderLogEntry) -> bool:
	if not ModLoaderStore.logged_messages.all.has(entry.get_md5()):
		return false

	return true


class ModLoaderLogCompare:
	# Custom sorter that orders logs by time
	static func time(a: ModLoaderLogEntry, b: ModLoaderLogEntry) -> bool:
		if a.time_stamp > b.time_stamp:
			return true # a -> b
		else:
			return false # b -> a


# Internal Date Time
# =============================================================================

# Returns the current time as a string in the format hh:mm:ss
static func _get_time_string() -> String:
	var date_time := Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [ date_time.hour, date_time.minute, date_time.second ]


# Returns the current date as a string in the format yyyy-mm-dd
static func _get_date_string() -> String:
	var date_time := Time.get_datetime_dict_from_system()
	return "%s-%02d-%02d" % [ date_time.year, date_time.month, date_time.day ]


# Returns the current date and time as a string in the format yyyy-mm-dd_hh:mm:ss
static func _get_date_time_string() -> String:
	return "%s_%s" % [ _get_date_string(), _get_time_string() ]



# Internal File
# =============================================================================

static func _write_to_log_file(string_to_write: String) -> void:
	var log_file := File.new()

	if not log_file.file_exists(MOD_LOG_PATH):
		_rotate_log_file()

	var error := log_file.open(MOD_LOG_PATH, File.READ_WRITE)
	if not error == OK:
		assert(false, "Could not open log file, error code: %s" % error)
		return

	log_file.seek_end()
	log_file.store_string("\n" + string_to_write)
	log_file.close()


# Keeps log backups for every run, just like the Godot gdscript implementation of
# https://github.com/godotengine/godot/blob/1d14c054a12dacdc193b589e4afb0ef319ee2aae/core/io/logger.cpp#L151
static func _rotate_log_file() -> void:
	var MAX_LOGS := int(ProjectSettings.get_setting("logging/file_logging/max_log_files"))
	var log_file := File.new()

	if log_file.file_exists(MOD_LOG_PATH):
		if MAX_LOGS > 1:
			var datetime := _get_date_time_string().replace(":", ".")
			var backup_name: String = MOD_LOG_PATH.get_basename() + "_" + datetime
			if MOD_LOG_PATH.get_extension().length() > 0:
				backup_name += "." + MOD_LOG_PATH.get_extension()

			var dir := Directory.new()
			if dir.dir_exists(MOD_LOG_PATH.get_base_dir()):
				dir.copy(MOD_LOG_PATH, backup_name)
			_clear_old_log_backups()

	# only File.WRITE creates a new file, File.READ_WRITE throws an error
	var error := log_file.open(MOD_LOG_PATH, File.WRITE)
	if not error == OK:
		assert(false, "Could not open log file, error code: %s" % error)
	log_file.store_string('%s Created log' % _get_date_string())
	log_file.close()


static func _clear_old_log_backups() -> void:
	var MAX_LOGS := int(ProjectSettings.get_setting("logging/file_logging/max_log_files"))
	var MAX_BACKUPS := MAX_LOGS - 1 # -1 for the current new log (not a backup)
	var basename := MOD_LOG_PATH.get_file().get_basename() as String
	var extension := MOD_LOG_PATH.get_extension() as String

	var dir := Directory.new()
	if not dir.dir_exists(MOD_LOG_PATH.get_base_dir()):
		return
	if not dir.open(MOD_LOG_PATH.get_base_dir()) == OK:
		return

	dir.list_dir_begin()
	var file := dir.get_next()
	var backups := []
	while file.length() > 0:
		if (not dir.current_is_dir() and
				file.begins_with(basename) and
				file.get_extension() == extension and
				not file == MOD_LOG_PATH.get_file()):
			backups.append(file)
		file = dir.get_next()
	dir.list_dir_end()

	if backups.size() > MAX_BACKUPS:
		backups.sort()
		backups.resize(backups.size() - MAX_BACKUPS)
		for file_to_delete in backups:
			dir.remove(file_to_delete)


# Internal util funcs
# =============================================================================
# This are duplicates of the functions in mod_loader_utils.gd to prevent
# a cyclic reference error between ModLoaderLog and ModLoaderUtils.


# This is a dummy func. It is exclusively used to show notes in the code that
# stay visible after decompiling a PCK, as is primarily intended to assist new
# modders in understanding and troubleshooting issues.
static func _code_note(_msg:String):
	pass
