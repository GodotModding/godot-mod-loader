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

## Directory of the mod. Has to be identical to [method ModManifest.get_mod_id]
var dir_name := ""
## Path to the Mod's Directory
var dir_path := ""
## False if any data is invalid
var is_loadable := true
## Is increased for every mod depending on this mod. Highest importance is loaded first
var importance := 0
## Contents of the manifest
var manifest: ModManifest
## Updated in _load_mod_configs
var config := {}

## only set if DEBUG_ENABLE_STORING_FILEPATHS is enabled
var file_paths := []


func _init(_dir_path: String) -> void:
	dir_path = _dir_path


## Load meta data from a mod's manifest.json file
func load_manifest() -> void:
	if not has_required_files():
		return

#	ModLoader.mod_log("Loading mod_manifest (manifest.json) for -> %s" % dir_name, LOG_NAME)

	# Load meta data file
	var manifest_path = get_required_mod_file_path(required_mod_files.MANIFEST)
	var manifest_dict = _get_json_as_dict(manifest_path) # todo get from utils

#	ModLoader.mod_log("%s loaded manifest data -> %s" % [dir_name, manifest_dict], LOG_NAME)

	var mod_manifest := ModManifest.new(manifest_dict)

	if not mod_manifest:
		is_loadable = false
		return

	manifest = mod_manifest


## Validates if [member dir_name] matches [method ModManifest.get_mod_id]
func is_mod_dir_name_same_as_id() -> bool:
	var manifest_id = manifest.get_mod_id()
	if dir_name != manifest_id:
#		ModLoader.mod_log('ERROR - Mod directory name "%s" does not match the data in manifest.json. Expected "%s"' % [ dir_name, manifest_id ], LOG_NAME)
		is_loadable = false
		return false
	return true


## Confirms that all files from [member required_mod_files] exist
func has_required_files() -> bool:
	var file_check = File.new()

	for required_file in required_mod_files:
		var file_path = get_required_mod_file_path(required_mod_files[required_file])

		if !file_check.file_exists(file_path):
#			ModLoader.mod_log("ERROR - %s is missing a required file: %s" % [dir_name, file_path], LOG_NAME)
			is_loadable = false
	return is_loadable


## Validates if manifest is set
func has_manifest() -> bool:
	return not manifest == null


## Converts enum indices [member required_mod_files] into their respective file paths
func get_required_mod_file_path(required_file: int) -> String:
	match required_file:
		required_mod_files.MOD_MAIN:
			return dir_path.plus_file("mod_main.gd")
		required_mod_files.MANIFEST:
			return dir_path.plus_file("manifest.json")
	return ""


## Parses JSON from a given file path and returns a dictionary.
## Returns an empty dictionary if no file exists (check with size() < 1)
static func _get_json_as_dict(path:String) -> Dictionary: # todo move to utils
	var file = File.new()

	if !file.file_exists(path):
		file.close()
		return {}

	file.open(path, File.READ)
	var content = file.get_as_text()

	var parsed := JSON.parse(content)
	if parsed.error:
		# log error
		return {}
	return parsed.result


#func _to_string() -> String:
	# todo if we want it pretty printed


