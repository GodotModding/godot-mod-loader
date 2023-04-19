class_name ModData
extends Resource

# Stores and validates all Data required to load a mod successfully
# If some of the data is invalid, [member is_loadable] will be false

const LOG_NAME := "ModLoader:ModData"

# Controls how manifest.json data is logged for each mod
# true  = Full JSON contents (floods the log)
# false = Single line (default)
const USE_EXTENDED_DEBUGLOG := false

# These 2 files are always required by mods.
# [i]mod_main.gd[/i] = The main init file for the mod
# [i]manifest.json[/i] = Meta data for the mod, including its dependencies
enum required_mod_files {
	MOD_MAIN,
	MANIFEST,
}

enum optional_mod_files {
	OVERWRITES
}

# Directory of the mod. Has to be identical to [method ModManifest.get_mod_id]
var dir_name := ""
# Path to the Mod's Directory
var dir_path := ""
# False if any data is invalid
var is_loadable := true
# True if overwrites.gd exists
var is_overwrite := false
# Is increased for every mod depending on this mod. Highest importance is loaded first
var importance := 0
# Contents of the manifest
var manifest: ModManifest
# Updated in _load_mod_configs
var config := {}

# only set if DEBUG_ENABLE_STORING_FILEPATHS is enabled
var file_paths: PoolStringArray = []


func _init(_dir_path: String) -> void:
	dir_path = _dir_path


# Load meta data from a mod's manifest.json file
func load_manifest() -> void:
	if not has_required_files():
		return

	ModLoaderLog.info("Loading mod_manifest (manifest.json) for -> %s" % dir_name, LOG_NAME)

	# Load meta data file
	var manifest_path := get_required_mod_file_path(required_mod_files.MANIFEST)
	var manifest_dict := ModLoaderFile.get_json_as_dict(manifest_path)

	if USE_EXTENDED_DEBUGLOG:
		ModLoaderLog.debug_json_print("%s loaded manifest data -> " % dir_name, manifest_dict, LOG_NAME)
	else:
		ModLoaderLog.debug(str("%s loaded manifest data -> " % dir_name, manifest_dict), LOG_NAME)

	var mod_manifest := ModManifest.new(manifest_dict)

	is_loadable = has_manifest(mod_manifest)
	if not is_loadable: return
	is_loadable = is_mod_dir_name_same_as_id(mod_manifest)
	if not is_loadable: return
	manifest = mod_manifest


# Validates if [member dir_name] matches [method ModManifest.get_mod_id]
func is_mod_dir_name_same_as_id(mod_manifest: ModManifest) -> bool:
	var manifest_id := mod_manifest.get_mod_id()
	if not dir_name == manifest_id:
		ModLoaderLog.fatal('Mod directory name "%s" does not match the data in manifest.json. Expected "%s" (Format: {namespace}-{name})' % [ dir_name, manifest_id ], LOG_NAME)
		return false
	return true


# Confirms that all files from [member required_mod_files] exist
func has_required_files() -> bool:
	for required_file in required_mod_files:
		var file_path := get_required_mod_file_path(required_mod_files[required_file])

		if !ModLoaderFile.file_exists(file_path):
			ModLoaderLog.fatal("ERROR - %s is missing a required file: %s" % [dir_name, file_path], LOG_NAME)
			is_loadable = false
	return is_loadable


# Validates if manifest is set
func has_manifest(mod_manifest: ModManifest) -> bool:
	if mod_manifest == null:
		ModLoaderLog.fatal("Mod manifest could not be created correctly due to errors.", LOG_NAME)
		return false
	return true


# Converts enum indices [member required_mod_files] into their respective file paths
func get_required_mod_file_path(required_file: int) -> String:
	match required_file:
		required_mod_files.MOD_MAIN:
			return dir_path.plus_file("mod_main.gd")
		required_mod_files.MANIFEST:
			return dir_path.plus_file("manifest.json")
	return ""

func get_optional_mod_file_path(optional_file: int) -> String:
	match optional_file:
		optional_mod_files.OVERWRITES:
			return dir_path.plus_file("overwrites.gd")
	return ""
