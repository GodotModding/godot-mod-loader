class_name _ModLoaderFile
extends RefCounted


# This Class provides util functions for working with files.
# Currently all of the included functions are internal and should only be used by the mod loader itself.

const LOG_NAME := "ModLoader:File"

# Get Data
# =============================================================================

# Parses JSON from a given file path and returns a [Dictionary].
# Returns an empty [Dictionary] if no file exists (check with size() < 1)
static func get_json_as_dict(path: String) -> Dictionary:
	if not file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var error = file.get_open_error()

	if file == null:
		ModLoaderLog.error("Error opening file. Code: %s" % error, LOG_NAME)

	var content := file.get_as_text()
	return _get_json_string_as_dict(content)


# Parses JSON from a given [String] and returns a [Dictionary].
# Returns an empty [Dictionary] on error (check with size() < 1)
static func _get_json_string_as_dict(string: String) -> Dictionary:
	if string == "":
		return {}

	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(string)
	if not error == OK:
		ModLoaderLog.error("Error parsing JSON", LOG_NAME)
		return {}

	if not test_json_conv.data is Dictionary:
		ModLoaderLog.error("JSON is not a dictionary", LOG_NAME)
		return {}
	return test_json_conv.data


# Opens the path and reports all the errors that can happen
static func open_dir(folder_path: String) -> DirAccess:
	var mod_dir := DirAccess.open(folder_path)
	if mod_dir == null:
		ModLoaderLog.error("Can't open mod folder %s" % [folder_path], LOG_NAME)
		return null

	var mod_dir_open_error := mod_dir.get_open_error()
	if not mod_dir_open_error == OK:
		ModLoaderLog.info(
			"Can't open mod folder %s (Error: %s, %s)" %
			[folder_path, mod_dir_open_error, error_string(mod_dir_open_error)],
			LOG_NAME
		)
		return null
	var mod_dir_listdir_error := mod_dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	if not mod_dir_listdir_error == OK:
		ModLoaderLog.error(
			"Can't read mod folder %s (Error: %s, %s)" %
			[folder_path, mod_dir_listdir_error, error_string(mod_dir_listdir_error)],
			LOG_NAME
		)
		return null

	return mod_dir


static func get_json_as_dict_from_zip(zip_path: String, file_path: String, is_full_path := false) -> Dictionary:
	if not file_exists(zip_path):
		ModLoaderLog.error("Zip was not found at %s" % [zip_path], LOG_NAME)
		return {}

	var reader := ZIPReader.new()

	var zip_open_error := reader.open(zip_path)
	if not zip_open_error == OK:
		ModLoaderLog.error(
			"Error opening zip. (Error: %s, %s)" %
			[zip_open_error, error_string(zip_open_error)],
			LOG_NAME
		)

	var full_path := ""
	if is_full_path:
		full_path = file_path
		if not reader.file_exists(full_path):
			ModLoaderLog.error("File was not found in zip at path %s" % [file_path], LOG_NAME)
			return {}
	else:
		# Go through all files and find the file
		# Since we don't know which mod folder will be in the zip to get the exact full path
		# (zip naming is not required to be the name as folder name)
		for path in reader.get_files():
			if Array(path.rsplit("/", false, 1)).back() == file_path:
				full_path = path
		if not full_path:
			ModLoaderLog.error("File was not found in zip at path %s" % [file_path], LOG_NAME)
			return {}

	var content := reader.read_file(full_path).get_string_from_utf8()
	return _get_json_string_as_dict(content)


# Finds the global paths to all zips in provided directory
static func get_zip_paths_in(folder_path: String) -> Array[String]:
	var zip_paths: Array[String] = []

	var files := Array(DirAccess.get_files_at(folder_path))\
	.filter(
		func(file_name: String):
			return file_name.get_extension() == "zip"
	).map(
		func(file_name: String):
			var global_path := ProjectSettings.globalize_path(folder_path.path_join(file_name))
			ModLoaderLog.debug("Found mod ZIP: %s" % global_path, LOG_NAME)
			return global_path
	)

	# only assign casts to the nested Array type we want to return
	zip_paths.assign(files)
	return zip_paths


# Save Data
# =============================================================================

# Saves a dictionary to a file, as a JSON string
static func _save_string_to_file(save_string: String, filepath: String) -> bool:
	# Create directory if it doesn't exist yet
	var file_directory := filepath.get_base_dir()
	var dir := DirAccess.open(file_directory)

	_code_note(str(
		"View error codes here:",
		"https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error"
	))

	if not dir:
		var makedir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file_directory))
		if not makedir_error == OK:
			ModLoaderLog.fatal("Encountered an error (%s) when attempting to create a directory, with the path: %s" % [makedir_error, file_directory], LOG_NAME)
			return false

	# Save data to the file
	var file := FileAccess.open(filepath, FileAccess.WRITE)

	if not file:
		ModLoaderLog.fatal("Encountered an error (%s) when attempting to write to a file, with the path: %s" % [FileAccess.get_open_error(), filepath], LOG_NAME)
		return false

	file.store_string(save_string)
	file.close()

	return true


# Saves a dictionary to a file, as a JSON string
static func save_dictionary_to_json_file(data: Dictionary, filepath: String) -> bool:
	var json_string := JSON.stringify(data, "\t")
	return _save_string_to_file(json_string, filepath)


# Remove Data
# =============================================================================

# Removes a file from the given path
static func remove_file(file_path: String) -> bool:
	var dir := DirAccess.open(file_path)

	if not dir.file_exists(file_path):
		ModLoaderLog.error("No file found at \"%s\"" % file_path, LOG_NAME)
		return false

	var error := dir.remove(file_path)

	if error:
		ModLoaderLog.error(
			"Encountered an error (%s) when attempting to remove the file, with the path: %s"
			% [error, file_path],
			LOG_NAME
		)
		return false

	return true


# Checks
# =============================================================================

static func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


# Internal util functions
# =============================================================================
# These are duplicates of the functions in mod_loader_utils.gd to prevent
# a cyclic reference error.

# This is a dummy func. It is exclusively used to show notes in the code that
# stay visible after decompiling a PCK, as is primarily intended to assist new
# modders in understanding and troubleshooting issues.
static func _code_note(_msg:String):
	pass
