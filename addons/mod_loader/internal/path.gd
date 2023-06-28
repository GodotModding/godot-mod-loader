class_name _ModLoaderPath
extends Reference


# This Class provides util functions for working with paths.
# Currently all of the included functions are internal and should only be used by the mod loader itself.

const LOG_NAME := "ModLoader:Path"
const MOD_CONFIG_DIR_PATH := "user://configs"


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


# Returns an array of file paths inside the src dir
static func get_file_paths_in_dir(src_dir_path: String) -> Array:
	var file_paths := []

	var directory := Directory.new()
	var error := directory.open(src_dir_path)

	if not error  == OK:
		ModLoaderLog.error("Encountered an error (%s) when attempting to open a directory, with the path: %s" % [error, src_dir_path], LOG_NAME)
		return file_paths

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while (file_name != ""):
		if not directory.current_is_dir():
			file_paths.push_back(src_dir_path.plus_file(file_name))
		file_name = directory.get_next()

	return file_paths


# Returns an array of directory paths inside the src dir
static func get_dir_paths_in_dir(src_dir_path: String) -> Array:
	var dir_paths := []

	var directory := Directory.new()
	var error := directory.open(src_dir_path)

	if not error == OK:
		ModLoaderLog.error("Encountered an error (%s) when attempting to open a directory, with the path: %s" % [error, src_dir_path], LOG_NAME)
		return dir_paths

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while (file_name != ""):
		if file_name == "." or file_name == "..":
			file_name = directory.get_next()
			continue
		if directory.current_is_dir():
			dir_paths.push_back(src_dir_path.plus_file(file_name))
		file_name = directory.get_next()

	return dir_paths


# Get the path to the mods folder, with any applicable overrides applied
static func get_path_to_mods() -> String:
	var mods_folder_path := get_local_folder_dir("mods")
	if ModLoaderStore:
		if ModLoaderStore.ml_options.override_path_to_mods:
			mods_folder_path = ModLoaderStore.ml_options.override_path_to_mods
	return mods_folder_path


static func get_unpacked_mods_dir_path() -> String:
	return ModLoaderStore.UNPACKED_DIR


# Get the path to the configs folder, with any applicable overrides applied
static func get_path_to_configs() -> String:
	var configs_path := MOD_CONFIG_DIR_PATH
	if ModLoaderStore:
		if ModLoaderStore.ml_options.override_path_to_configs:
			configs_path = ModLoaderStore.ml_options.override_path_to_configs
	return configs_path


# Get the path to a mods config folder
static func get_path_to_mod_configs_dir(mod_id: String) -> String:
	return get_path_to_configs().plus_file(mod_id)


# Get the path to a mods config file
static func get_path_to_mod_config_file(mod_id: String, config_name: String) -> String:
	var mod_config_dir := get_path_to_mod_configs_dir(mod_id)

	return mod_config_dir.plus_file( config_name + ".json")
