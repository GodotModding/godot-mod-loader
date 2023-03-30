# ModLoader - A mod loader for GDScript
#
# Written in 2021 by harrygiel <harrygiel@gmail.com>,
# in 2021 by Mariusz Chwalba <mariusz@chwalba.net>,
# in 2022 by Vladimir Panteleev <git@cy.md>,
# in 2023 by KANA <kai@kana.jetzt>,
# in 2023 by Darkly77,
# in 2023 by otDan <otdanofficial@gmail.com>,
# in 2023 by Qubus0/Ste
#
# To the extent possible under law, the author(s) have
# dedicated all copyright and related and neighboring
# rights to this software to the public domain worldwide.
# This software is distributed without any warranty.
#
# You should have received a copy of the CC0 Public
# Domain Dedication along with this software. If not, see
# <http://creativecommons.org/publicdomain/zero/1.0/>.

extends Node


# Config
# =============================================================================

# Most of these settings should never need to change, aside from the DEBUG_*
# options (which should be `false` when distributing compiled PCKs)

const MODLOADER_VERSION = "5.0.1"

# If true, a complete array of filepaths is stored for each mod. This is
# disabled by default because the operation can be very expensive, but may
# be useful for debugging
const DEBUG_ENABLE_STORING_FILEPATHS := false

# Path to the mod log file
# Find this log here: %appdata%/GAMENAME/mods.log
const MOD_LOG_PATH := "user://mods.log"

# This is where mod ZIPs are unpacked to
const UNPACKED_DIR := "res://mods-unpacked/"


# Set to true to require using "--enable-mods" to enable them
const REQUIRE_CMD_LINE := false

# Prefix for this file when using mod_log or dev_log
const LOG_NAME := "ModLoader"


# Vars
# =============================================================================

# Stores data for every found/loaded mod
var mod_data := {}

# Order for mods to be loaded in, set by `_get_load_order`
var mod_load_order := []

# Any mods that are missing their dependancies are added to this
# Example property: "mod_id": ["dep_mod_id_0", "dep_mod_id_2"]
var mod_missing_dependencies := {}

# Things to keep to ensure they are not garbage collected (used by `save_scene`)
var _saved_objects := []

# Store all extenders paths
var script_extensions := []

# Store vanilla classes for script extension sorting
var loaded_vanilla_parents_cache := {}

# Set to false after _init()
# Helps to decide whether a script extension should go through the _handle_script_extensions process
var is_initializing := true

# Stores all the taken over scripts for restoration
var _saved_scripts := {}

# Main
# =============================================================================

func _init() -> void:
	# if mods are not enabled - don't load mods
	if REQUIRE_CMD_LINE and not ModLoaderUtils.is_running_with_command_line_arg("--enable-mods"):
		return

	# Rotate the log files once on startup. Can't be checked in utils, since it's static
	ModLoaderUtils.rotate_log_file()

	# Ensure ModLoaderStore and ModLoader are the 1st and 2nd autoloads
	_check_autoload_positions()

	# Log the autoloads order. Helpful when providing support to players
	ModLoaderUtils.log_debug_json_print("Autoload order", ModLoaderUtils.get_autoload_array(), LOG_NAME)

	# Log game install dir
	ModLoaderUtils.log_info("game_install_directory: %s" % ModLoaderUtils.get_local_folder_dir(), LOG_NAME)

	if not ModLoaderStore.ml_options.enable_mods:
		ModLoaderUtils.log_info("Mods are currently disabled", LOG_NAME)
		return

	# Loop over "res://mods" and add any mod zips to the unpacked virtual
	# directory (UNPACKED_DIR)
	var unzipped_mods := _load_mod_zips()
	if unzipped_mods > 0:
		ModLoaderUtils.log_success("DONE: Loaded %s mod files into the virtual filesystem" % unzipped_mods, LOG_NAME)
	else:
		ModLoaderUtils.log_info("No zipped mods found", LOG_NAME)

	# Loop over UNPACKED_DIR. This triggers _init_mod_data for each mod
	# directory, which adds their data to mod_data.
	var setup_mods := _setup_mods()
	if setup_mods > 0:
		ModLoaderUtils.log_success("DONE: Setup %s mods" % setup_mods, LOG_NAME)
	else:
		ModLoaderUtils.log_info("No mods were setup", LOG_NAME)

	# Set up mod configs. If a mod's JSON file is found, its data gets added
	# to mod_data.{dir_name}.config
	_load_mod_configs()

	# Loop over all loaded mods via their entry in mod_data. Verify that they
	# have all the required files (REQUIRED_MOD_FILES), load their meta data
	# (from their manifest.json file), and verify that the meta JSON has all
	# required properties (REQUIRED_META_TAGS)
	for dir_name in mod_data:
		var mod: ModData = mod_data[dir_name]
		mod.load_manifest()

	ModLoaderUtils.log_success("DONE: Loaded all meta data", LOG_NAME)


	# Check for mods with load_before. If a mod is listed in load_before,
	# add the current mod to the dependencies of the the mod specified
	# in load_before.
	for dir_name in mod_data:
		var mod: ModData = mod_data[dir_name]
		if not mod.is_loadable:
			continue
		_check_load_before(mod)


	# Run optional dependency checks after loading mod_manifest.
	# If a mod depends on another mod that hasn't been loaded,
	# that dependent mod will be loaded regardless.
	for dir_name in mod_data:
		var mod: ModData = mod_data[dir_name]
		if not mod.is_loadable:
			continue
		var _is_circular := _check_dependencies(mod, false)


	# Run dependency checks after loading mod_manifest. If a mod depends on another
	# mod that hasn't been loaded, that dependent mod won't be loaded.
	for dir_name in mod_data:
		var mod: ModData = mod_data[dir_name]
		if not mod.is_loadable:
			continue
		var _is_circular := _check_dependencies(mod)

	# Sort mod_load_order by the importance score of the mod
	mod_load_order = _get_load_order(mod_data.values())

	# Log mod order
	var mod_i := 1
	for mod in mod_load_order: # mod === mod_data
		mod = mod as ModData
		ModLoaderUtils.log_info("mod_load_order -> %s) %s" % [mod_i, mod.dir_name], LOG_NAME)
		mod_i += 1

	# Instance every mod and add it as a node to the Mod Loader
	for mod in mod_load_order:
		mod = mod as ModData
		ModLoaderUtils.log_info("Initializing -> %s" % mod.manifest.get_mod_id(), LOG_NAME)
		_init_mod(mod)

	ModLoaderUtils.log_debug_json_print("mod data", mod_data, LOG_NAME)

	ModLoaderUtils.log_success("DONE: Completely finished loading mods", LOG_NAME)

	_handle_script_extensions()

	ModLoaderUtils.log_success("DONE: Installed all script extensions", LOG_NAME)

	is_initializing = false


# Check autoload positions:
# Ensure 1st autoload is `ModLoaderStore`, and 2nd is `ModLoader`.
func _check_autoload_positions() -> void:
	# If the override file exists we assume the ModLoader was setup with the --setup-create-override-cfg cli arg
	# In that case the ModLoader will be the last entry in the autoload array
	var override_cfg_path := ModLoaderUtils.get_override_path()
	var is_override_cfg_setup :=  ModLoaderUtils.file_exists(override_cfg_path)
	if is_override_cfg_setup:
		ModLoaderUtils.log_info("override.cfg setup detected, ModLoader will be the last autoload loaded.", LOG_NAME)
		return

	var _pos_ml_store := ModLoaderGodot.check_autoload_position("ModLoaderStore", 0, true)
	var _pos_ml_core := ModLoaderGodot.check_autoload_position("ModLoader", 1, true)


# Loop over "res://mods" and add any mod zips to the unpacked virtual directory
# (UNPACKED_DIR)
func _load_mod_zips() -> int:
	var zipped_mods_count := 0

	if not ModLoaderStore.ml_options.steam_workshop_enabled:
		var mods_folder_path := ModLoaderUtils.get_path_to_mods()

		# If we're not using Steam workshop, just loop over the mod ZIPs.
		zipped_mods_count += _load_zips_in_folder(mods_folder_path)
	else:
		# If we're using Steam workshop, loop over the workshop item directories
		zipped_mods_count += _load_steam_workshop_zips()

	return zipped_mods_count


# Load the mod ZIP from the provided directory
func _load_zips_in_folder(folder_path: String) -> int:
	var temp_zipped_mods_count := 0

	var mod_dir := Directory.new()
	var mod_dir_open_error := mod_dir.open(folder_path)
	if not mod_dir_open_error == OK:
		ModLoaderUtils.log_error("Can't open mod folder %s (Error: %s)" % [folder_path, mod_dir_open_error], LOG_NAME)
		return -1
	var mod_dir_listdir_error := mod_dir.list_dir_begin()
	if not mod_dir_listdir_error == OK:
		ModLoaderUtils.log_error("Can't read mod folder %s (Error: %s)" % [folder_path, mod_dir_listdir_error], LOG_NAME)
		return -1

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

		var mod_folder_path := folder_path.plus_file(mod_zip_file_name)
		var mod_folder_global_path := ProjectSettings.globalize_path(mod_folder_path)
		var is_mod_loaded_successfully := ProjectSettings.load_resource_pack(mod_folder_global_path, false)

		# Notifies developer of an issue with Godot, where using `load_resource_pack`
		# in the editor WIPES the entire virtual res:// directory the first time you
		# use it. This means that unpacked mods are no longer accessible, because they
		# no longer exist in the file system. So this warning basically says
		# "don't use ZIPs with unpacked mods!"
		# https://github.com/godotengine/godot/issues/19815
		# https://github.com/godotengine/godot/issues/16798
		if OS.has_feature("editor") and not ModLoaderStore.has_shown_editor_zips_warning:
			ModLoaderUtils.log_warning(str(
				"Loading any resource packs (.zip/.pck) with `load_resource_pack` will WIPE the entire virtual res:// directory. ",
				"If you have any unpacked mods in ", UNPACKED_DIR, ", they will not be loaded. ",
				"Please unpack your mod ZIPs instead, and add them to ", UNPACKED_DIR), LOG_NAME)
			ModLoaderStore.has_shown_editor_zips_warning = true

		ModLoaderUtils.log_debug("Found mod ZIP: %s" % mod_folder_global_path, LOG_NAME)

		# If there was an error loading the mod zip file
		if not is_mod_loaded_successfully:
			# Log the error and continue with the next file
			ModLoaderUtils.log_error("%s failed to load." % mod_zip_file_name, LOG_NAME)
			continue

		# Mod successfully loaded!
		ModLoaderUtils.log_success("%s loaded." % mod_zip_file_name, LOG_NAME)
		temp_zipped_mods_count += 1

	mod_dir.list_dir_end()

	return temp_zipped_mods_count


# Load mod ZIPs from Steam workshop folders. Uses 2 loops: One for each
# workshop item's folder, with another inside that which loops over the ZIPs
# inside each workshop item's folder
func _load_steam_workshop_zips() -> int:
	var temp_zipped_mods_count := 0
	var workshop_folder_path := ModLoaderSteam.get_path_to_workshop()

	ModLoaderUtils.log_info("Checking workshop items, with path: \"%s\"" % workshop_folder_path, LOG_NAME)

	var workshop_dir := Directory.new()
	var workshop_dir_open_error := workshop_dir.open(workshop_folder_path)
	if not workshop_dir_open_error == OK:
		ModLoaderUtils.log_error("Can't open workshop folder %s (Error: %s)" % [workshop_folder_path, workshop_dir_open_error], LOG_NAME)
		return -1
	var workshop_dir_listdir_error := workshop_dir.list_dir_begin()
	if not workshop_dir_listdir_error == OK:
		ModLoaderUtils.log_error("Can't read workshop folder %s (Error: %s)" % [workshop_folder_path, workshop_dir_listdir_error], LOG_NAME)
		return -1

	# Loop 1: Workshop folders
	while true:
		# Get the next workshop item folder
		var item_dir := workshop_dir.get_next()
		var item_path := workshop_dir.get_current_dir() + "/" + item_dir

		ModLoaderUtils.log_info("Checking workshop item path: \"%s\"" % item_path, LOG_NAME)

		# Stop loading mods when there's no more folders
		if item_dir == '':
			break

		# Only check directories
		if not workshop_dir.current_is_dir():
			continue

		# Loop 2: ZIPs inside the workshop folders
		temp_zipped_mods_count += _load_zips_in_folder(ProjectSettings.globalize_path(item_path))

	workshop_dir.list_dir_end()

	return temp_zipped_mods_count


# Loop over UNPACKED_DIR and triggers `_init_mod_data` for each mod directory,
# which adds their data to mod_data.
func _setup_mods() -> int:
	# Path to the unpacked mods folder
	var unpacked_mods_path := UNPACKED_DIR

	var dir := Directory.new()
	if not dir.open(unpacked_mods_path) == OK:
		ModLoaderUtils.log_error("Can't open unpacked mods folder %s." % unpacked_mods_path, LOG_NAME)
		return -1
	if not dir.list_dir_begin() == OK:
		ModLoaderUtils.log_error("Can't read unpacked mods folder %s." % unpacked_mods_path, LOG_NAME)
		return -1

	var unpacked_mods_count := 0
	# Get all unpacked mod dirs
	while true:
		# Get the next file in the directory
		var mod_dir_name := dir.get_next()

		# If there is no more file
		if mod_dir_name == "":
			# Stop loading mod zip files
			break

		# Only check directories
		if not dir.current_is_dir():
			continue

		if mod_dir_name == "." or mod_dir_name == "..":
			continue

		if ModLoaderStore.ml_options.disabled_mods.has(mod_dir_name):
			ModLoaderUtils.log_info("Skipped setting up mod: \"%s\"" % mod_dir_name, LOG_NAME)
			continue

		# Init the mod data
		_init_mod_data(mod_dir_name)
		unpacked_mods_count += 1

	dir.list_dir_end()
	return unpacked_mods_count


# Load mod config JSONs from res://configs
func _load_mod_configs() -> void:
	var found_configs_count := 0
	var configs_path := ModLoaderUtils.get_path_to_configs()

	for dir_name in mod_data:
		var json_path := configs_path.plus_file(dir_name + ".json")
		var mod_config := ModLoaderUtils.get_json_as_dict(json_path)

		ModLoaderUtils.log_debug("Config JSON: Looking for config at path: %s" % json_path, LOG_NAME)

		if mod_config.size() > 0:
			found_configs_count += 1

			ModLoaderUtils.log_info("Config JSON: Found a config file: '%s'" % json_path, LOG_NAME)
			ModLoaderUtils.log_debug_json_print("Config JSON: File data: ", mod_config, LOG_NAME)

			# Check `load_from` option. This lets you specify the name of a
			# different JSON file to load your config from. Must be in the same
			# dir. Means you can have multiple config files for a single mod
			# and switch between them quickly. Should include ".json" extension.
			# Ignored if the filename matches the mod ID, or is empty
			if mod_config.has("load_from"):
				var new_path: String = mod_config.load_from
				if not new_path == "" and not new_path == str(dir_name, ".json"):
					ModLoaderUtils.log_info("Config JSON: Following load_from path: %s" % new_path, LOG_NAME)
					var new_config := ModLoaderUtils.get_json_as_dict(configs_path + new_path)
					if new_config.size() > 0:
						mod_config = new_config
						ModLoaderUtils.log_info("Config JSON: Loaded from custom json: %s" % new_path, LOG_NAME)
						ModLoaderUtils.log_debug_json_print("Config JSON: File data:", mod_config, LOG_NAME)
					else:
						ModLoaderUtils.log_error("Config JSON: ERROR - Could not load data via `load_from` for %s, at path: %s" % [dir_name, new_path], LOG_NAME)

			mod_data[dir_name].config = mod_config

	if found_configs_count > 0:
		ModLoaderUtils.log_success("Config JSON: Loaded %s config(s)" % found_configs_count, LOG_NAME)
	else:
		ModLoaderUtils.log_info("Config JSON: No mod configs were found", LOG_NAME)


# Add a mod's data to mod_data.
# The mod_folder_path is just the folder name that was added to UNPACKED_DIR,
# which depends on the name used in a given mod ZIP (eg "mods-unpacked/Folder-Name")
func _init_mod_data(mod_folder_path: String) -> void:
	# The file name should be a valid mod id
	var dir_name := ModLoaderUtils.get_file_name_from_path(mod_folder_path, false, true)

	# Path to the mod in UNPACKED_DIR (eg "res://mods-unpacked/My-Mod")
	var local_mod_path := UNPACKED_DIR.plus_file(dir_name)

	var mod := ModData.new(local_mod_path)
	mod.dir_name = dir_name
	var mod_overwrites_path := mod.get_optional_mod_file_path(ModData.optional_mod_files.OVERWRITES)
	mod.is_overwrite = ModLoaderUtils.file_exists(mod_overwrites_path)
	mod_data[dir_name] = mod

	# Get the mod file paths
	# Note: This was needed in the original version of this script, but it's
	# not needed anymore. It can be useful when debugging, but it's also an expensive
	# operation if a mod has a large number of files (eg. Brotato's Invasion mod,
	# which has ~1,000 files). That's why it's disabled by default
	if DEBUG_ENABLE_STORING_FILEPATHS:
		mod.file_paths = ModLoaderUtils.get_flat_view_dict(local_mod_path)


# Run dependency checks on a mod, checking any dependencies it lists in its
# mod_manifest (ie. its manifest.json file). If a mod depends on another mod that
# hasn't been loaded, the dependent mod won't be loaded, if it is a required dependency.
#
# Parameters:
# - mod: A ModData object representing the mod being checked.
# - dependency_chain: An array that stores the IDs of the mods that have already
#   been checked to avoid circular dependencies.
# - is_required: A boolean indicating whether the mod is a required or optional
#   dependency. Optional dependencies will not prevent the dependent mod from
#   loading if they are missing.
#
# Returns: A boolean indicating whether a circular dependency was detected.
func _check_dependencies(mod: ModData, is_required := true, dependency_chain := []) -> bool:
	var dependency_type := "required" if is_required else "optional"
	# Get the dependency array based on the is_required flag
	var dependencies := mod.manifest.dependencies if is_required else mod.manifest.optional_dependencies
	# Get the ID of the mod being checked
	var mod_id := mod.dir_name

	ModLoaderUtils.log_debug("Checking dependencies - mod_id: %s %s dependencies: %s" % [mod_id, dependency_type, dependencies], LOG_NAME)

	# Check for circular dependency
	if mod_id in dependency_chain:
		ModLoaderUtils.log_debug("%s dependency check - circular dependency detected for mod with ID %s." % [dependency_type.capitalize(), mod_id], LOG_NAME)
		return true

	# Add mod_id to dependency_chain to avoid circular dependencies
	dependency_chain.append(mod_id)

	# Loop through each dependency listed in the mod's manifest
	for dependency_id in dependencies:
		# Check if dependency is missing
		if not mod_data.has(dependency_id):
			# Skip to the next dependency if it's optional
			if not is_required:
				ModLoaderUtils.log_info("Missing optional dependency - mod: -> %s dependency -> %s" % [mod_id, dependency_id], LOG_NAME)
				continue
			_handle_missing_dependency(mod_id, dependency_id)
			# Flag the mod so it's not loaded later
			mod.is_loadable = false
		else:
			var dependency: ModData = mod_data[dependency_id]

			# Increase the importance score of the dependency by 1
			dependency.importance += 1
			ModLoaderUtils.log_debug("%s dependency -> %s importance -> %s" % [dependency_type.capitalize(), dependency_id, dependency.importance], LOG_NAME)

			# Check if the dependency has any dependencies of its own
			if dependency.manifest.dependencies.size() > 0:
				if _check_dependencies(dependency, is_required, dependency_chain):
					return true

	# Return false if all dependencies have been resolved
	return false


# Handles a missing dependency for a given mod ID. Logs an error message indicating the missing dependency and adds
# the dependency ID to the mod_missing_dependencies dictionary for the specified mod.
func _handle_missing_dependency(mod_id: String, dependency_id: String) -> void:
	ModLoaderUtils.log_error("Missing dependency - mod: -> %s dependency -> %s" % [mod_id, dependency_id], LOG_NAME)
	# if mod is not present in the missing dependencies array
	if not mod_missing_dependencies.has(mod_id):
		# add it
		mod_missing_dependencies[mod_id] = []

	mod_missing_dependencies[mod_id].append(dependency_id)


# Run load before check on a mod, checking any load_before entries it lists in its
# mod_manifest (ie. its manifest.json file). Add the mod to the dependency of the
# mods inside the load_before array.
func _check_load_before(mod: ModData) -> void:
	# Skip if no entries in load_before
	if mod.manifest.load_before.size() == 0:
		return

	ModLoaderUtils.log_debug("Load before - In mod %s detected." % mod.dir_name, LOG_NAME)

	# For each mod id in load_before
	for load_before_id in mod.manifest.load_before:

		# Check if the load_before mod exists
		if not mod_data.has(load_before_id):
			ModLoaderUtils.log_debug("Load before - Skipping %s because it's missing" % load_before_id, LOG_NAME)
			continue

		var load_before_mod_dependencies := mod_data[load_before_id].manifest.dependencies as PoolStringArray

		# Check if it's already a dependency
		if mod.dir_name in load_before_mod_dependencies:
			ModLoaderUtils.log_debug("Load before - Skipping because it's already a dependency for %s" % load_before_id, LOG_NAME)
			continue

		# Add the mod to the dependency array
		load_before_mod_dependencies.append(mod.dir_name)
		mod_data[load_before_id].manifest.dependencies = load_before_mod_dependencies

		ModLoaderUtils.log_debug("Load before - Added %s as dependency for %s" % [mod.dir_name, load_before_id], LOG_NAME)


# Get the load order of mods, using a custom sorter
func _get_load_order(mod_data_array: Array) -> Array:

	# Add loadable mods to the mod load order array
	for mod in mod_data_array:
		mod = mod as ModData
		if mod.is_loadable:
			mod_load_order.append(mod)

	# Sort mods by the importance value
	mod_load_order.sort_custom(self, "_compare_importance")
	return  mod_load_order


# Custom sorter that orders mods by important
func _compare_importance(a: ModData, b: ModData) -> bool:
	if a.importance > b.importance:
		return true # a -> b
	else:
		return false # b -> a


# Instance every mod and add it as a node to the Mod Loader.
# Runs mods in the order stored in mod_load_order.
func _init_mod(mod: ModData) -> void:
	var mod_main_path := mod.get_required_mod_file_path(ModData.required_mod_files.MOD_MAIN)
	var mod_overwrites_path := mod.get_optional_mod_file_path(ModData.optional_mod_files.OVERWRITES)

	# If the mod contains overwrites initialize the overwrites script
	if mod.is_overwrite:
		ModLoaderUtils.log_debug("Overwrite script detected -> %s" % mod_overwrites_path, LOG_NAME)
		var mod_overwrites_script := load(mod_overwrites_path)
		mod_overwrites_script.new()
		ModLoaderUtils.log_debug("Initialized overwrite script -> %s" % mod_overwrites_path, LOG_NAME)

	ModLoaderUtils.log_debug("Loading script from -> %s" % mod_main_path, LOG_NAME)
	var mod_main_script := ResourceLoader.load(mod_main_path)
	ModLoaderUtils.log_debug("Loaded script -> %s" % mod_main_script, LOG_NAME)

	var mod_main_instance: Node = mod_main_script.new(self)
	mod_main_instance.name = mod.manifest.get_mod_id()

	ModLoaderUtils.log_debug("Adding child -> %s" % mod_main_instance, LOG_NAME)
	add_child(mod_main_instance, true)


# Couple the extension paths with the parent paths and the extension's mod id
# in a ScriptExtensionData resource
func _handle_script_extensions()->void:
	var script_extension_data_array := []
	for extension_path in script_extensions:

		if not File.new().file_exists(extension_path):
			ModLoaderUtils.log_error("The child script path '%s' does not exist" % [extension_path], LOG_NAME)
			continue

		var child_script = ResourceLoader.load(extension_path)

		var mod_id:String = extension_path.trim_prefix(UNPACKED_DIR).get_slice("/", 0)

		var parent_script:Script = child_script.get_base_script()
		var parent_script_path:String = parent_script.resource_path

		if not loaded_vanilla_parents_cache.keys().has(parent_script_path):
			loaded_vanilla_parents_cache[parent_script_path] = parent_script

		script_extension_data_array.push_back(
			ScriptExtensionData.new(extension_path, parent_script_path, mod_id)
		)

	# Sort the extensions based on dependencies
	script_extension_data_array = _sort_extensions_from_load_order(script_extension_data_array)

	# Inheritance is more important so this called last
	script_extension_data_array.sort_custom(self, "check_inheritances")

	# This saved some bugs in the past.
	loaded_vanilla_parents_cache.clear()

	# Load and install all extensions
	for extension in script_extension_data_array:
		var script:Script = _apply_extension(extension.extension_path)
		_reload_vanilla_child_classes_for(script)


# Sort an array of ScriptExtensionData following the load order
func _sort_extensions_from_load_order(extensions:Array)->Array:
	var extensions_sorted := []

	for _mod_data in mod_load_order:
		for script in extensions:
			if script.mod_id == _mod_data.dir_name:
				extensions_sorted.push_front(script)

	return extensions_sorted


# Inheritance sorting
# Go up extension_a's inheritance tree to find if any parent shares the same vanilla path as extension_b
func _check_inheritances(extension_a:ScriptExtensionData, extension_b:ScriptExtensionData)->bool:
	var a_child_script:Script

	if loaded_vanilla_parents_cache.keys().has(extension_a.parent_script_path):
		a_child_script = ResourceLoader.load(extension_a.parent_script_path)
	else:
		a_child_script = ResourceLoader.load(extension_a.parent_script_path)
		loaded_vanilla_parents_cache[extension_a.parent_script_path] = a_child_script

	var a_parent_script:Script = a_child_script.get_base_script()

	if a_parent_script == null:
		return true

	var a_parent_script_path = a_parent_script.resource_path
	if a_parent_script_path == extension_b.parent_script_path:
		return false

	else:
		return _check_inheritances(ScriptExtensionData.new(extension_a.extension_path, a_parent_script_path, extension_a.mod_id), extension_b)


# Reload all children classes of the vanilla class we just extended
# Calling reload() the children of an extended class seems to allow them to be extended
# e.g if B is a child class of A, reloading B after apply an extender of A allows extenders of B to properly extend B, taking A's extender(s) into account
func _reload_vanilla_child_classes_for(script:Script)->void:

	if script == null:
		return
	var current_child_classes := []
	var actual_path:String = script.get_base_script().resource_path
	var classes:Array = ProjectSettings.get_setting("_global_script_classes")

	for _class in classes:
		if _class.path == actual_path:
			current_child_classes.push_back(_class)
			break

	for _class in current_child_classes:
		for child_class in classes:

			if child_class.base == _class.class:
				load(child_class.path).reload()


func _apply_extension(extension_path)->Script:
	# Check path to file exists
	if not File.new().file_exists(extension_path):
		ModLoaderUtils.log_error("The child script path '%s' does not exist" % [extension_path], LOG_NAME)
		return null

	var child_script:Script = ResourceLoader.load(extension_path)
	# Adding metadata that contains the extension script path
	# We cannot get that path in any other way
	# Passing the child_script as is would return the base script path
	# Passing the .duplicate() would return a '' path
	child_script.set_meta("extension_script_path", extension_path)

	# Force Godot to compile the script now.
	# We need to do this here to ensure that the inheritance chain is
	# properly set up, and multiple mods can chain-extend the same
	# class multiple times.
	# This is also needed to make Godot instantiate the extended class
	# when creating singletons.
	# The actual instance is thrown away.
	child_script.new()

	var parent_script:Script = child_script.get_base_script()
	var parent_script_path:String = parent_script.resource_path

	# We want to save scripts for resetting later
	# All the scripts are saved in order already
	if not _saved_scripts.has(parent_script_path):
		_saved_scripts[parent_script_path] = []
		# The first entry in the saved script array that has the path
		# used as a key will be the duplicate of the not modified script
		_saved_scripts[parent_script_path].append(parent_script.duplicate())
	_saved_scripts[parent_script_path].append(child_script)

	ModLoaderUtils.log_info("Installing script extension: %s <- %s" % [parent_script_path, extension_path], LOG_NAME)
	child_script.take_over_path(parent_script_path)

	return child_script


# Used to remove a specific extension
func _remove_extension(extension_path: String) -> void:
	# Check path to file exists
	if not ModLoaderUtils.file_exists(extension_path):
		ModLoaderUtils.log_error("The extension script path \"%s\" does not exist" % [extension_path], LOG_NAME)
		return null

	var extension_script: Script = ResourceLoader.load(extension_path)
	var parent_script: Script = extension_script.get_base_script()
	var parent_script_path: String = parent_script.resource_path

	# Check if the script to reset has been extended
	if not _saved_scripts.has(parent_script_path):
		ModLoaderUtils.log_error("The extension parent script path \"%s\" has not been extended" % [parent_script_path], LOG_NAME)
		return

	# Check if the script to reset has anything actually saved
	# If we ever encounter this it means something went very wrong in extending
	if not _saved_scripts[parent_script_path].size() > 0:
		ModLoaderUtils.log_error("The extension script path \"%s\" does not have the base script saved, this should never happen, if you encounter this please create an issue in the github repository" % [parent_script_path], LOG_NAME)
		return

	var parent_script_extensions: Array = _saved_scripts[parent_script_path].duplicate()
	parent_script_extensions.remove(0)

	# Searching for the extension that we want to remove
	var found_script_extension: Script = null
	for script_extension in parent_script_extensions:
		if script_extension.get_meta("extension_script_path") == extension_path:
			found_script_extension = script_extension
			break

	if found_script_extension == null:
		ModLoaderUtils.log_error("The extension script path \"%s\" has not been found in the saved extension of the base script" % [parent_script_path], LOG_NAME)
		return
	parent_script_extensions.erase(found_script_extension)

	# Preparing the script to have all other extensions reapllied
	_reset_extension(parent_script_path)

	# Reapplying all the extensions without the removed one
	for script_extension in parent_script_extensions:
		_apply_extension(script_extension.get_meta("extension_script_path"))


# Used to fully reset the provided script to a state prior of any extension
func _reset_extension(parent_script_path: String) -> void:
	# Check path to file exists
	if not ModLoaderUtils.file_exists(parent_script_path):
		ModLoaderUtils.log_error("The parent script path \"%s\" does not exist" % [parent_script_path], LOG_NAME)
		return

	# Check if the script to reset has been extended
	if not _saved_scripts.has(parent_script_path):
		ModLoaderUtils.log_error("The parent script path \"%s\" has not been extended" % [parent_script_path], LOG_NAME)
		return

	# Check if the script to reset has anything actually saved
	# If we ever encounter this it means something went very wrong in extending
	if not _saved_scripts[parent_script_path].size() > 0:
		ModLoaderUtils.log_error("The parent script path \"%s\" does not have the base script saved, \nthis should never happen, if you encounter this please create an issue in the github repository" % [parent_script_path], LOG_NAME)
		return

	var parent_script: Script = _saved_scripts[parent_script_path][0]
	parent_script.take_over_path(parent_script_path)

	# Remove the script after it has been reset so we do not do it again
	_saved_scripts.erase(parent_script_path)


# Helpers
# =============================================================================

# Helper functions to build mods

# Add a script that extends a vanilla script. `child_script_path` should point
# to your mod's extender script, eg "MOD/extensions/singletons/utils.gd".
# Inside that extender script, it should include "extends {target}", where
# {target} is the vanilla path, eg: `extends "res://singletons/utils.gd"`.
# Note that your extender script doesn't have to follow the same directory path
# as the vanilla file, but it's good practice to do so.
func install_script_extension(child_script_path:String):

	# If this is called during initialization, add it with the other
	# extensions to be installed taking inheritance chain into account
	if is_initializing:
		script_extensions.push_back(child_script_path)

	# If not, apply the extension directly
	else:
		_apply_extension(child_script_path)


func uninstall_script_extension(extension_script_path: String) -> void:

	# Currently this is the only thing we do, but it is better to expose
	# this function like this for further changes
	_remove_extension(extension_script_path)


# Register an array of classes to the global scope, since Godot only does that in the editor.
# Format: { "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }
# You can find these easily in the project.godot file under "_global_script_classes"
# (but you should only include classes belonging to your mod)
func register_global_classes_from_array(new_global_classes: Array) -> void:
	ModLoaderUtils.register_global_classes_from_array(new_global_classes)
	var _savecustom_error: int = ProjectSettings.save_custom(ModLoaderUtils.get_override_path())


# Add a translation file, eg "mytranslation.en.translation". The translation
# file should have been created in Godot already: When you import a CSV, such
# a file will be created for you.
func add_translation_from_resource(resource_path: String) -> void:
	if not File.new().file_exists(resource_path):
		ModLoaderUtils.log_fatal("Tried to load a translation resource from a file that doesn't exist. The invalid path was: %s" % [resource_path], LOG_NAME)
		return

	var translation_object: Translation = load(resource_path)
	TranslationServer.add_translation(translation_object)
	ModLoaderUtils.log_info("Added Translation from Resource -> %s" % resource_path, LOG_NAME)


func append_node_in_scene(modified_scene: Node, node_name: String = "", node_parent = null, instance_path: String = "", is_visible: bool = true) -> void:
	var new_node: Node
	if not instance_path == "":
		new_node = load(instance_path).instance()
	else:
		new_node = Node.instance()
	if not node_name == "":
		new_node.name = node_name
	if is_visible == false:
		new_node.visible = false
	if not node_parent == null:
		var tmp_node: Node = modified_scene.get_node(node_parent)
		tmp_node.add_child(new_node)
		new_node.set_owner(modified_scene)
	else:
		modified_scene.add_child(new_node)
		new_node.set_owner(modified_scene)


func save_scene(modified_scene: Node, scene_path: String) -> void:
	var packed_scene := PackedScene.new()
	var _pack_error := packed_scene.pack(modified_scene)
	ModLoaderUtils.log_debug("packing scene -> %s" % packed_scene, LOG_NAME)
	packed_scene.take_over_path(scene_path)
	ModLoaderUtils.log_debug("save_scene - taking over path - new path -> %s" % packed_scene.resource_path, LOG_NAME)
	_saved_objects.append(packed_scene)



# Deprecated
# =============================================================================

func get_mod_config(mod_dir_name: String = "", key: String = "") -> Dictionary:
	ModLoaderDeprecated.deprecated_changed("ModLoader.get_mod_config", "ModLoaderConfig.get_mod_config", "6.0.0")
	return ModLoaderConfig.get_mod_config(mod_dir_name, key)
