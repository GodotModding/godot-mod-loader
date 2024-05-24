class_name ModData
extends Resource
##
## Stores and validates all Data required to load a mod successfully
## If some of the data is invalid, [member is_loadable] will be false


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

# Specifies the source from which the mod has been loaded:
# UNPACKED = From the mods-unpacked directory ( only when in the editor ).
# LOCAL = From the local mod zip directory, which by default is ../game_dir/mods.
# STEAM_WORKSHOP = Loaded from ../Steam/steamapps/workshop/content/1234567/[..].
enum sources {
	UNPACKED,
	LOCAL,
	STEAM_WORKSHOP,
}

## Name of the Mod's zip file
var zip_name := ""
## Path to the Mod's zip file
var zip_path := ""

## Directory of the mod. Has to be identical to [method ModManifest.get_mod_id]
var dir_name := ""
## Path to the Mod's Directory
var dir_path := ""
## False if any data is invalid
var is_loadable := true
## True if overwrites.gd exists
var is_overwrite := false
## True if mod can't be disabled or enabled in a user profile
var is_locked := false
## Flag indicating whether the mod should be loaded
var is_active := true
## Is increased for every mod depending on this mod. Highest importance is loaded first
var importance := 0
## Contents of the manifest
var manifest: ModManifest
# Updated in load_configs
## All mod configs
var configs := {}
## The currently applied mod config
var current_config: ModConfig: set = _set_current_config
## Specifies the source from which the mod has been loaded
var source: int

# only set if DEBUG_ENABLE_STORING_FILEPATHS is enabled
var file_paths: PackedStringArray = []


# Load meta data from a mod's manifest.json file
func load_manifest() -> void:
	if not _has_required_files():
		return

	ModLoaderLog.info("Loading mod_manifest (manifest.json) for -> %s" % dir_name, LOG_NAME)

	# Load meta data file
	var manifest_path := get_required_mod_file_path(required_mod_files.MANIFEST)
	var manifest_dict := _ModLoaderFile.get_json_as_dict(manifest_path)

	if USE_EXTENDED_DEBUGLOG:
		ModLoaderLog.debug_json_print("%s loaded manifest data -> " % dir_name, manifest_dict, LOG_NAME)
	else:
		ModLoaderLog.debug(str("%s loaded manifest data -> " % dir_name, manifest_dict), LOG_NAME)

	var mod_manifest := ModManifest.new(manifest_dict)

	is_loadable = _has_manifest(mod_manifest)
	if not is_loadable:
		return
	is_loadable = _is_mod_dir_name_same_as_id(mod_manifest)
	if not is_loadable:
		return
	manifest = mod_manifest


# Load each mod config json from the mods config directory.
func load_configs() -> void:
	# If the default values in the config schema are invalid don't load configs
	if not manifest.load_mod_config_defaults():
		return

	var config_dir_path := _ModLoaderPath.get_path_to_mod_configs_dir(dir_name)
	var config_file_paths := _ModLoaderPath.get_file_paths_in_dir(config_dir_path)
	for config_file_path in config_file_paths:
		_load_config(config_file_path)

	# Set the current_config based on the user profile
	current_config = ModLoaderConfig.get_current_config(dir_name)


# Create a new ModConfig instance for each Config JSON and add it to the configs dictionary.
func _load_config(config_file_path: String) -> void:
	var config_data := _ModLoaderFile.get_json_as_dict(config_file_path)
	var mod_config = ModConfig.new(
		dir_name,
		config_data,
		config_file_path,
		manifest.config_schema
	)

	# Add the config to the configs dictionary
	configs[mod_config.name] = mod_config


# Update the mod_list of the current user profile
func _set_current_config(new_current_config: ModConfig) -> void:
	ModLoaderUserProfile.set_mod_current_config(dir_name, new_current_config)
	current_config = new_current_config
	# We can't emit the signal if the ModLoader is not initialized yet
	if ModLoader:
		ModLoader.current_config_changed.emit(new_current_config)


# Validates if [member dir_name] matches [method ModManifest.get_mod_id]
func _is_mod_dir_name_same_as_id(mod_manifest: ModManifest) -> bool:
	var manifest_id := mod_manifest.get_mod_id()
	if not dir_name == manifest_id:
		ModLoaderLog.fatal('Mod directory name "%s" does not match the data in manifest.json. Expected "%s" (Format: {namespace}-{name})' % [ dir_name, manifest_id ], LOG_NAME)
		return false
	return true


# Confirms that all files from [member required_mod_files] exist
func _has_required_files() -> bool:
	for required_file in required_mod_files:
		var file_path := get_required_mod_file_path(required_mod_files[required_file])

		if !_ModLoaderFile.file_exists(file_path):
			ModLoaderLog.fatal("ERROR - %s is missing a required file: %s" % [dir_name, file_path], LOG_NAME)
			is_loadable = false
	return is_loadable


# Validates if manifest is set
func _has_manifest(mod_manifest: ModManifest) -> bool:
	if mod_manifest == null:
		ModLoaderLog.fatal("Mod manifest could not be created correctly due to errors.", LOG_NAME)
		return false
	return true


# Converts enum indices [member required_mod_files] into their respective file paths
func get_required_mod_file_path(required_file: int) -> String:
	match required_file:
		required_mod_files.MOD_MAIN:
			return dir_path.path_join("mod_main.gd")
		required_mod_files.MANIFEST:
			return dir_path.path_join("manifest.json")
	return ""


func get_optional_mod_file_path(optional_file: int) -> String:
	match optional_file:
		optional_mod_files.OVERWRITES:
			return dir_path.path_join("overwrites.gd")
	return ""


func get_mod_source() -> sources:
	if zip_path.contains("workshop"):
		return sources.STEAM_WORKSHOP
	if zip_path == "":
		return sources.UNPACKED

	return sources.LOCAL
