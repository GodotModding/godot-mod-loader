extends Node
class_name ModLoaderUtils

const MOD_LOG_PATH = "user://mods.log"

enum verbosity_level {
	ERROR,
	WARNING,
	INFO,
	DEBUG,
}

# Logs the error in red and a stack trace. Prefixed FATAL-ERROR
# Stops the execution in editor
# Always logged
static func log_fatal(message: String, mod_name: String) -> void:
	_loader_log(message, mod_name, "fatal-error")


# Logs the message and pushed an error. Prefixed ERROR
# Always logged
static func log_error(message: String, mod_name: String) -> void:
	_loader_log(message, mod_name, "error")


# Logs the message and pushes a warning. Prefixed WARNING
# Logged with verbosity level at or above warning (-v)
static func log_warning(message: String, mod_name: String) -> void:
	_loader_log(message, mod_name, "warning")


# Logs the message. Prefixed INFO
# Logged with verbosity level at or above info (-vv)
static func log_info(message: String, mod_name: String) -> void:
	_loader_log(message, mod_name, "info")


# Logs the message. Prefixed SUCCESS
# Logged with verbosity level at or above info (-vv)
static func log_success(message: String, mod_name: String) -> void:
	_loader_log(message, mod_name, "success")


# Logs the message. Prefixed DEBUG
# Logged with verbosity level at or above debug (-vvv)
static func log_debug(message: String, mod_name: String) -> void:
	_loader_log(message, mod_name, "debug")


# Logs the message formatted with [method JSON.print]. Prefixed DEBUG
# Logged with verbosity level at or above debug (-vvv)
static func log_debug_json_print(message: String, json_printable, mod_name: String) -> void:
	message = "%s\n%s" % [message, JSON.print(json_printable, "  ")]
	_loader_log(message, mod_name, "debug")


static func _loader_log(message: String, mod_name: String, log_type: String = "info")->void:
	var date := "%s   " % get_date_time_string()
	var prefix := "%s %s: " % [log_type.to_upper(), mod_name]
	var log_message := date + prefix + message

	match log_type.to_lower():
		"fatal-error":
			write_to_log_file(log_message)
			write_to_log_file(JSON.print(get_stack(), "  "))
			assert(false, message)
		"error":
			printerr(message)
			push_error(message)
			write_to_log_file(log_message)
		"warning":
			if get_verbosity() >= verbosity_level.WARNING:
				print(prefix + message)
				push_warning(message)
				write_to_log_file(log_message)
		"info", "success":
			if get_verbosity() >= verbosity_level.INFO:
				print(prefix + message)
				write_to_log_file(log_message)
		"debug":
			if get_verbosity() >= verbosity_level.DEBUG:
				print(prefix + message)
				write_to_log_file(log_message)


static func write_to_log_file(log_entry: String) -> void:
	var log_file = File.new()

	if not log_file.file_exists(MOD_LOG_PATH):
		log_file.open(MOD_LOG_PATH, File.WRITE)
		log_file.store_string('%s\t Created mod.log!' % get_date_time_string())
		log_file.close()

	var _error: int = log_file.open(MOD_LOG_PATH, File.READ_WRITE)
	if not _error == OK:
		assert(false, "Could not open log file, error code: %s" % _error)
		return

	log_file.seek_end()
	log_file.store_string("\n" + log_entry)
	log_file.close()


static func get_verbosity() -> int:
	if is_running_with_command_line_arg("-vvv") or is_running_with_command_line_arg("--log-debug"):
		return verbosity_level.DEBUG
	if is_running_with_command_line_arg("-vv") or is_running_with_command_line_arg("--log-info"):
		return verbosity_level.INFO
	if is_running_with_command_line_arg("-v") or is_running_with_command_line_arg("--log-warning"):
		return verbosity_level.WARNING

	if OS.has_feature("editor"):
		return verbosity_level.DEBUG

	return verbosity_level.ERROR


# Check if the provided command line argument was present when launching the game
static func is_running_with_command_line_arg(argument: String) -> bool:
	for arg in OS.get_cmdline_args():
		if arg == argument:
			return true

	return false


# Get the command line argument value if present when launching the game
static func get_cmd_line_arg_value(argument: String) -> String:
	for arg in OS.get_cmdline_args():
		if arg.find("=") > -1:
			var key_value = arg.split("=")
			# True if the checked argument matches a user-specified arg key
			# (eg. checking `--mods-path` will match with `--mods-path="C://mods"`
			if key_value[0] == argument:
				return key_value[1]

	return ""


# Returns the current date and time as a string in the format dd.mm.yy-hh:mm:ss
static func get_date_time_string() -> String:
	var date_time = Time.get_datetime_dict_from_system()

	return "%02d.%02d.%s-%02d:%02d:%02d" % [
		date_time.day, date_time.month, date_time.year,
		date_time.hour, date_time.minute, date_time.second
	]


