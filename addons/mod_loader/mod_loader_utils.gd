extends Node
class_name ModLoaderUtils

const LOG_NAME := "ModLoader:ModLoaderUtils"
const MOD_LOG_PATH := "user://mods.log"

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


static func _loader_log(message: String, mod_name: String, log_type: String = "info") -> void:
	if is_mod_name_ignored(mod_name):
		return

	var date := "%s   " % get_date_time_string()
	var prefix := "%s %s: " % [log_type.to_upper(), mod_name]
	var log_message := date + prefix + message

	match log_type.to_lower():
		"fatal-error":
			_write_to_log_file(log_message)
			_write_to_log_file(JSON.print(get_stack(), "  "))
			assert(false, message)
		"error":
			printerr(message)
			push_error(message)
			_write_to_log_file(log_message)
		"warning":
			if _get_verbosity() >= verbosity_level.WARNING:
				print(prefix + message)
				push_warning(message)
				_write_to_log_file(log_message)
		"info", "success":
			if _get_verbosity() >= verbosity_level.INFO:
				print(prefix + message)
				_write_to_log_file(log_message)
		"debug":
			if _get_verbosity() >= verbosity_level.DEBUG:
				print(prefix + message)
				_write_to_log_file(log_message)


static func is_mod_name_ignored(mod_name: String) -> bool:
	var ignored_arg := get_cmd_line_arg_value("--log-ignore")

	if not ignored_arg == "":
		var ignored_names: Array = ignored_arg.split(",")
		if mod_name in ignored_names:
			return true
	return false


static func _write_to_log_file(log_entry: String) -> void:
	var log_file := File.new()

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


static func _get_verbosity() -> int:
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
		if (arg as String).find("=") > -1:
			var key_value := (arg as String).split("=")
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


# Provide a path, get the file name at the end of the path
static func get_file_name_from_path(path: String, make_lower_case := true, remove_extension := false) -> String:
	var file_name := path.get_file()

	if make_lower_case:
		file_name = file_name.to_lower()

	if remove_extension:
		file_name = file_name.trim_suffix("." + file_name.get_extension())

	return file_name


# Parses JSON from a given file path and returns a [Dictionary].
# Returns an empty [Dictionary] if no file exists (check with size() < 1)
static func get_json_as_dict(path: String) -> Dictionary:
	var file := File.new()

	if !file.file_exists(path):
		file.close()
		return {}

	var error = file.open(path, File.READ)
	if not error == OK:
		log_error("Error opening file. Code: %s" % error, LOG_NAME)

	var content := file.get_as_text()
	return get_json_string_as_dict(content)


# Parses JSON from a given [String] and returns a [Dictionary].
# Returns an empty [Dictionary] on error (check with size() < 1)
static func get_json_string_as_dict(string: String) -> Dictionary:
	if string == "":
		return {}
	var parsed := JSON.parse(string)
	if parsed.error:
		log_error("Error parsing JSON", LOG_NAME)
		return {}
	if not parsed.result is Dictionary:
		log_error("JSON is not a dictionary", LOG_NAME)
		return {}
	return parsed.result


# Register an array of classes to the global scope, since Godot only does that in the editor.
# Format: { "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }
# You can find these easily in the project.godot file under "_global_script_classes"
# (but you should only include classes belonging to your mod)
static func register_global_classes_from_array(new_global_classes: Array) -> void:
	var registered_classes: Array = ProjectSettings.get_setting("_global_script_classes")
	var registered_class_icons: Dictionary = ProjectSettings.get_setting("_global_script_class_icons")

	for new_class in new_global_classes:
		if not is_valid_global_class_dict(new_class):
			continue
		if registered_classes.has(new_class):
			continue

		registered_classes.append(new_class)
		registered_class_icons[new_class.class] = "" # empty icon, does not matter

	ProjectSettings.set_setting("_global_script_classes", registered_classes)
	ProjectSettings.set_setting("_global_script_class_icons", registered_class_icons)
	ProjectSettings.save_custom(get_override_path())


# Checks if all required fields are in the given [Dictionary]
# Format: { "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }
static func is_valid_global_class_dict(global_class_dict: Dictionary) -> bool:
	var required_fields := ["base", "class", "language", "path"]
	if not global_class_dict.has_all(required_fields):
		log_fatal("Global class to be registered is missing one of %s" % required_fields, LOG_NAME)
		return false

	var file = File.new()
	if not file.file_exists(global_class_dict.path):
		log_fatal('Class "%s" to be registered as global could not be found at given path "%s"' %
		[global_class_dict.class, global_class_dict.path], LOG_NAME)
		return false

	return true


# Get a flat array of all files in the target directory. This was needed in the
# original version of this script, before becoming deprecated. It may still be
# used if DEBUG_ENABLE_STORING_FILEPATHS is true.
# Source: https://gist.github.com/willnationsdev/00d97aa8339138fd7ef0d6bd42748f6e
static func get_flat_view_dict(p_dir := "res://", p_match := "", p_match_is_regex := false) -> Array:
	var regex: RegEx
	if p_match_is_regex:
		regex = RegEx.new()
		regex.compile(p_match)
		if not regex.is_valid():
			return []

	var dirs := [p_dir]
	var first := true
	var data := []
	while not dirs.empty():
		var dir := Directory.new()
		var dir_name: String = dirs.back()
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir_name == "res://":
					first = false
				# ignore hidden, temporary, or system content
				if not file_name.begins_with(".") and not file_name.get_extension() in ["tmp", "import"]:
					# If a directory, then add to list of directories to visit
					if dir.current_is_dir():
						dirs.push_back(dir.get_current_dir().plus_file(file_name))
					# If a file, check if we already have a record for the same name
					else:
						var path := dir.get_current_dir() + ("/" if not first else "") + file_name
						# grab all
						if not p_match:
							data.append(path)
						# grab matching strings
						elif not p_match_is_regex and file_name.find(p_match, 0) != -1:
							data.append(path)
						# grab matching regex
						else:
							var regex_match := regex.search(path)
							if regex_match != null:
								data.append(path)
				# Move on to the next file in this directory
				file_name = dir.get_next()
			# We've exhausted all files in this directory. Close the iterator.
			dir.list_dir_end()
	return data

