extends Node
class_name ModLoaderUtils

const LOG_NAME := "ModLoader:ModLoaderUtils"
const MOD_LOG_PATH := "user://logs/modloader.log"

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

	var time := "%s   " % get_time_string()
	var prefix := "%s %s: " % [log_type.to_upper(), mod_name]
	var log_message := time + prefix + message

	match log_type.to_lower():
		"fatal-error":
			push_error(message)
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
		rotate_log_file()

	var error := log_file.open(MOD_LOG_PATH, File.READ_WRITE)
	if not error == OK:
		assert(false, "Could not open log file, error code: %s" % error)
		return

	log_file.seek_end()
	log_file.store_string("\n" + log_entry)
	log_file.close()


# Keeps log backups for every run, just like the Godot; gdscript implementation of
# https://github.com/godotengine/godot/blob/1d14c054a12dacdc193b589e4afb0ef319ee2aae/core/io/logger.cpp#L151
static func rotate_log_file() -> void:
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


static func clear_old_log_backups() -> void:
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


# Returns the current time as a string in the format hh:mm:ss
static func get_time_string() -> String:
	var date_time = Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [ date_time.hour, date_time.minute, date_time.second ]


# Returns the current date as a string in the format yyyy-mm-dd
static func get_date_string() -> String:
	var date_time = Time.get_datetime_dict_from_system()
	return "%s-%02d-%02d" % [ date_time.year, date_time.month, date_time.day ]


# Returns the current date and time as a string in the format yyyy-mm-dd_hh:mm:ss
static func get_date_time_string() -> String:
	return "%s_%s" % [ get_date_string(), get_time_string() ]


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


static func file_exists(path: String) -> bool:
	var file = File.new()
	return file.file_exists(path)


static func dir_exists(path: String) -> bool:
	var dir = Directory.new()
	return dir.dir_exists(path)


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
					log_info('Class "%s" to be registered as global was already registered by the editor. Skipping.' % new_class.class, LOG_NAME)
				else:
					log_info('Class "%s" to be registered as global already exists. Skipping.' % new_class.class, LOG_NAME)
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
		log_fatal("Global class to be registered is missing one of %s" % required_fields, LOG_NAME)
		return false

	var file = File.new()
	if not file.file_exists(global_class_dict.path):
		log_fatal('Class "%s" to be registered as global could not be found at given path "%s"' %
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


# Get a flat array of all files in the target directory. This was needed in the
# original version of this script, before becoming deprecated. It may still be
# used if DEBUG_ENABLE_STORING_FILEPATHS is true.
# Source: https://gist.github.com/willnationsdev/00d97aa8339138fd7ef0d6bd42748f6e
static func get_flat_view_dict(p_dir := "res://", p_match := "", p_match_is_regex := false) -> PoolStringArray:
	var data: PoolStringArray = []
	var regex: RegEx
	if p_match_is_regex:
		regex = RegEx.new()
		var _compile_error: int = regex.compile(p_match)
		if not regex.is_valid():
			return data

	var dirs := [p_dir]
	var first := true
	while not dirs.empty():
		var dir := Directory.new()
		var dir_name: String = dirs.back()
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			var _dirlist_error: int = dir.list_dir_begin()
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


# Saves a dictionary to a file, as a JSON string
static func save_string_to_file(save_string: String, filepath: String) -> bool:
	# Create directory if it doesn't exist yet
	var file_directory := filepath.get_base_dir()
	var dir := Directory.new()
	if not dir.dir_exists(file_directory):
		var makedir_error = dir.make_dir_recursive(file_directory)
		if not makedir_error == OK:
			# @todo: Uncomment when PR #139 is merged: https://github.com/GodotModding/godot-mod-loader/pull/139
			#code_note("View error codes here: https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error")
			log_fatal("Encountered an error (%s) when attempting to create a directory, with the path: %s" % [makedir_error, file_directory], LOG_NAME)
			return false

	var file = File.new()

	# Save data to the file
	var fileopen_error = file.open(filepath, File.WRITE)

	if not fileopen_error == OK:
		# @todo: Uncomment when PR #139 is merged: https://github.com/GodotModding/godot-mod-loader/pull/139
		#code_note("View error codes here: https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error")
		log_fatal("Encountered an error (%s) when attempting to write to a file, with the path: %s" % [fileopen_error, filepath], LOG_NAME)
		return false

	file.store_string(save_string)
	file.close()

	return true


# Saves a dictionary to a file, as a JSON string
static func save_dictionary_to_file(data: Dictionary, filepath: String) -> bool:
	var json_string = JSON.print(data, "\t")
	return save_string_to_file(json_string, filepath)
