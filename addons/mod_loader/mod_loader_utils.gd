class_name ModLoaderUtils
extends Node


const LOG_NAME := "ModLoader:ModLoaderUtils"
const MOD_CONFIG_DIR_PATH := "user://configs"


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


# This is a dummy func. It is exclusively used to show notes in the code that
# stay visible after decompiling a PCK, as is primarily intended to assist new
# modders in understanding and troubleshooting issues
static func code_note(_msg:String):
	pass


# Returns a reference to the ModLoaderStore autoload if it exists, or null otherwise.
# This function can be used to get a reference to the ModLoaderStore autoload in functions
# that may be called before the autoload is initialized.
# If the ModLoaderStore autoload does not exist in the global scope, this function returns null.
static func get_modloader_store() -> Object:
	return Engine.get_singleton("ModLoaderStore") if Engine.has_singleton("ModLoaderStore") else null


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
		ModLoaderLog.error("Error opening file. Code: %s" % error, LOG_NAME)

	var content := file.get_as_text()
	return get_json_string_as_dict(content)


# Parses JSON from a given [String] and returns a [Dictionary].
# Returns an empty [Dictionary] on error (check with size() < 1)
static func get_json_string_as_dict(string: String) -> Dictionary:
	if string == "":
		return {}
	var parsed := JSON.parse(string)
	if parsed.error:
		ModLoaderLog.error("Error parsing JSON", LOG_NAME)
		return {}
	if not parsed.result is Dictionary:
		ModLoaderLog.error("JSON is not a dictionary", LOG_NAME)
		return {}
	return parsed.result


static func file_exists(path: String) -> bool:
	var file = File.new()
	return file.file_exists(path)


static func dir_exists(path: String) -> bool:
	var dir = Directory.new()
	return dir.dir_exists(path)


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

	var file = File.new()
	if not file.file_exists(global_class_dict.path):
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


# Saving (Files)
# =============================================================================

# Saves a dictionary to a file, as a JSON string
static func save_string_to_file(save_string: String, filepath: String) -> bool:
	# Create directory if it doesn't exist yet
	var file_directory := filepath.get_base_dir()
	var dir := Directory.new()

	code_note(str(
		"View error codes here:",
		"https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error"
	))

	if not dir.dir_exists(file_directory):
		var makedir_error = dir.make_dir_recursive(file_directory)
		if not makedir_error == OK:
			ModLoaderLog.fatal("Encountered an error (%s) when attempting to create a directory, with the path: %s" % [makedir_error, file_directory], LOG_NAME)
			return false

	var file = File.new()

	# Save data to the file
	var fileopen_error = file.open(filepath, File.WRITE)

	if not fileopen_error == OK:
		ModLoaderLog.fatal("Encountered an error (%s) when attempting to write to a file, with the path: %s" % [fileopen_error, filepath], LOG_NAME)
		return false

	file.store_string(save_string)
	file.close()

	return true


# Saves a dictionary to a file, as a JSON string
static func save_dictionary_to_json_file(data: Dictionary, filepath: String) -> bool:
	var json_string = JSON.print(data, "\t")
	return save_string_to_file(json_string, filepath)


# Paths
# =============================================================================

# Get the path to the mods folder, with any applicable overrides applied
static func get_path_to_mods() -> String:
	var modloader_store := get_modloader_store()
	var mods_folder_path := get_local_folder_dir("mods")
	if modloader_store:
		if modloader_store.ml_options.override_path_to_mods:
			mods_folder_path = modloader_store.ml_options.override_path_to_mods
	return mods_folder_path


# Get the path to the configs folder, with any applicable overrides applied
static func get_path_to_configs() -> String:
	var modloader_store := get_modloader_store()
	var configs_path := MOD_CONFIG_DIR_PATH
	if modloader_store:
		if modloader_store.ml_options.override_path_to_configs:
			configs_path = modloader_store.ml_options.override_path_to_configs
	return configs_path
