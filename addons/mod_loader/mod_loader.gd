## ModLoader - A mod loader for GDScript
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


## Emitted if something is logged with [ModLoaderLog]
signal logged(entry: ModLoaderLog.ModLoaderLogEntry)
## Emitted if the [member ModData.current_config] of any mod changed.
## Use the [member ModConfig.mod_id] of the [ModConfig] to check if the config of your mod has changed.
signal current_config_changed(config: ModConfig)


const LOG_NAME := "ModLoader"


# Main
# =============================================================================

func _init() -> void:
	# Ensure the ModLoaderStore and ModLoader autoloads are in the correct position.
	_check_autoload_positions()

	# if mods are not enabled - don't load mods
	if ModLoaderStore.REQUIRE_CMD_LINE and not _ModLoaderCLI.is_running_with_command_line_arg("--enable-mods"):
		return

	# Rotate the log files once on startup. Can't be checked in utils, since it's static
	ModLoaderLog._rotate_log_file()

	# Log the autoloads order. Helpful when providing support to players
	ModLoaderLog.debug_json_print("Autoload order", _ModLoaderGodot.get_autoload_array(), LOG_NAME)

	# Log game install dir
	ModLoaderLog.info("game_install_directory: %s" % _ModLoaderPath.get_local_folder_dir(), LOG_NAME)

	if not ModLoaderStore.ml_options.enable_mods:
		ModLoaderLog.info("Mods are currently disabled", LOG_NAME)
		return

	# Load user profiles into ModLoaderStore
	var _success_user_profile_load := ModLoaderUserProfile._load()

	var mod_zip_paths := _get_mod_zip_paths()
	if OS.has_feature("editor"):
		var path := _ModLoaderPath.get_unpacked_mods_dir_path()
		for mod_dir in DirAccess.get_directories_at(path):
			var manifest_path := path.path_join(mod_dir).path_join("manifest.json")
			var manifest_dict := _ModLoaderFile.get_json_as_dict(manifest_path)
			_load_metadata(manifest_dict)
	else:
		for zip_path in mod_zip_paths:
			var manifest_dict := _ModLoaderFile.get_json_as_dict_from_zip(zip_path, "manifest.json")
			_load_metadata(manifest_dict)
	_load_mods(mod_zip_paths)
	_apply_mods()
	ModLoaderStore.is_initializing = false


func _ready():
	# Create the default user profile if it doesn't exist already
	# This should always be present unless the JSON file was manually edited
	if not ModLoaderStore.user_profiles.has("default"):
		var _success_user_profile_create := ModLoaderUserProfile.create_profile("default")

	# Update the mod_list for each user profile
	var _success_update_mod_lists := ModLoaderUserProfile._update_mod_lists()


func _exit_tree() -> void:
	# Save the cache stored in ModLoaderStore to the cache file.
	_ModLoaderCache.save_to_file()


func _load_metadata(manifest_dict: Dictionary, zip_path := ""):
	var manifest := ModManifest.new(manifest_dict)
	var mod := ModData.new(manifest.get_mod_id(), zip_path)
	ModLoaderStore.mod_data[manifest.get_mod_id()] = mod
	mod.manifest = manifest
	mod.validate_loadability()
	if not mod.is_loadable:
		ModLoaderStore.ml_options.disabled_mods.append(mod.manifest.get_mod_id())
		ModLoaderLog.error("Mod %s can't be loaded due to load errors: %s"
		% [mod.manifest.get_mod_id(), mod.load_errors], LOG_NAME)


func _load_mods(mod_zip_paths: Array[String]) -> void:
	if mod_zip_paths.is_empty():
		ModLoaderLog.info("No zipped mods provided", LOG_NAME)
		return
	var zip_data := _load_mod_zips(mod_zip_paths)
	ModLoaderLog.success("DONE: Loaded %s mod files into the virtual filesystem" % zip_data.size(), LOG_NAME)


func _apply_mods() -> void:
	ModLoaderStore.previous_mod_dirs = _ModLoaderPath.get_dir_paths_in_dir(_ModLoaderPath.get_unpacked_mods_dir_path())

	# Update active state of mods based on the current user profile
	ModLoaderUserProfile._update_disabled_mods()

	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if mod.manifest.get("config_schema") and not mod.manifest.config_schema.is_empty():
			mod.load_configs()

	ModLoaderLog.success("DONE: Loaded all mod configs", LOG_NAME)

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

		# Continue if mod is disabled
		if not mod.is_active:
			continue

		ModLoaderLog.info("Initializing -> %s" % mod.manifest.get_mod_id(), LOG_NAME)
		_init_mod(mod)

	ModLoaderLog.debug_json_print("mod data", ModLoaderStore.mod_data, LOG_NAME)

	ModLoaderLog.success("DONE: Completely finished loading mods", LOG_NAME)

	_ModLoaderScriptExtension.handle_script_extensions()

	ModLoaderLog.success("DONE: Installed all script extensions", LOG_NAME)

	_ModLoaderSceneExtension.refresh_scenes()

	_ModLoaderSceneExtension.handle_scene_extensions()

	ModLoaderLog.success("DONE: Applied all scene extensions", LOG_NAME)

	ModLoaderStore.is_initializing = false


# Internal call to reload mods
func _reload_mods() -> void:
	pass #TODO fix
	printerr("_reload_mods is currently disabled, sorry")
	#_reset_mods()
	#var mod_zip_paths := _get_mod_zip_paths()
	#_apply_mods(mod_zip_paths)


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
	var ml_options: Object = load("res://addons/mod_loader/options/options.tres").current_options
	var override_cfg_path := _ModLoaderPath.get_override_path()
	var is_override_cfg_setup :=  _ModLoaderFile.file_exists(override_cfg_path)
	# If the override file exists we assume the ModLoader was setup with the --setup-create-override-cfg cli arg
	# In that case the ModLoader will be the last entry in the autoload array
	if is_override_cfg_setup:
		ModLoaderLog.info("override.cfg setup detected, ModLoader will be the last autoload loaded.", LOG_NAME)
		return

	# If there are Autoloads that need to be before the ModLoader
	# "allow_modloader_autoloads_anywhere" in the ModLoader Options can be enabled.
	# With that only the correct order of, ModLoaderStore first and ModLoader second, is checked.
	if ml_options.allow_modloader_autoloads_anywhere:
		_ModLoaderGodot.check_autoload_order("ModLoaderStore", "ModLoader", true)
	else:
		var _pos_ml_store := _ModLoaderGodot.check_autoload_position("ModLoaderStore", 0, true)
		var _pos_ml_core := _ModLoaderGodot.check_autoload_position("ModLoader", 1, true)


func _get_mod_zip_paths() -> Array[String]:
	var zip_paths: Array[String] = []

	if ModLoaderStore.ml_options.load_from_local:
		var mods_folder_path := _ModLoaderPath.get_path_to_mods()
		# Loop over the mod zips in the "mods" directory
		zip_paths.append_array(_ModLoaderFile.get_zip_paths_in(mods_folder_path))

	if ModLoaderStore.ml_options.load_from_steam_workshop:
		# If we're using Steam workshop, loop over the workshop item directories
		zip_paths.append_array(_ModLoaderSteam.find_steam_workshop_zips())

	return zip_paths


# Add any mod zips to the unpacked virtual directory
static func _load_mod_zips(zip_paths: Array[String]) -> Dictionary:
	const URL_MOD_STRUCTURE_DOCS := "https://github.com/GodotModding/godot-mod-loader/wiki/Mod-Structure"
	var zip_data := {}

	for mod_zip_global_path in zip_paths:
		var is_mod_loaded_successfully := ProjectSettings.load_resource_pack(mod_zip_global_path, false)

		# Get the current directories inside UNPACKED_DIR
		# This array is used to determine which directory is new
		var current_mod_dirs := _ModLoaderPath.get_dir_paths_in_dir(_ModLoaderPath.get_unpacked_mods_dir_path())

		# Create a backup to reference when the next mod is loaded
		var current_mod_dirs_backup := current_mod_dirs.duplicate()

		# Remove all directory paths that existed before, leaving only the one added last
		for previous_mod_dir in ModLoaderStore.previous_mod_dirs:
			current_mod_dirs.erase(previous_mod_dir)

		# If the mod zip is not structured correctly, it may not be in the UNPACKED_DIR.
		if current_mod_dirs.is_empty():
			ModLoaderLog.fatal(
				"The mod zip at path \"%s\" does not have the correct file structure. For more information, please visit \"%s\"."
				% [mod_zip_global_path, URL_MOD_STRUCTURE_DOCS],
				LOG_NAME
			)
			continue

		# The key is the mod_id of the latest loaded mod, and the value is the path to the zip file
		zip_data[current_mod_dirs[0].get_slice("/", 3)] = mod_zip_global_path

		# Update previous_mod_dirs in ModLoaderStore to use for the next mod
		ModLoaderStore.previous_mod_dirs = current_mod_dirs_backup

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

		# Report the loading status
		var mod_zip_file_name := mod_zip_global_path.get_file()
		if not is_mod_loaded_successfully:
			ModLoaderLog.error("%s failed to load." % mod_zip_file_name, LOG_NAME)
			continue

		ModLoaderLog.success("%s loaded." % mod_zip_file_name, LOG_NAME)

	return zip_data


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
	var mod_main_script: GDScript = ResourceLoader.load(mod_main_path)
	ModLoaderLog.debug("Loaded script -> %s" % mod_main_script, LOG_NAME)

	var mod_main_instance: Node = mod_main_script.new()
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
