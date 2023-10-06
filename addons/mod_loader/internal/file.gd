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
	if !file_exists(path):
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


# Load the mod ZIP from the provided directory
static func load_zips_in_folder(folder_path: String) -> Dictionary:
	var URL_MOD_STRUCTURE_DOCS := "https://github.com/GodotModding/godot-mod-loader/wiki/Mod-Structure"
	var zip_data := {}

	var mod_dir := DirAccess.open(folder_path)
	if mod_dir == null:
		ModLoaderLog.error("Can't open mod folder %s" % [folder_path], LOG_NAME)
		return {}

	var mod_dir_open_error := mod_dir.get_open_error()
	if not mod_dir_open_error == OK:
		ModLoaderLog.info("Can't open mod folder %s (Error: %s)" % [folder_path, mod_dir_open_error], LOG_NAME)
		return {}
	var mod_dir_listdir_error := mod_dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	if not mod_dir_listdir_error == OK:
		ModLoaderLog.error("Can't read mod folder %s (Error: %s)" % [folder_path, mod_dir_listdir_error], LOG_NAME)
		return {}

	# Get all zip folders inside the game mod folder
	while true:
		# Get the next file in the directory
		var mod_zip_file_name := mod_dir.get_next()

		# If there is no more file
		if mod_zip_file_name == "":
			# Stop loading mod zip files
			break

		# Ignore files that aren't ZIP or PCK
		if not mod_zip_file_name.get_extension() == "zip" and not mod_zip_file_name.get_extension() == "pck":
			continue

		# If the current file is a directory
		if mod_dir.current_is_dir():
			# Go to the next file
			continue

		var mod_zip_path := folder_path.path_join(mod_zip_file_name)
		var mod_zip_global_path := ProjectSettings.globalize_path(mod_zip_path)
		var is_mod_loaded_successfully := ProjectSettings.load_resource_pack(mod_zip_global_path, false)

		# Get the current directories inside UNPACKED_DIR
		# This array is used to determine which directory is new
		var current_mod_dirs := _ModLoaderPath.get_dir_paths_in_dir(_ModLoaderPath.get_unpacked_mods_dir_path())

		# Create a backup to reference when the next mod is loaded
		var current_mod_dirs_backup := current_mod_dirs.duplicate()

		# Remove all directory paths that existed before, leaving only the one added last
		for previous_mod_dir in ModLoaderStore.previous_mod_dirs:
			current_mod_dirs.erase(previous_mod_dir)

		# If the mod zip is not structured correctly, it may not be in the UNPACKED_DIR.
		if current_mod_dirs.is_empty():
			ModLoaderLog.fatal(
				"The mod zip at path \"%s\" does not have the correct file structure. For more information, please visit \"%s\"."
				% [mod_zip_global_path, URL_MOD_STRUCTURE_DOCS],
				LOG_NAME
			)
			continue

		# The key is the mod_id of the latest loaded mod, and the value is the path to the zip file
		zip_data[current_mod_dirs[0].get_slice("/", 3)] = mod_zip_global_path

		# Update previous_mod_dirs in ModLoaderStore to use for the next mod
		ModLoaderStore.previous_mod_dirs = current_mod_dirs_backup

		# Notifies developer of an issue with Godot, where using `load_resource_pack`
		# in the editor WIPES the entire virtual res:// directory the first time you
		# use it. This means that unpacked mods are no longer accessible, because they
		# no longer exist in the file system. So this warning basically says
		# "don't use ZIPs with unpacked mods!"
		# https://github.com/godotengine/godot/issues/19815
		# https://github.com/godotengine/godot/issues/16798
		if OS.has_feature("editor") and not ModLoaderStore.has_shown_editor_zips_warning:
			ModLoaderLog.warning(str(
				"Loading any resource packs (.zip/.pck) with `load_resource_pack` will WIPE the entire virtual res:// directory. ",
				"If you have any unpacked mods in ", _ModLoaderPath.get_unpacked_mods_dir_path(), ", they will not be loaded. ",
				"Please unpack your mod ZIPs instead, and add them to ", _ModLoaderPath.get_unpacked_mods_dir_path()), LOG_NAME)
			ModLoaderStore.has_shown_editor_zips_warning = true

		ModLoaderLog.debug("Found mod ZIP: %s" % mod_zip_global_path, LOG_NAME)

		# If there was an error loading the mod zip file
		if not is_mod_loaded_successfully:
			# Log the error and continue with the next file
			ModLoaderLog.error("%s failed to load." % mod_zip_file_name, LOG_NAME)
			continue

		# Mod successfully loaded!
		ModLoaderLog.success("%s loaded." % mod_zip_file_name, LOG_NAME)

	mod_dir.list_dir_end()

	return zip_data


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
# This are duplicates of the functions in mod_loader_utils.gd to prevent
# a cyclic reference error.

# This is a dummy func. It is exclusively used to show notes in the code that
# stay visible after decompiling a PCK, as is primarily intended to assist new
# modders in understanding and troubleshooting issues.
static func _code_note(_msg:String):
	pass

