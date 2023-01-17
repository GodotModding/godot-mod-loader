extends Resource
class_name ModData

## Stores and validates all Data required to load a mod successfully
## If some of the data is invalid, [member is_loadable] will be false

const LOG_NAME := "ModLoader:ModData"

## These 2 files are always required by mods.
## [i]mod_main.gd[/i] = The main init file for the mod
## [i]manifest.json[/i] = Meta data for the mod, including its dependencies
enum required_mod_files {
	MOD_MAIN,
	MANIFEST,
}

## Directory of the mod. Has to be identical to [method ModDetails.get_mod_id]
var dir_name := ""
## Path to the Mod's Directory
var dir_path := ""
## False if any data is invalid
var is_loadable := true
## Is increased for every mod depending on this mod. Highest importance is loaded first
var importance := 0
## Contents of the manifest
var details: ModDetails
## Updated in _load_mod_configs
var config := {}

## only set if DEBUG_ENABLE_STORING_FILEPATHS is enabled
var file_paths := []


func _init(_dir_path: String) -> void:
	dir_path = _dir_path


## Load meta data from a mod's manifest.json file
func load_details(modLoader = ModLoader) -> void:
	if not has_required_files():
		return

	modLoader.mod_log("Loading mod_details (manifest.json) for -> %s" % dir_name, LOG_NAME)

	# Load meta data file
	var manifest_path = get_required_mod_file_path(required_mod_files.MANIFEST)
	var manifest_dict = modLoader._get_json_as_dict(manifest_path) # todo get from utils

	modLoader.dev_log("%s loaded manifest data -> %s" % [dir_name, manifest_dict], LOG_NAME)

	var mod_details := ModDetails.new(manifest_dict)

	if not mod_details:
		is_loadable = false
		return

	details = mod_details


## Validates if [member dir_name] matches [method ModDetails.get_mod_id]
func is_mod_dir_name_same_as_id() -> bool:
	var manifest_id = details.get_mod_id()
	if dir_name != manifest_id:
		ModLoader.mod_log('ERROR - Mod directory name "%s" does not match the data in manifest.json. Expected "%s"' % [ dir_name, manifest_id ], LOG_NAME)
		is_loadable = false
		return false
	return true


## Confirms that all files from [member required_mod_files] exist
func has_required_files() -> bool:
	var file_check = File.new()

	for required_file in required_mod_files:
		var file_path = get_required_mod_file_path(required_mod_files[required_file])

		if !file_check.file_exists(file_path):
			ModLoader.mod_log("ERROR - %s is missing a required file: %s" % [dir_name, file_path], LOG_NAME)
			is_loadable = false
	return is_loadable


## Validates if details are set
func has_details() -> bool:
	return not details == null


## Converts enum indices [member required_mod_files] into their respective file paths
func get_required_mod_file_path(required_file: int) -> String:
	match required_file:
		required_mod_files.MOD_MAIN:
			return dir_path.plus_file("mod_main.gd")
		required_mod_files.MANIFEST:
			return dir_path.plus_file("manifest.json")
	return ""


#func _to_string() -> String:
	# todo if we want it pretty printed


