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

# Override for the path mods are loaded from. Only set if the CLI arg is present.
# Can be tested in the editor via: Project Settings > Display> Editor > Main Run Args
# Default: "res://mods"
# Set via: --mods-path
# Example: --mods-path="C://path/mods"
var os_mods_path_override := ""

# Override for the path config JSONs are loaded from
# Default: "res://configs"
# Set via: --configs-path
# Example: --configs-path="C://path/configs"
var os_configs_path_override := ""

# Any mods that are missing their dependancies are added to this
# Example property: "mod_id": ["dep_mod_id_0", "dep_mod_id_2"]
var mod_missing_dependencies := {}

# Things to keep to ensure they are not garbage collected (used by `save_scene`)
var _saved_objects := []


# Main
# =============================================================================

func _init() -> void:
	# if mods are not enabled - don't load mods
	if REQUIRE_CMD_LINE and not ModLoaderUtils.is_running_with_command_line_arg("--enable-mods"):
		return

	# Rotate the log files once on startup. Can't be checked in utils, since it's static
	ModLoaderUtils.rotate_log_file()

	# Ensure ModLoader is the first autoload
	_check_first_autoload()

	# Log game install dir
	ModLoaderUtils.log_info("game_install_directory: %s" % ModLoaderUtils.get_local_folder_dir(), LOG_NAME)

	# check if we want to use a different mods path that is provided as a command line argument
	var cmd_line_mod_path := ModLoaderUtils.get_cmd_line_arg_value("--mods-path")
	if not cmd_line_mod_path == "":
		os_mods_path_override = cmd_line_mod_path
		ModLoaderUtils.log_info("The path mods are loaded from has been changed via the CLI arg `--mods-path`, to: " + cmd_line_mod_path, LOG_NAME)

	# Check for the CLI arg that overrides the configs path
	var cmd_line_configs_path := ModLoaderUtils.get_cmd_line_arg_value("--configs-path")
	if not cmd_line_configs_path == "":
		os_configs_path_override = cmd_line_configs_path
		ModLoaderUtils.log_info("The path configs are loaded from has been changed via the CLI arg `--configs-path`, to: " + cmd_line_configs_path, LOG_NAME)

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

	# Run dependency checks after loading mod_manifest. If a mod depends on another
	# mod that hasn't been loaded, that dependent mod won't be loaded.
	for dir_name in mod_data:
		var mod: ModData = mod_data[dir_name]
		if not mod.is_loadable:
			continue
		_check_dependencies(mod)

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


# Ensure ModLoader is the first autoload
func _check_first_autoload() -> void:
	var autoload_array = ModLoaderUtils.get_autoload_array()
	var mod_loader_index = autoload_array.find("ModLoader")
	var is_mod_loader_first = mod_loader_index == 0

	var override_cfg_path = ModLoaderUtils.get_override_path()
	var is_override_cfg_setup =  ModLoaderUtils.file_exists(override_cfg_path)

	# Log the autoloads order. Might seem superflous but could help when providing support
	ModLoaderUtils.log_debug_json_print("Autoload order", autoload_array, LOG_NAME)

	# If the override file exists we assume the ModLoader was setup with the --setup-create-override-cfg cli arg
	# In that case the ModLoader will be the last entry in the autoload array
	if is_override_cfg_setup:
		ModLoaderUtils.log_info("override.cfg setup detected, ModLoader will be the last autoload loaded.", LOG_NAME)
		return

	var base_msg = "ModLoader needs to be the first autoload to work correctly, "
	var help_msg = ""

	if OS.has_feature("editor"):
		help_msg = "To configure your autoloads, go to Project > Project Settings > Autoload, and add ModLoader as the first item. For more info, see the 'Godot Project Setup' page on the ModLoader GitHub wiki."
	else:
		help_msg = "If you're seeing this error, something must have gone wrong in the setup process."

	if not is_mod_loader_first:
		ModLoaderUtils.log_fatal(str(base_msg, 'but the first autoload is currently: "%s". ' % autoload_array[0], help_msg), LOG_NAME)


# Loop over "res://mods" and add any mod zips to the unpacked virtual directory
# (UNPACKED_DIR)
func _load_mod_zips() -> int:
	# Path to the games mod folder
	var game_mod_folder_path := ModLoaderUtils.get_local_folder_dir("mods")
	if not os_mods_path_override == "":
		game_mod_folder_path = os_mods_path_override

	var dir := Directory.new()
	if not dir.open(game_mod_folder_path) == OK:
		ModLoaderUtils.log_warning("Can't open mod folder %s." % game_mod_folder_path, LOG_NAME)
		return -1
	if not dir.list_dir_begin() == OK:
		ModLoaderUtils.log_warning("Can't read mod folder %s." % game_mod_folder_path, LOG_NAME)
		return -1

	var has_shown_editor_warning := false

	var zipped_mods_count := 0
	# Get all zip folders inside the game mod folder
	while true:
		# Get the next file in the directory
		var mod_zip_file_name := dir.get_next()

		# If there is no more file
		if mod_zip_file_name == "":
			# Stop loading mod zip files
			break

		# Ignore files that aren't ZIP or PCK
		if not mod_zip_file_name.get_extension() == "zip" and not mod_zip_file_name.get_extension() == "pck":
			continue

		# If the current file is a directory
		if dir.current_is_dir():
			# Go to the next file
			continue

		var mod_folder_path := game_mod_folder_path.plus_file(mod_zip_file_name)
		var mod_folder_global_path := ProjectSettings.globalize_path(mod_folder_path)
		var is_mod_loaded_successfully := ProjectSettings.load_resource_pack(mod_folder_global_path, false)

		# Notifies developer of an issue with Godot, where using `load_resource_pack`
		# in the editor WIPES the entire virtual res:// directory the first time you
		# use it. This means that unpacked mods are no longer accessible, because they
		# no longer exist in the file system. So this warning basically says
		# "don't use ZIPs with unpacked mods!"
		# https://github.com/godotengine/godot/issues/19815
		# https://github.com/godotengine/godot/issues/16798
		if OS.has_feature("editor") and not has_shown_editor_warning:
			ModLoaderUtils.log_warning(str(
				"Loading any resource packs (.zip/.pck) with `load_resource_pack` will WIPE the entire virtual res:// directory. ",
				"If you have any unpacked mods in ", UNPACKED_DIR, ", they will not be loaded. ",
				"Please unpack your mod ZIPs instead, and add them to ", UNPACKED_DIR), LOG_NAME)
			has_shown_editor_warning = true

		ModLoaderUtils.log_debug("Found mod ZIP: %s" % mod_folder_global_path, LOG_NAME)

		# If there was an error loading the mod zip file
		if not is_mod_loaded_successfully:
			# Log the error and continue with the next file
			ModLoaderUtils.log_error("%s failed to load." % mod_zip_file_name, LOG_NAME)
			continue

		# Mod successfully loaded!
		ModLoaderUtils.log_success("%s loaded." % mod_zip_file_name, LOG_NAME)
		zipped_mods_count += 1

	dir.list_dir_end()
	return zipped_mods_count


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

		# Init the mod data
		_init_mod_data(mod_dir_name)
		unpacked_mods_count += 1

	dir.list_dir_end()
	return unpacked_mods_count


# Load mod config JSONs from res://configs
func _load_mod_configs() -> void:
	var found_configs_count := 0
	var configs_path := ModLoaderUtils.get_local_folder_dir("configs")

	# CLI override, set with `--configs-path="C://path/configs"`
	# (similar to os_mods_path_override)
	if not os_configs_path_override == "":
		configs_path = os_configs_path_override

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
# hasn't been loaded, the dependent mod won't be loaded.
func _check_dependencies(mod: ModData) -> void:
	ModLoaderUtils.log_debug("Checking dependencies - mod_id: %s dependencies: %s" % [mod.dir_name, mod.manifest.dependencies], LOG_NAME)

	# loop through each dependency
	for dependency_id in mod.manifest.dependencies:
		# check if dependency is missing
		if not mod_data.has(dependency_id):
			_handle_missing_dependency(mod.dir_name, dependency_id)
			# Flag the mod so it's not loaded later
			mod.is_loadable = false
			continue

		var dependency: ModData = mod_data[dependency_id]

		# increase importance score by 1
		dependency.importance += 1
		ModLoaderUtils.log_debug("Dependency -> %s importance -> %s" % [dependency_id, dependency.importance], LOG_NAME)

		# check if dependency has dependencies
		if dependency.manifest.dependencies.size() > 0:
			_check_dependencies(dependency)


# Handle missing dependencies: Sets `is_loadable` to false and logs an error
func _handle_missing_dependency(mod_dir_name: String, dependency_id: String) -> void:
	ModLoaderUtils.log_error("Missing dependency - mod: -> %s dependency -> %s" % [mod_dir_name, dependency_id], LOG_NAME)
	# if mod is not present in the missing dependencies array
	if not mod_missing_dependencies.has(mod_dir_name):
		# add it
		mod_missing_dependencies[mod_dir_name] = []

	mod_missing_dependencies[mod_dir_name].append(dependency_id)


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


# Helpers
# =============================================================================

# Helper functions to build mods

# Add a script that extends a vanilla script. `child_script_path` should point
# to your mod's extender script, eg "MOD/extensions/singletons/utils.gd".
# Inside that extender script, it should include "extends {target}", where
# {target} is the vanilla path, eg: `extends "res://singletons/utils.gd"`.
# Note that your extender script doesn't have to follow the same directory path
# as the vanilla file, but it's good practice to do so.



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

	script_extensions.push_back(child_script_path)





# stores all extenders paths
var script_extensions = []

# this is for caching purposes during the sorting.
var loaded_vanilla_parents = {}

func handle_script_extensions()->void:

	# couple the extension paths with the parent paths and the extension's mod id
	var parent_paths = []
	for extension_path in script_extensions:
		
		if not File.new().file_exists(extension_path):
			ModLoaderUtils.log_error("The child script path '%s' does not exist" % [extension_path], LOG_NAME)
			continue 
		
		var child_script 	= ResourceLoader.load(extension_path)
		
		# this could be done during install_script_extension() ?
		var mod_id = extension_path.replace(UNPACKED_DIR, "").get_slice("/", 0)
		
		var parent_script = child_script.get_base_script()
		var parent_script_path = parent_script.resource_path
		
		if not loaded_vanilla_parents.keys().has(parent_script_path):
			loaded_vanilla_parents[parent_script_path] = parent_script
		
		parent_paths.push_back([extension_path, parent_script_path, mod_id])
	
	
	# sort the extensions based on dependencies then inheritance
	parent_paths = sort_w_dependencies(parent_paths)
	# inheritance is more important so this called last
	parent_paths.sort_custom(self, "check_inheritances")
	
	# useless but maybe not
	loaded_vanilla_parents.clear()
	
	# load and install all extensions
	for extension in parent_paths:
		var scr = apply_extension(extension[0])
		reload_vanilla_child_classes_for(scr, extension[2])
		
	
func sort_w_dependencies(extensions:Array)->Array:

	# what this does :
	#
	# adds independent mod_ids to new_arr
	# iterate and append to extensions_sorted every mod that has all their dependencies in new_arr
	# remove those from mods_sorted and loop till mods_sorted is empty
	# extensions_sorted ends up sorted with every dependency before the mods using them
	
	# probably should be optimized because i think n²?

	# array to unpopulate on each iteration
	var all_mods = mod_data.keys()
	# array to populate on each iteration
	var mods_sorted = []
	# when all_mods is empty, fill this following mods_sorted order
	var extensions_sorted = []

	# add independent mods
	for mod_id in mod_data.keys():
		if mod_data[mod_id].manifest.dependencies.empty():
			mods_sorted.push_back(mod_id)
			all_mods.erase(mod_id)

	# iterate till all mods have been sorted
	while not all_mods.empty():
		var to_remove = []
		for mod_id in all_mods:
			
			var dependencies = mod_data[mod_id].manifest.dependencies
			for i in dependencies.size():
				
				var dependency = dependencies[i]
				
				# skip if any dependency isn't in mods_sorted already
				if not mods_sorted.has(dependency):
					break
				
				# transfer if all dependencies are in mods_sorted
				if i == dependencies.size() - 1:
					mods_sorted.push_back(mod_id)
					to_remove.push_back(mod_id)
	
		for mod_id in to_remove:
			all_mods.erase(mod_id)
	
	# populate extensions_sorted following the dependency order
	for mod_id in mods_sorted:
		for script in extensions:
			if script[2] == mod_id:
				extensions_sorted.push_front(script)
	
	
	return extensions_sorted


# goes up a's inheritance tree to find if any parent shares the same path as b
func check_inheritances(a:Array, b:Array)->bool:
	var a_child_script
	if loaded_vanilla_parents.keys().has(a[1]):
		a_child_script = ResourceLoader.load(a[1])
	else:
		a_child_script = ResourceLoader.load(a[1])
		loaded_vanilla_parents[a[1]] = a_child_script

	var a_parent_script = a_child_script.get_base_script()
	if a_parent_script == null:
		return true

	var a_parent_script_path = a_parent_script.resource_path
	if a_parent_script_path == b[1]:
		return false
	else:
		return check_inheritances([a[0], a_parent_script_path, a[2]], b)

# calling reload() on all of extender's children seem to allow them to be extended
# e.g if B is a child class of A, reloading B after apply an extender of A allows extenders of B to properly extend B, taking A's extender(s) into account
# this is useless if B's extenders are installed before A's
func reload_vanilla_child_classes_for(script:Script, mod_name:String)->void:

	var child_classes = []
	var current_child_classes = []
	var actual_path = script.get_base_script().resource_path
	var classes = ProjectSettings.get_setting("_global_script_classes")

	for _class in classes:

		if _class.path == actual_path:
			current_child_classes.push_back(_class)
			break
	while not current_child_classes.empty():
		var new_child_classes = []
		
		for _class in current_child_classes:
			for child_class in classes:
				if child_class.base == _class.class:
					
					new_child_classes.push_back(child_class)
					child_classes.push_back(child_class)
					
					load(child_class.path).reload()
		
		current_child_classes = new_child_classes


func apply_extension(extension_path)->Script:
	# Check path to file exists
	if not File.new().file_exists(extension_path):
		ModLoaderUtils.log_error("The child script path '%s' does not exist" % [extension_path], LOG_NAME)
		return null
	
	var child_script = ResourceLoader.load(extension_path)
	
	# Force Godot to compile the script now.
	# We need to do this here to ensure that the inheritance chain is
	# properly set up, and multiple mods can chain-extend the same
	# class multiple times.
	# This is also needed to make Godot instantiate the extended class
	# when creating singletons.
	# The actual instance is thrown away.
	child_script.new()
	
	var parent_script = child_script.get_base_script()
	var parent_script_path = parent_script.resource_path
	ModLoaderUtils.log_info("Installing script extension: %s <- %s" % [parent_script_path, extension_path], LOG_NAME)
	child_script.take_over_path(parent_script_path)
	
	return child_script




# Register an array of classes to the global scope, since Godot only does that in the editor.
# Format: { "base": "ParentClass", "class": "ClassName", "language": "GDScript", "path": "res://path/class_name.gd" }
# You can find these easily in the project.godot file under "_global_script_classes"
# (but you should only include classes belonging to your mod)
func register_global_classes_from_array(new_global_classes: Array) -> void:
	ModLoaderUtils.register_global_classes_from_array(new_global_classes)
	var _savecustom_error: int = ProjectSettings.save_custom(ModLoaderUtils.get_override_path())


# Add a translation file, eg "mytranslation.en.translation". The translation
# file should have been created in Godot already: When you improt a CSV, such
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


enum MLConfigStatus {
	OK,                  # 0 = No errors
	INVALID_MOD_ID,      # 1 = Invalid mod ID
	NO_JSON_OK,          # 2 = No custom JSON. File probably does not exist. Defaults will be used if available
	NO_JSON_INVALID_KEY, # 3 = No custom JSON, and key was invalid when trying to get the default from your manifest defaults (`extra.godot.config_defaults`)
	INVALID_KEY          # 4 = Invalid key, although config data does exists
}

# Get the config data for a specific mod. Always returns a dictionary with two
# keys: `error` and `data`.
# Data (`data`) is either the full config, or data from a specific key if one was specified.
# Error (`error`) is 0 if there were no errors, or > 0 if the setting could not be retrieved:
func get_mod_config(mod_dir_name: String = "", key: String = "") -> Dictionary:
	var status_code = MLConfigStatus.OK
	var status_msg := ""
	var data = {} # can be anything
	var defaults := {}

	# Invalid mod ID
	if not mod_data.has(mod_dir_name):
		status_code = MLConfigStatus.INVALID_MOD_ID
		status_msg = "Mod ID was invalid: %s" % mod_dir_name

	# Mod ID is valid
	if status_code == MLConfigStatus.OK:
		var mod := mod_data[mod_dir_name] as ModData
		var config_data := mod.config
		defaults = mod.manifest.config_defaults

		# No custom JSON file
		if config_data.size() == MLConfigStatus.OK:
			status_code = MLConfigStatus.NO_JSON_OK
			var noconfig_msg = "No config file for %s.json. " % mod_dir_name
			if key == "":
				data = defaults
				status_msg += str(noconfig_msg, "Using defaults (extra.godot.config_defaults)")
			else:
				if defaults.has(key):
					data = defaults[key]
					status_msg += str(noconfig_msg, "Using defaults for key '%s' (extra.godot.config_defaults.%s)" % [key, key])
				else:
					status_code = MLConfigStatus.NO_JSON_INVALID_KEY
					status_msg += str(
						"Could not get the requested data for %s: " % mod_dir_name,
						"Requested key '%s' is not present in the 'config_defaults' of the mod's manifest.json file (extra.godot.config_defaults.%s). " % [key, key]
					)

		# JSON file exists
		if status_code == MLConfigStatus.OK:
			if key == "":
				data = config_data
			else:
				if config_data.has(key):
					data = config_data[key]
				else:
					status_code = MLConfigStatus.INVALID_KEY
					status_msg = "Invalid key '%s' for mod ID: %s" % [key, mod_dir_name]

	# Log if any errors occured
	if not status_code == MLConfigStatus.OK:
		if status_code == MLConfigStatus.NO_JSON_OK:
			# No user config file exists. Low importance as very likely to trigger
			ModLoaderUtils.log_debug("Config JSON Notice: %s" % status_msg, mod_dir_name)
		else:
			# Code error (eg. invalid mod ID)
			ModLoaderUtils.log_fatal("Config JSON Error (%s): %s" % [status_code, status_msg], mod_dir_name)

	return {
		"status_code": status_code,
		"status_msg": status_msg,
		"data": data,
	}
