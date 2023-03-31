class_name LogManager


const MOD_LOG_PATH := "user://logs/modloader.log"

enum VERBOSITY_LEVEL {
	ERROR,
	WARNING,
	INFO,
	DEBUG,
}

var all := {}
var by_mod := {}
var by_type := {
	"fatal-error": {},
	"error": {},
	"warning": {},
	"info": {},
	"success": {},
	"debug": {},
}


func log(message: String, mod_name: String, log_type: String = "info") -> void:
	if _is_mod_name_ignored(mod_name):
		return

	var time := "%s   " % get_time_string()
	var log_entry := LogEntry.new(mod_name, message, log_type, time)
	store_log(log_entry)

	ModLoaderUtils.code_note(str(
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


func _write_to_log_file(string_to_write: String) -> void:
	var log_file := File.new()

	if not log_file.file_exists(MOD_LOG_PATH):
		rotate_log_file()

	var error := log_file.open(MOD_LOG_PATH, File.READ_WRITE)
	if not error == OK:
		assert(false, "Could not open log file, error code: %s" % error)
		return

	log_file.seek_end()
	log_file.store_string("\n" + string_to_write)
	log_file.close()


func _is_mod_name_ignored(mod_name: String) -> bool:
	var ignored_arg := ModLoaderUtils.get_cmd_line_arg_value("--log-ignore")

	if not ignored_arg == "":
		var ignored_names: Array = ignored_arg.split(",")
		if mod_name in ignored_names:
			return true
	return false


# Returns the current time as a string in the format hh:mm:ss
func get_time_string() -> String:
	var date_time = Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [ date_time.hour, date_time.minute, date_time.second ]


# Returns the current date as a string in the format yyyy-mm-dd
func get_date_string() -> String:
	var date_time = Time.get_datetime_dict_from_system()
	return "%s-%02d-%02d" % [ date_time.year, date_time.month, date_time.day ]


# Returns the current date and time as a string in the format yyyy-mm-dd_hh:mm:ss
func get_date_time_string() -> String:
	return "%s_%s" % [ get_date_string(), get_time_string() ]


func _get_verbosity() -> int:
	var modloader_store := ModLoaderUtils.get_modloader_store()
	if not modloader_store:
		# This lets us get a verbosity level even when ModLoaderStore is not in
		# the correct autoload position (which they'll be notified about via
		# `_check_autoload_positions`)
		return VERBOSITY_LEVEL.DEBUG
	else:
		return modloader_store.ml_options.log_level


# Keeps log backups for every run, just like the Godot; gdscript implementation of
# https://github.com/godotengine/godot/blob/1d14c054a12dacdc193b589e4afb0ef319ee2aae/core/io/logger.cpp#L151
func rotate_log_file() -> void:
	var MAX_LOGS := int(ProjectSettings.get_setting("logging/file_logging/max_log_files"))
	var log_file := File.new()

	if log_file.file_exists(MOD_LOG_PATH):
		if MAX_LOGS > 1:
			var datetime := get_date_time_string().replace(":", ".")
			var backup_name := MOD_LOG_PATH.get_basename() + "_" + datetime
			if MOD_LOG_PATH.get_extension().length() > 0:
				backup_name += "." + MOD_LOG_PATH.get_extension()

			var dir := Directory.new()
			if dir.dir_exists(MOD_LOG_PATH.get_base_dir()):
				dir.copy(MOD_LOG_PATH, backup_name)
			clear_old_log_backups()

	# only File.WRITE creates a new file, File.READ_WRITE throws an error
	var error := log_file.open(MOD_LOG_PATH, File.WRITE)
	if not error == OK:
		assert(false, "Could not open log file, error code: %s" % error)
	log_file.store_string('%s Created log' % get_date_string())
	log_file.close()


func clear_old_log_backups() -> void:
	var MAX_LOGS := int(ProjectSettings.get_setting("logging/file_logging/max_log_files"))
	var MAX_BACKUPS := MAX_LOGS - 1 # -1 for the current new log (not a backup)
	var basename := MOD_LOG_PATH.get_file().get_basename()
	var extension := MOD_LOG_PATH.get_extension()

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


func store_log(log_entry: LogEntry) -> void:
	# Store in all
	all[log_entry.get_md5()] = log_entry

	# Store in by_mod
	# If the mod is not yet in "by_mod" init the entry
	if not by_mod.has(log_entry.mod_name):
		by_mod[log_entry.mod_name] = {}

	by_mod[log_entry.mod_name][log_entry.get_md5()] = log_entry

	# Store in by_type
	by_type[log_entry.type.to_lower()][log_entry.get_md5()] = log_entry
