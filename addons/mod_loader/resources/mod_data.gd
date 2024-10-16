class_name ModData
extends Resource
##
## Stores and validates all Data required to load a mod successfully
## If some of the data is invalid, [member is_loadable] will be false


const LOG_NAME := "ModLoader:ModData"

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

var load_errors: Array[String] = []
var load_warnings: Array[String] = []


func _init(mod_id: String, zip_path := "") -> void:
	# Path to the mod in UNPACKED_DIR (eg "res://mods-unpacked/My-Mod")
	var local_mod_path := _ModLoaderPath.get_unpacked_mods_dir_path().path_join(mod_id)

	if not zip_path.is_empty():
		zip_name = _ModLoaderPath.get_file_name_from_path(zip_path)
		zip_path = zip_path
		source = get_mod_source()
	dir_path = local_mod_path
	dir_name = mod_id

	var mod_overwrites_path := get_optional_mod_file_path(ModData.optional_mod_files.OVERWRITES)
	is_overwrite = _ModLoaderFile.file_exists(mod_overwrites_path)
	is_locked = mod_id in ModLoaderStore.ml_options.locked_mods

	# Get the mod file paths
	# Note: This was needed in the original version of this script, but it's
	# not needed anymore. It can be useful when debugging, but it's also an expensive
	# operation if a mod has a large number of files (eg. Brotato's Invasion mod,
	# which has ~1,000 files). That's why it's disabled by default
	if ModLoaderStore.DEBUG_ENABLE_STORING_FILEPATHS:
		file_paths = _ModLoaderPath.get_flat_view_dict(local_mod_path)


# Load meta data from a mod's manifest.json file
func load_manifest() -> void:
	if not _has_required_files():
		return

	ModLoaderLog.info("Loading mod_manifest (manifest.json) for -> %s" % dir_name, LOG_NAME)

	# Load meta data file
	var manifest_path := get_required_mod_file_path(required_mod_files.MANIFEST)
	var manifest_dict := _ModLoaderFile.get_json_as_dict(manifest_path)

	var mod_manifest := ModManifest.new(manifest_dict)
	manifest = mod_manifest
	validate_manifest_loadability()


func validate_loadability() -> void:
	var is_manifest_loadable := validate_manifest_loadability()
	if not is_manifest_loadable:
		return
	manifest.validate_workshop_id(self)
	validate_game_version_compatibility(ModLoaderGameConstants.semantic_version)

	is_loadable = load_errors.is_empty()


func validate_game_version_compatibility(game_semver: String) -> void:
	var game_major := int(game_semver.get_slice(".", 0))
	var game_minor := int(game_semver.get_slice(".", 1))

	var valid_major := false
	var valid_minor := false
	for version in manifest.compatible_game_version:
		var compat_major := int(version.get_slice(".", 0))
		if compat_major >= game_major:
			valid_major = true
		var compat_minor := int(version.get_slice(".", 1))
		if compat_minor >= game_minor:
			valid_minor = true

	if not valid_major:
		load_errors.append("This mod is incompatible with the current game version.")
	if not valid_minor:
		load_warnings.append("This mod may not be compatible with the current game version. Enable at your own risk.")


func validate_manifest_loadability() -> bool:
	if not _has_manifest(manifest):
		load_errors.append("This mod could not be loaded due to a manifest error. Contact the mod developer.")
		return false

	if not _is_mod_dir_name_same_as_id(manifest):
		load_errors.append("This mod could not be loaded due to a structural error. Contact the mod developer.")
		return false
	return true


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


func set_mod_state(should_activate: bool, force := false) -> bool:
	if is_locked and should_activate != is_active:
		ModLoaderLog.error(
			"Unable to toggle mod \"%s\" since it is marked as locked. Locked mods: %s"
			% [manifest.get_mod_id(), ModLoaderStore.ml_options.locked_mods], LOG_NAME)
		return false

	if should_activate and not is_loadable:
		ModLoaderLog.error(
			"Unable to activate mod \"%s\" since it has the following load errors: %s"
			% [manifest.get_mod_id(), ", ".join(load_errors)], LOG_NAME)
		return false

	if should_activate and load_warnings.size() > 0:
		if not force:
			ModLoaderLog.warning(
				"Rejecting to activate mod \"%s\" since it has the following load warnings: %s"
				% [manifest.get_mod_id(), ", ".join(load_warnings)], LOG_NAME)
			return false
		ModLoaderLog.info(
			"Forced to activate mod \"%s\" despite the following load warnings: %s"
			% [manifest.get_mod_id(), ", ".join(load_warnings)], LOG_NAME)

	is_active = should_activate
	return true


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

		if not _ModLoaderFile.file_exists(file_path):
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
