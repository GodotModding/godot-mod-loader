class_name _ModLoaderModHookPacker
extends RefCounted


# This class is used to generate mod hooks on demand and pack them into a zip file.
# Currently all of the included functions are internal and should only be used by the mod loader itself.

const LOG_NAME := "ModLoader:ModHookPacker"

static var ModLoaderSetupLog: Object = load("res://addons/mod_loader/setup/setup_log.gd")
static var ModLoaderSetupUtils: Object = load("res://addons/mod_loader/setup/setup_utils.gd")

static func start() -> void:
	_decompile_and_load_if_needed()

	ModLoaderLog.info("Generating mod hooks .zip", LOG_NAME)
	var hook_pre_processor = _ModLoaderModHookPreProcessor.new()
	hook_pre_processor.process_begin()

	var mod_hook_pack_path := _ModLoaderPath.get_path_to_hook_pack()

	# Create mod hook pack path if necessary
	if not DirAccess.dir_exists_absolute(mod_hook_pack_path.get_base_dir()):
		var error := DirAccess.make_dir_recursive_absolute(mod_hook_pack_path.get_base_dir())
		if not error == OK:
			ModLoaderLog.error("Error creating the mod hook directory at %s" % mod_hook_pack_path, LOG_NAME)
			return
		ModLoaderLog.debug("Created dir at: %s" % mod_hook_pack_path, LOG_NAME)

	# Create mod hook zip
	var zip_writer := ZIPPacker.new()
	var error: Error

	if not FileAccess.file_exists(mod_hook_pack_path):
		# Clear cache if the hook pack does not exist
		_ModLoaderCache.remove_data("hooks")
		error = zip_writer.open(mod_hook_pack_path)
	else:
		# If there is a pack already, append to it
		error = zip_writer.open(mod_hook_pack_path, ZIPPacker.APPEND_ADDINZIP)
	if not error == OK:
		ModLoaderLog.error("Error (%s) writing to hooks zip, consider deleting this file: %s" % [error, mod_hook_pack_path], LOG_NAME)
		return

	ModLoaderLog.debug("Scripts requiring hooks: %s" % [ModLoaderStore.hooked_script_paths], LOG_NAME)

	var cache := _ModLoaderCache.get_data("hooks")
	var cached_script_paths: Dictionary = {} if cache.is_empty() or not cache.has("hooked_script_paths") else cache.hooked_script_paths
	if cached_script_paths == ModLoaderStore.hooked_script_paths:
		ModLoaderLog.info("Scripts are already processed according to cache, skipping process.", LOG_NAME)
		zip_writer.close()
		return

	var new_hooks_created := false
	# Get all scripts that need processing
	for path in ModLoaderStore.hooked_script_paths.keys():
		var method_mask: Array[String] = []
		method_mask.assign(ModLoaderStore.hooked_script_paths[path])
		var processed_source_code := hook_pre_processor.process_script_verbose(path, false, method_mask)

		# Skip writing to the zip if no new hooks were created for this script
		if not hook_pre_processor.script_paths_hooked.has(path):
			ModLoaderLog.debug("No new hooks were created in \"%s\", skipping writing to hook pack." % path, LOG_NAME)
			continue

		var script_path: String = path.trim_prefix("res://")
		zip_writer.start_file(script_path)
		zip_writer.write_file(processed_source_code.to_utf8_buffer())
		zip_writer.close_file()

		if FileAccess.file_exists(path + ".remap"):
			var remap_file = FileAccess.open(path + ".remap", FileAccess.READ)
			var remap_content = remap_file.get_as_text()
			remap_file.close()
			zip_writer.start_file(script_path + ".remap")
			zip_writer.write_file(remap_content.to_utf8_buffer())
			zip_writer.close_file()

		ModLoaderLog.debug("Hooks created for script: %s" % path, LOG_NAME)
		new_hooks_created = true

	if new_hooks_created:
		_ModLoaderCache.update_data("hooks", {"hooked_script_paths": ModLoaderStore.hooked_script_paths})
		_ModLoaderCache.save_to_file()
		ModLoader.new_hooks_created.emit()

	zip_writer.close()


static func _decompile_and_load_if_needed() -> bool:
	var hooked_scripts := ModLoaderStore.hooked_script_paths
	var scripts_to_decompile: Array[String] = []

	for path: String in hooked_scripts.keys():
		# if actual .gd script doesn't exist (which means it wasn't decompiled or hooked already), and there's a .gdc file instead
		if path.ends_with(".gd") and not FileAccess.file_exists(path) and FileAccess.file_exists(path + "c"):
			scripts_to_decompile.append(path)

	if not scripts_to_decompile:
		return false

	ModLoaderLog.info("Decompiling scripts before hooking: %s" % [scripts_to_decompile], LOG_NAME)


	# C:/path/to/game/game.exe
	var exe_path := OS.get_executable_path()
	# C:/path/to/game/
	var game_base_dir: String = ModLoaderSetupUtils.get_local_folder_dir()
	# C:/path/to/game/addons/mod_loader
	var mod_loader_dir: String = game_base_dir + "addons/mod_loader/"
	var gdre_path := mod_loader_dir + "vendor/GDRE/gdre_tools.exe"
	var decomp_dir := mod_loader_dir + "decomp/"
	var zip_path := decomp_dir + "inject.zip"

	if not DirAccess.dir_exists_absolute(decomp_dir):
		DirAccess.make_dir_recursive_absolute(decomp_dir)

	# can be supplied to override the exe_name
	var cli_arg_exe: String = ModLoaderSetupUtils.get_cmd_line_arg_value("--exe-name")
	# can be supplied to override the pck_name
	var cli_arg_pck: String = ModLoaderSetupUtils.get_cmd_line_arg_value("--pck-name")
	# game - or use the value of cli_arg_exe_name if there is one
	var exe: String = (
		ModLoaderSetupUtils.get_file_name_from_path(exe_path, false, true)
		if cli_arg_exe == ""
		else cli_arg_exe
	)
	# game - or use the value of cli_arg_pck_name if there is one
	# using exe_path.get_file() instead of exe_name
	# so you don't override the pck_name with the --exe-name cli arg
	# the main pack name is the same as the .exe name
	# if --main-pack cli arg is not set
	var pck: String = exe if cli_arg_pck == "" else cli_arg_pck
	
	# C:/path/to/game/game.pck
	var pck_path := game_base_dir.path_join(pck + ".pck")

	var is_embedded: bool = not FileAccess.file_exists(pck_path)
	var injection_path: String = exe_path if is_embedded else pck_path


	# Decompile scripts
	var arguments := []
	var output := []
	arguments.push_back("--headless")
	arguments.push_back("--recover=%s" % injection_path)
	for script_to_decompile in scripts_to_decompile:
		var compressed_script_path := script_to_decompile + "c"
		arguments.push_back("--include=%s" % compressed_script_path)
	arguments.push_back("--output=%s" % decomp_dir)
	ModLoaderSetupLog.debug("Script recovery started: %s %s" % [gdre_path, arguments], LOG_NAME)
	var _exit_code_recover := OS.execute(gdre_path, arguments, output)
	ModLoaderSetupLog.debug("Script recovery: %s" % output, LOG_NAME)

	# Extract remap files
	arguments.clear()
	output.clear()
	arguments.push_back("--headless")
	arguments.push_back("--extract=%s" % injection_path)
	for script_to_decompile in scripts_to_decompile:
		var remap_path := script_to_decompile + ".remap"
		arguments.push_back("--include=%s" % remap_path)
	arguments.push_back("--output=%s" % decomp_dir)
	ModLoaderSetupLog.debug("Remap extract started: %s %s" % [gdre_path, arguments], LOG_NAME)
	var _exit_code_extract := OS.execute(gdre_path, arguments, output)
	ModLoaderSetupLog.debug("Remap extract: %s" % output, LOG_NAME)


	# Create inject zip
	var zip_writer := ZIPPacker.new()
	var error: Error

	error = zip_writer.open(zip_path, ZIPPacker.APPEND_CREATE)
	if not error == OK:
		ModLoaderLog.error("Error (%s) writing to inject zip, consider deleting this file: %s" % [error, zip_path], LOG_NAME)
		DirAccess.remove_absolute(decomp_dir) # Clean up
		return false

	for script_to_decompile in scripts_to_decompile:
		var script_path := script_to_decompile.trim_prefix("res://")
		var file_path := decomp_dir + script_path

		# Script
		var script_file := FileAccess.open(file_path, FileAccess.READ)
		var script_content := script_file.get_as_text()
		script_file.close()
		zip_writer.start_file(script_path)
		zip_writer.write_file(script_content.to_utf8_buffer())
		zip_writer.close_file()
		
		# Remap
		var remap_path := file_path + ".remap"
		if FileAccess.file_exists(remap_path):
			var remap_file := FileAccess.open(remap_path, FileAccess.READ)
			var remap_content = remap_file.get_as_text().replace(".gdc", ".gd")
			remap_file.close()
			zip_writer.start_file(script_path + ".remap")
			zip_writer.write_file(remap_content.to_utf8_buffer())
			zip_writer.close_file()

	zip_writer.close()

	# Inject decompiled scripts and remaps
	ModLoaderLog.info("Injecting decompiled scripts before hooking: %s" % [scripts_to_decompile], LOG_NAME)
	var inject_success := ProjectSettings.load_resource_pack(zip_path) # TODO this returns true, but seems not to do anything ;d

	if not inject_success:
		ModLoaderLog.error("Error injecting decompiled scripts: %s" % [zip_path], LOG_NAME)

	# Clean up
	DirAccess.remove_absolute(decomp_dir)

	return inject_success
