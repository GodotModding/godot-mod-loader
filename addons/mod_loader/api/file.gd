class_name _ModLoaderFile
extends Reference


# This Class provides util functions for working with files.
# Currently all of the included functions are internal and should only be used by the mod loader itself.

const LOG_NAME := "ModLoader:File"


# Get Data
# =============================================================================

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


# Save Data
# =============================================================================

# Saves a dictionary to a file, as a JSON string
static func save_string_to_file(save_string: String, filepath: String) -> bool:
	# Create directory if it doesn't exist yet
	var file_directory := filepath.get_base_dir()
	var dir := Directory.new()

	_code_note(str(
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


# Checks
# =============================================================================

static func file_exists(path: String) -> bool:
	var file = File.new()
	return file.file_exists(path)


static func dir_exists(path: String) -> bool:
	var dir = Directory.new()
	return dir.dir_exists(path)


# Internal util functions
# =============================================================================
# This are duplicates of the functions in mod_loader_utils.gd to prevent
# a cyclic reference error.

# This is a dummy func. It is exclusively used to show notes in the code that
# stay visible after decompiling a PCK, as is primarily intended to assist new
# modders in understanding and troubleshooting issues.
static func _code_note(_msg:String):
	pass
