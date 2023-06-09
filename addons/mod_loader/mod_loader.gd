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


signal logged(entry)

# Prefix for this file when using mod_log or dev_log
const LOG_NAME := "ModLoader"

# --- DEPRECATED ---
# UNPACKED_DIR was moved to ModLoaderStore.
# However, many Brotato mods use this const directly, which is why the deprecation warning was added.
var UNPACKED_DIR := "res://mods-unpacked/" setget ,deprecated_direct_access_UNPACKED_DIR

# Main
# =============================================================================

func _init() -> void:
	# if mods are not enabled - don't load mods
	if ModLoaderStore.REQUIRE_CMD_LINE and not _ModLoaderCLI.is_running_with_command_line_arg("--enable-mods"):
		return

	# Rotate the log files once on startup. Can't be checked in utils, since it's static
	ModLoaderLog._rotate_log_file()

	# Ensure ModLoaderStore and ModLoader are the 1st and 2nd autoloads
	_check_autoload_positions()

	# Log the autoloads order. Helpful when providing support to players
	ModLoaderLog.debug_json_print("Autoload order", _ModLoaderGodot.get_autoload_array(), LOG_NAME)

	# Log game install dir
	ModLoaderLog.info("game_install_directory: %s" % _ModLoaderPath.get_local_folder_dir(), LOG_NAME)

	if not ModLoaderStore.ml_options.enable_mods:
		ModLoaderLog.info("Mods are currently disabled", LOG_NAME)
		return

	# Load user profiles into ModLoaderStore
	var _success_user_profile_load := ModLoaderUserProfile._load()
	# Update the list of disabled mods in ModLoaderStore based on the current user profile
	ModLoaderUserProfile._update_disabled_mods()

	_load_mods()

	ModLoaderStore.is_initializing = false


func _ready():
	# Create the default user profile if it doesn't exist already
	# This should always be present unless the JSON file was manually edited
	if not ModLoaderStore.user_profiles.has("default"):
		var _success_user_profile_create := ModLoaderUserProfile.create_profile("default")

	# Update the mod_list for each user profile
	var _success_update_mod_lists := ModLoaderUserProfile._update_mod_lists()


func _load_mods() -> void:
	# Loop over "res://mods" and add any mod zips to the unpacked virtual
	# directory (UNPACKED_DIR)
	var unzipped_mods := _load_mod_zips()
	if unzipped_mods > 0:
		ModLoaderLog.success("DONE: Loaded %s mod files into the virtual filesystem" % unzipped_mods, LOG_NAME)
	else:
		ModLoaderLog.info("No zipped mods found", LOG_NAME)

	# Loop over UNPACKED_DIR. This triggers _init_mod_data for each mod
	# directory, which adds their data to mod_data.
	var setup_mods := _setup_mods()
	if setup_mods > 0:
		ModLoaderLog.success("DONE: Setup %s mods" % setup_mods, LOG_NAME)
	else:
		ModLoaderLog.info("No mods were setup", LOG_NAME)

	# Set up mod configs. If a mod's JSON file is found, its data gets added
	# to mod_data.{dir_name}.config
	_load_mod_configs()

	# Loop over all loaded mods via their entry in mod_data. Verify that they
	# have all the required files (REQUIRED_MOD_FILES), load their meta data
	# (from their manifest.json file), and verify that the meta JSON has all
	# required properties (REQUIRED_META_TAGS)
	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		mod.load_manifest()

	ModLoaderLog.success("DONE: Loaded all meta data", LOG_NAME)


	# Check for mods with load_before. If a mod is listed in load_before,
	# add the current mod to the dependencies of the the mod specified
	# in load_before.
	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if not mod.is_loadable:
			continue
		_ModLoaderDependency.check_load_before(mod)


	# Run optional dependency checks after loading mod_manifest.
	# If a mod depends on another mod that hasn't been loaded,
	# that dependent mod will be loaded regardless.
	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if not mod.is_loadable:
			continue
		var _is_circular := _ModLoaderDependency.check_dependencies(mod, false)


	# Run dependency checks after loading mod_manifest. If a mod depends on another
	# mod that hasn't been loaded, that dependent mod won't be loaded.
	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if not mod.is_loadable:
			continue
		var _is_circular := _ModLoaderDependency.check_dependencies(mod)

	# Sort mod_load_order by the importance score of the mod
	ModLoaderStore.mod_load_order = _ModLoaderDependency.get_load_order(ModLoaderStore.mod_data.values())

	# Log mod order
	var mod_i := 1
	for mod in ModLoaderStore.mod_load_order: # mod === mod_data
		mod = mod as ModData
		ModLoaderLog.info("mod_load_order -> %s) %s" % [mod_i, mod.dir_name], LOG_NAME)
		mod_i += 1

	# Instance every mod and add it as a node to the Mod Loader
	for mod in ModLoaderStore.mod_load_order:
		mod = mod as ModData
		ModLoaderLog.info("Initializing -> %s" % mod.manifest.get_mod_id(), LOG_NAME)
		_init_mod(mod)

	ModLoaderLog.debug_json_print("mod data", ModLoaderStore.mod_data, LOG_NAME)

	ModLoaderLog.success("DONE: Completely finished loading mods", LOG_NAME)

	_ModLoaderScriptExtension.handle_script_extensions()

	ModLoaderLog.success("DONE: Installed all script extensions", LOG_NAME)

	ModLoaderStore.is_initializing = false


# Internal call to reload mods
func _reload_mods() -> void:
	_reset_mods()
	_load_mods()


# Internal call that handles the resetting of all mod related data
func _reset_mods() -> void:
	_disable_mods()
	ModLoaderStore.mod_data.clear()
	ModLoaderStore.mod_load_order.clear()
	ModLoaderStore.mod_missing_dependencies.clear()
	ModLoaderStore.script_extensions.clear()


# Internal call that handles the disabling of all mods
func _disable_mods() -> void:
	for mod in ModLoaderStore.mod_data:
		_disable_mod(ModLoaderStore.mod_data[mod])


# Check autoload positions:
# Ensure 1st autoload is `ModLoaderStore`, and 2nd is `ModLoader`.
func _check_autoload_positions() -> void:
	# If the override file exists we assume the ModLoader was setup with the --setup-create-override-cfg cli arg
	# In that case the ModLoader will be the last entry in the autoload array
	var override_cfg_path := _ModLoaderPath.get_override_path()
	var is_override_cfg_setup :=  _ModLoaderFile.file_exists(override_cfg_path)
	if is_override_cfg_setup:
		ModLoaderLog.info("override.cfg setup detected, ModLoader will be the last autoload loaded.", LOG_NAME)
		return

	var _pos_ml_store := _ModLoaderGodot.check_autoload_position("ModLoaderStore", 0, true)
	var _pos_ml_core := _ModLoaderGodot.check_autoload_position("ModLoader", 1, true)


# Loop over "res://mods" and add any mod zips to the unpacked virtual directory
# (UNPACKED_DIR)
func _load_mod_zips() -> int:
	var zipped_mods_count := 0

	if not ModLoaderStore.ml_options.steam_workshop_enabled:
		var mods_folder_path := _ModLoaderPath.get_path_to_mods()

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
		ModLoaderLog.error("Can't open mod folder %s (Error: %s)" % [folder_path, mod_dir_open_error], LOG_NAME)
		return -1
	var mod_dir_listdir_error := mod_dir.list_dir_begin()
	if not mod_dir_listdir_error == OK:
		ModLoaderLog.error("Can't read mod folder %s (Error: %s)" % [folder_path, mod_dir_listdir_error], LOG_NAME)
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
			ModLoaderLog.warning(str(
				"Loading any resource packs (.zip/.pck) with `load_resource_pack` will WIPE the entire virtual res:// directory. ",
				"If you have any unpacked mods in ", _ModLoaderPath.get_unpacked_mods_dir_path(), ", they will not be loaded. ",
				"Please unpack your mod ZIPs instead, and add them to ", _ModLoaderPath.get_unpacked_mods_dir_path()), LOG_NAME)
			ModLoaderStore.has_shown_editor_zips_warning = true

		ModLoaderLog.debug("Found mod ZIP: %s" % mod_folder_global_path, LOG_NAME)

		# If there was an error loading the mod zip file
		if not is_mod_loaded_successfully:
			# Log the error and continue with the next file
			ModLoaderLog.error("%s failed to load." % mod_zip_file_name, LOG_NAME)
			continue

		# Mod successfully loaded!
		ModLoaderLog.success("%s loaded." % mod_zip_file_name, LOG_NAME)
		temp_zipped_mods_count += 1

	mod_dir.list_dir_end()

	return temp_zipped_mods_count


# Load mod ZIPs from Steam workshop folders. Uses 2 loops: One for each
# workshop item's folder, with another inside that which loops over the ZIPs
# inside each workshop item's folder
func _load_steam_workshop_zips() -> int:
	var temp_zipped_mods_count := 0
	var workshop_folder_path := _ModLoaderSteam.get_path_to_workshop()

	ModLoaderLog.info("Checking workshop items, with path: \"%s\"" % workshop_folder_path, LOG_NAME)

	var workshop_dir := Directory.new()
	var workshop_dir_open_error := workshop_dir.open(workshop_folder_path)
	if not workshop_dir_open_error == OK:
		ModLoaderLog.error("Can't open workshop folder %s (Error: %s)" % [workshop_folder_path, workshop_dir_open_error], LOG_NAME)
		return -1
	var workshop_dir_listdir_error := workshop_dir.list_dir_begin()
	if not workshop_dir_listdir_error == OK:
		ModLoaderLog.error("Can't read workshop folder %s (Error: %s)" % [workshop_folder_path, workshop_dir_listdir_error], LOG_NAME)
		return -1

	# Loop 1: Workshop folders
	while true:
		# Get the next workshop item folder
		var item_dir := workshop_dir.get_next()
		var item_path := workshop_dir.get_current_dir() + "/" + item_dir

		ModLoaderLog.info("Checking workshop item path: \"%s\"" % item_path, LOG_NAME)

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
	var unpacked_mods_path := _ModLoaderPath.get_unpacked_mods_dir_path()

	var dir := Directory.new()
	if not dir.open(unpacked_mods_path) == OK:
		ModLoaderLog.error("Can't open unpacked mods folder %s." % unpacked_mods_path, LOG_NAME)
		return -1
	if not dir.list_dir_begin() == OK:
		ModLoaderLog.error("Can't read unpacked mods folder %s." % unpacked_mods_path, LOG_NAME)
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

		if (
			# Only check directories
			not dir.current_is_dir()
			# Ignore self, parent and hidden directories
			or mod_dir_name.begins_with(".")
		):
			continue

		if ModLoaderStore.ml_options.disabled_mods.has(mod_dir_name):
			ModLoaderLog.info("Skipped setting up mod: \"%s\"" % mod_dir_name, LOG_NAME)
			continue

		# Init the mod data
		_init_mod_data(mod_dir_name)
		unpacked_mods_count += 1

	dir.list_dir_end()
	return unpacked_mods_count


# Load mod config JSONs from res://configs
func _load_mod_configs() -> void:
	var found_configs_count := 0
	var configs_path := _ModLoaderPath.get_path_to_configs()

	for dir_name in ModLoaderStore.mod_data:
		var json_path := configs_path.plus_file(dir_name + ".json")
		var mod_config := _ModLoaderFile.get_json_as_dict(json_path)

		ModLoaderLog.debug("Config JSON: Looking for config at path: %s" % json_path, LOG_NAME)

		if mod_config.size() > 0:
			found_configs_count += 1

			ModLoaderLog.info("Config JSON: Found a config file: '%s'" % json_path, LOG_NAME)
			ModLoaderLog.debug_json_print("Config JSON: File data: ", mod_config, LOG_NAME)

			# Check `load_from` option. This lets you specify the name of a
			# different JSON file to load your config from. Must be in the same
			# dir. Means you can have multiple config files for a single mod
			# and switch between them quickly. Should include ".json" extension.
			# Ignored if the filename matches the mod ID, or is empty
			if mod_config.has("load_from"):
				var new_path: String = mod_config.load_from
				if not new_path == "" and not new_path == str(dir_name, ".json"):
					ModLoaderLog.info("Config JSON: Following load_from path: %s" % new_path, LOG_NAME)
					var new_config := _ModLoaderFile.get_json_as_dict(configs_path + new_path)
					if new_config.size() > 0:
						mod_config = new_config
						ModLoaderLog.info("Config JSON: Loaded from custom json: %s" % new_path, LOG_NAME)
						ModLoaderLog.debug_json_print("Config JSON: File data:", mod_config, LOG_NAME)
					else:
						ModLoaderLog.error("Config JSON: ERROR - Could not load data via `load_from` for %s, at path: %s" % [dir_name, new_path], LOG_NAME)

			ModLoaderStore.mod_data[dir_name].config = mod_config

	if found_configs_count > 0:
		ModLoaderLog.success("Config JSON: Loaded %s config(s)" % found_configs_count, LOG_NAME)
	else:
		ModLoaderLog.info("Config JSON: No mod configs were found", LOG_NAME)


# Add a mod's data to mod_data.
# The mod_folder_path is just the folder name that was added to UNPACKED_DIR,
# which depends on the name used in a given mod ZIP (eg "mods-unpacked/Folder-Name")
func _init_mod_data(mod_folder_path: String) -> void:
	# The file name should be a valid mod id
	var dir_name := _ModLoaderPath.get_file_name_from_path(mod_folder_path, false, true)

	# Path to the mod in UNPACKED_DIR (eg "res://mods-unpacked/My-Mod")
	var local_mod_path := _ModLoaderPath.get_unpacked_mods_dir_path().plus_file(dir_name)

	var mod := ModData.new(local_mod_path)
	mod.dir_name = dir_name
	var mod_overwrites_path := mod.get_optional_mod_file_path(ModData.optional_mod_files.OVERWRITES)
	mod.is_overwrite = _ModLoaderFile.file_exists(mod_overwrites_path)
	mod.is_locked = true if dir_name in ModLoaderStore.ml_options.locked_mods else false
	ModLoaderStore.mod_data[dir_name] = mod

	# Get the mod file paths
	# Note: This was needed in the original version of this script, but it's
	# not needed anymore. It can be useful when debugging, but it's also an expensive
	# operation if a mod has a large number of files (eg. Brotato's Invasion mod,
	# which has ~1,000 files). That's why it's disabled by default
	if ModLoaderStore.DEBUG_ENABLE_STORING_FILEPATHS:
		mod.file_paths = _ModLoaderPath.get_flat_view_dict(local_mod_path)


# Instance every mod and add it as a node to the Mod Loader.
# Runs mods in the order stored in mod_load_order.
func _init_mod(mod: ModData) -> void:
	var mod_main_path := mod.get_required_mod_file_path(ModData.required_mod_files.MOD_MAIN)
	var mod_overwrites_path := mod.get_optional_mod_file_path(ModData.optional_mod_files.OVERWRITES)

	# If the mod contains overwrites initialize the overwrites script
	if mod.is_overwrite:
		ModLoaderLog.debug("Overwrite script detected -> %s" % mod_overwrites_path, LOG_NAME)
		var mod_overwrites_script := load(mod_overwrites_path)
		mod_overwrites_script.new()
		ModLoaderLog.debug("Initialized overwrite script -> %s" % mod_overwrites_path, LOG_NAME)

	ModLoaderLog.debug("Loading script from -> %s" % mod_main_path, LOG_NAME)
	var mod_main_script := ResourceLoader.load(mod_main_path)
	ModLoaderLog.debug("Loaded script -> %s" % mod_main_script, LOG_NAME)

	var mod_main_instance: Node = mod_main_script.new(self)
	mod_main_instance.name = mod.manifest.get_mod_id()

	ModLoaderStore.saved_mod_mains[mod_main_path] = mod_main_instance

	ModLoaderLog.debug("Adding child -> %s" % mod_main_instance, LOG_NAME)
	add_child(mod_main_instance, true)


# Call the disable method in every mod if present.
# This way developers can implement their own disable handling logic,
# that is needed if there are actions that are not done through the Mod Loader.
func _disable_mod(mod: ModData) -> void:
	if mod == null:
		ModLoaderLog.error("The provided ModData does not exist", LOG_NAME)
		return
	var mod_main_path := mod.get_required_mod_file_path(ModData.required_mod_files.MOD_MAIN)

	if not ModLoaderStore.saved_mod_mains.has(mod_main_path):
		ModLoaderLog.error("The provided Mod %s has no saved mod main" % mod.manifest.get_mod_id(), LOG_NAME)
		return

	var mod_main_instance: Node = ModLoaderStore.saved_mod_mains[mod_main_path]
	if mod_main_instance.has_method("_disable"):
		mod_main_instance._disable()
	else:
		ModLoaderLog.warning("The provided Mod %s does not have a \"_disable\" method" % mod.manifest.get_mod_id(), LOG_NAME)

	ModLoaderStore.saved_mod_mains.erase(mod_main_path)
	_ModLoaderScriptExtension.remove_all_extensions_of_mod(mod)

	remove_child(mod_main_instance)


# Deprecated
# =============================================================================

func install_script_extension(child_script_path:String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.install_script_extension", "ModLoaderMod.install_script_extension", "6.0.0")
	ModLoaderMod.install_script_extension(child_script_path)


func register_global_classes_from_array(new_global_classes: Array) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.register_global_classes_from_array", "ModLoaderMod.register_global_classes_from_array", "6.0.0")
	ModLoaderMod.register_global_classes_from_array(new_global_classes)


func add_translation_from_resource(resource_path: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.add_translation_from_resource", "ModLoaderMod.add_translation_from_resource", "6.0.0")
	ModLoaderMod.add_translation_from_resource(resource_path)


func append_node_in_scene(modified_scene: Node, node_name: String = "", node_parent = null, instance_path: String = "", is_visible: bool = true) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.append_node_in_scene", "ModLoaderMod.append_node_in_scene", "6.0.0")
	ModLoaderMod.append_node_in_scene(modified_scene, node_name, node_parent, instance_path, is_visible)


func save_scene(modified_scene: Node, scene_path: String) -> void:
	ModLoaderDeprecated.deprecated_changed("ModLoader.save_scene", "ModLoaderMod.save_scene", "6.0.0")
	ModLoaderMod.save_scene(modified_scene, scene_path)


func get_mod_config(mod_dir_name: String = "", key: String = "") -> Dictionary:
	ModLoaderDeprecated.deprecated_changed("ModLoader.get_mod_config", "ModLoaderConfig.get_mod_config", "6.0.0")
	return ModLoaderConfig.get_mod_config(mod_dir_name, key)


func deprecated_direct_access_UNPACKED_DIR() -> String:
	ModLoaderDeprecated.deprecated_message("The const \"UNPACKED_DIR\" was removed, use \"ModLoaderMod.get_unpacked_dir()\" instead", "6.0.0")
	return _ModLoaderPath.get_unpacked_mods_dir_path()
