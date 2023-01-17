extends Resource
class_name ModData

# These 2 files are always required by mods.
# mod_main.gd = The main init file for the mod
# manifest.json = Meta data for the mod, including its dependancies
const LOG_NAME := "ModLoader:ModData"

enum required_mod_files {
	MOD_MAIN,
	MANIFEST,
}

var dir_name := "" # technically a duplicate with ModDetails
var dir_path := ""
var is_loadable := true
var importance := 0
var details: ModDetails
var config := {} # updated in _load_mod_configs

# debug
var file_paths := []


func _init(_dir_path: String) -> void:
	dir_path = _dir_path


# Load meta data from a mod's manifest.json file
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


func is_mod_dir_name_same_as_id() -> bool:
	# Check that the mod ID is correct. This will fail if the mod's folder in
	# "res://mods-unpacked" does not match its full ID, which is `namespace.name`
	var manifest_id = details.get_mod_id()
	if dir_name != manifest_id:
		ModLoader.mod_log('ERROR - Mod directory name "%s" does not match the data in manifest.json. Expected "%s"' % [ dir_name, manifest_id ], LOG_NAME)
		is_loadable = false
		return false
	return true


func has_required_files() -> bool:
	var file_check = File.new()

	for required_file in required_mod_files:
		var file_path = get_required_mod_file_path(required_mod_files[required_file])

		if !file_check.file_exists(file_path):
			ModLoader.mod_log("ERROR - %s is missing a required file: %s" % [dir_name, file_path], LOG_NAME)
			is_loadable = false
	return is_loadable


func has_details() -> bool:
	return not details == null


func get_required_mod_file_path(required_file: int) -> String:
	match required_file:
		required_mod_files.MOD_MAIN:
			return dir_path.plus_file("mod_main.gd")
		required_mod_files.MANIFEST:
			return dir_path.plus_file("manifest.json")
	return ""


#func _to_string() -> String:
	# todo if we want it pretty printed


