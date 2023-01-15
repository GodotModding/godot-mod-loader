# ModLoader - A mod loader for GDScript
#
# Version 2.0.0
#
# Written in 2021 by harrygiel <harrygiel@gmail.com>,
# in 2021 by Mariusz Chwalba <mariusz@chwalba.net>,
# in 2022 by Vladimir Panteleev <git@cy.md>
# in 2023 by KANA <kai@kana.jetzt>
# in 2023 by Darkly77
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

# Enables logging messages made with dev_log. Usually these are enabled with the
# command line arg `--mod-dev`, but you can also enable them this way if you're
# debugging in the editor
const DEBUG_ENABLE_DEV_LOG = false

# If true, a complete array of filepaths is stored for each mod. This is
# disabled by default because the operation can be very expensive, but may
# be useful for debugging
const DEBUG_ENABLE_STORING_FILEPATHS = false

# Path to the mod log file
# Find this log here: %appdata%/GAMENAME/mods.log
const MOD_LOG_PATH = "user://mods.log"

# This is where mod ZIPs are unpacked to
const UNPACKED_DIR = "res://mods-unpacked/"

# These 2 files are always required by mods.
# mod_main.gd = The main init file for the mod
# manifest.json = Meta data for the mod, including its dependancies
const REQUIRED_MOD_FILES = ["mod_main.gd", "manifest.json"]

# Required keys in a mod's manifest.json file
const REQUIRED_MANIFEST_KEYS_ROOT = [
	"name",
	"version_number",
	"website_url",
	"description",
	"dependencies",
	"extra",
]

# Required keys in manifest's `json.extra.godot`
const REQUIRED_MANIFEST_KEYS_EXTRA = [
	"id",
	"incompatibilities",
	"authors",
	"compatible_game_version",
]

# Set to true to require using "--enable-mods" to enable them
const REQUIRE_CMD_LINE = false

# Prefix for this file when using mod_log or dev_log
const LOG_NAME = "ModLoader"


# Vars
# =============================================================================

# Stores data for every found/loaded mod
var mod_data = {}

# Order for mods to be loaded in, set by `_get_load_order`
var mod_load_order = []

# Override for the path mods are loaded from. Only gets set if the CLI arg
# --mods-path is used. This can be tested in the editor via:
# Project Settings > Display> Editor > Main Run Args
var os_mods_path_override = ""

# Any mods that are missing their dependancies are added to this
# Example property: "mod_id": ["dep_mod_id_0", "dep_mod_id_2"]
var mod_missing_dependencies = {}

# Things to keep to ensure they are not garbage collected (used by `saveScene`)
var _savedObjects = []


# Main
# =============================================================================

func _init():
	# if mods are not enabled - don't load mods
	if REQUIRE_CMD_LINE && (!_check_cmd_line_arg("--enable-mods")):
		return

	# check if we want to use a different mods path that is provided as a command line argument
	var cmd_line_mod_path = _get_cmd_line_arg("--mods-path")
	if cmd_line_mod_path != "":
		os_mods_path_override = cmd_line_mod_path
		mod_log("The path mods are loaded from has been changed via the CLI arg `--mods-path`, to: " + cmd_line_mod_path, LOG_NAME)

	# Loop over "res://mods" and add any mod zips to the unpacked virtual
	# directory (UNPACKED_DIR)
	_load_mod_zips()
	mod_log("DONE: Unziped all Mods", LOG_NAME)

	# Loop over UNPACKED_DIR. This triggers _init_mod_data for each mod
	# directory, which adds their data to mod_data.
	_setup_mods()

	# Loop over all loaded mods via their entry in mod_data. Verify that they
	# have all the required files (REQUIRED_MOD_FILES), load their meta data
	# (from their manifest.json file), and verify that the meta JSON has all
	# required properties (REQUIRED_META_TAGS)
	for mod_id in mod_data:
		var mod = mod_data[mod_id]

		# Verify files
		_check_mod_files(mod_id)
		if(!mod.is_loadable):
			continue

		# Load meta data into mod_data
		_load_meta_data(mod_id)
		if(!mod.is_loadable):
			continue

	mod_log("DONE: Loaded all meta data", LOG_NAME)

	# Run dependency checks after loading meta_data. If a mod depends on another
	# mod that hasn't been loaded, that dependent mod won't be loaded.
	for mod_id in mod_data:
		if(!mod_data[mod_id].is_loadable):
			continue
		_check_dependencies(mod_id, mod_data[mod_id].meta_data.dependencies)

	# Sort mod_load_order by the importance score of the mod
	_get_load_order()

	# Log mod order
	var mod_i = 1
	for mod in mod_load_order: # mod === mod_data
		dev_log(str("mod_load_order -> ", mod_i, ") ", mod.dir), LOG_NAME)
		mod_i += 1

	# Instance every mod and add it as a node to the Mod Loader
	for mod in mod_load_order:
		mod_log(str("Initializing -> ", mod.meta_data.extra.godot.id), LOG_NAME)
		_init_mod(mod)

	dev_log(str("mod_data: ", JSON.print(mod_data, '   ')), LOG_NAME)

	mod_log("DONE: Completely finished loading mods", LOG_NAME)


# Log developer info. Has to be enabled, either with the command line arg
# `--mod-dev--mod-dev`, or by temporarily enabling DEBUG_ENABLE_DEV_LOG
func dev_log(text:String, mod_name:String = "", pretty:bool = false):
	if DEBUG_ENABLE_DEV_LOG || (_check_cmd_line_arg("--mod-dev")):
		mod_log(text, mod_name, pretty)


# Log info for a mod. Accepts the mod name as the 2nd arg, which prefixes
# the logged string with "{mod_name}: "
func mod_log(text:String, mod_name:String = "Unknown-Mod", pretty:bool = false)->void:
	# Prefix with "{mod_name}: "
	var prefix = mod_name + ": "

	var date_time = Time.get_datetime_dict_from_system()

	# Add leading zeroes if needed
	var hour = date_time.hour
	var mins = date_time.minute
	var secs = date_time.second
	hour = hour if str(hour).length() > 1 else str("0", hour)
	mins = mins if str(mins).length() > 1 else str("0", mins)
	secs = secs if str(secs).length() > 1 else str("0", secs)

	var date_time_string = str(date_time.day,'.',date_time.month,'.',date_time.year,' - ', hour,':',mins,':',secs)

	print(str(date_time_string,'   ', prefix, text))

	var log_file = File.new()

	if(!log_file.file_exists(MOD_LOG_PATH)):
		log_file.open(MOD_LOG_PATH, File.WRITE)
		log_file.store_string("\n" + str(date_time_string,'   ', 'Created mod.log!'))
		log_file.close()

	var _error = log_file.open(MOD_LOG_PATH, File.READ_WRITE)
	if(_error):
		print(_error)
		return
	log_file.seek_end()
	if(pretty):
		log_file.store_string("\n" + str(date_time_string,'   ', prefix, JSON.print(text, " ")))
	else:
		log_file.store_string("\n" + str(date_time_string,'   ', prefix, text))
	log_file.close()


func _load_mod_zips():
	# Path to the games mod folder
	var game_mod_folder_path = _get_mod_folder_dir()

	var dir = Directory.new()
	if dir.open(game_mod_folder_path) != OK:
		mod_log("Can't open mod folder %s." % game_mod_folder_path, LOG_NAME)
		return
	if dir.list_dir_begin() != OK:
		mod_log("Can't read mod folder %s." % game_mod_folder_path, LOG_NAME)
		return

	var has_shown_editor_warning = false

	# Get all zip folders inside the game mod folder
	while true:
		# Get the next file in the directory
		var mod_zip_file_name = dir.get_next()

		# If there is no more file
		if mod_zip_file_name == '':
			# Stop loading mod zip files
			break

		# Ignore files that aren't ZIP or PCK
		if mod_zip_file_name.get_extension() != "zip" && mod_zip_file_name.get_extension() != "pck":
			continue

		# If the current file is a directory
		if dir.current_is_dir():
			# Go to the next file
			continue

		var mod_folder_path = game_mod_folder_path.plus_file(mod_zip_file_name)
		var mod_folder_global_path = ProjectSettings.globalize_path(mod_folder_path)
		var is_mod_loaded_success = ProjectSettings.load_resource_pack(mod_folder_global_path, false)

		# Notifies developer of an issue with Godot, where using `load_resource_pack`
		# in the editor WIPES the entire res:// directory the first time you use it:
		# https://github.com/godotengine/godot/issues/19815
		# https://github.com/godotengine/godot/issues/16798
		if OS.has_feature("editor") && !has_shown_editor_warning:
			mod_log(str(
				"WARNING: Loading files with `load_resource_pack` will WIPE the entire virtual res:// directory. ",
				"If you have any unpacked mods in ", UNPACKED_DIR, ", they will not be loaded. ",
				"Please unpack your mod ZIPs instead, and add them to ", UNPACKED_DIR), LOG_NAME)
			has_shown_editor_warning = true

		dev_log(str("Found mod ZIP: ", mod_folder_global_path), LOG_NAME)

		# If there was an error loading the mod zip file
		if !is_mod_loaded_success:
			# Log the error and continue with the next file
			mod_log(str(mod_zip_file_name, " failed to load."), LOG_NAME)
			continue

		# Mod successfully loaded!
		mod_log(str(mod_zip_file_name, " loaded."), LOG_NAME)

	dir.list_dir_end()


func _setup_mods():
	# Path to the unpacked mods folder
	var unpacked_mods_path = UNPACKED_DIR

	var dir = Directory.new()
	if dir.open(unpacked_mods_path) != OK:
		mod_log("Can't open unpacked mods folder %s." % unpacked_mods_path, LOG_NAME)
		return
	if dir.list_dir_begin() != OK:
		mod_log("Can't read unpacked mods folder %s." % unpacked_mods_path, LOG_NAME)
		return

	# Get all unpacked mod dirs
	while true:
		# Get the next file in the directory
		var mod_dir_name = dir.get_next()

		# If there is no more file
		if mod_dir_name == '':
			# Stop loading mod zip files
			break

		# Only check directories
		if !dir.current_is_dir():
			continue

		if mod_dir_name == "." || mod_dir_name == "..":
			continue

		# Init the mod data
		_init_mod_data(mod_dir_name)

	dir.list_dir_end()


# Add a mod's data to mod_data.
# The mod_folder_path is just the folder name that was added to UNPACKED_DIR,
# which depends on the name used in a given mod ZIP (eg "mods-unpacked/Folder-Name")
func _init_mod_data(mod_folder_path):
	# The file name should be a valid mod id
	var mod_id = _get_file_name(mod_folder_path, false, true)

	# Path to the mod in UNPACKED_DIR (eg "res://mods-unpacked/My-Mod")
	var local_mod_path = str(UNPACKED_DIR, mod_id)

	mod_data[mod_id] = {}
	mod_data[mod_id].file_paths = []
	mod_data[mod_id].required_files_path = {}
	mod_data[mod_id].is_loadable = true
	mod_data[mod_id].importance = 0
	mod_data[mod_id].dir = local_mod_path

	if DEBUG_ENABLE_STORING_FILEPATHS:
		# Get the mod file paths
		# Note: This was needed in the original version of this script, but it's
		# not needed anymore. It can be useful when debugging, but it's also an expensive
		# operation if a mod has a large number of files (eg. Brotato's Invasion mod,
		# which has ~1,000 files). That's why it's disabled by default
		mod_data[mod_id].file_paths = get_flat_view_dict(local_mod_path)

	for required_filename in REQUIRED_MOD_FILES:
		# Eg:
		# "mod_main.gd": local_mod_path + "/mod_main.gd",
		# "manifest.json": local_mod_path + "/manifest.json"
		mod_data[mod_id].required_files_path[required_filename] = local_mod_path + "/" + required_filename


# Make sure the required mod files are there
func _check_mod_files(mod_id):

	var file_check = File.new()
	var mod = mod_data[mod_id]

	for required_filename in REQUIRED_MOD_FILES:
		var filepath = mod_data[mod_id].required_files_path[required_filename]

		if !file_check.file_exists(filepath):
			mod_log(str("ERROR - ", mod_id, " is missing a required file: ", required_filename), LOG_NAME)
			mod.is_loadable = false

	if !mod.is_loadable:
		mod_log(str("ERROR - ", mod_id, " cannot be loaded due to missing required files"), LOG_NAME)


# Load meta data into mod_data, from a mod's manifest.json file
func _load_meta_data(mod_id):
	mod_log(str("Loading meta_data (manifest.json) for -> ", mod_id), LOG_NAME)
	var mod = mod_data[mod_id]

	# Load meta data file
	var meta_path = mod.required_files_path["manifest.json"]
	var meta_data = _get_json_as_dict(meta_path)

	dev_log(str(mod_id, " loaded manifest data -> ", meta_data), LOG_NAME)

	# Check if the manifest data has all required fields
	var missing_fields = _check_meta_file(meta_data)
	if(missing_fields.size() > 0):
		for missing_field in missing_fields:
			mod_log(str("ERROR - ", mod_id, " - Missing a required field in manifest.json: '", missing_field, "'"), LOG_NAME)
		# Flag mod - so it's not loaded later
		mod.is_loadable = false
		# Continue with the next mod
		return

	# Add the meta data to the mod
	mod.meta_data = meta_data


# Ensure manifest.json has all required keys
func _check_meta_file(meta_data):
	var missing_keys_root = REQUIRED_MANIFEST_KEYS_ROOT.duplicate()
	var missing_keys_extra = REQUIRED_MANIFEST_KEYS_EXTRA.duplicate()

	for key in meta_data:
		if(REQUIRED_MANIFEST_KEYS_ROOT.has(key)):
			# remove the entry from missing fields if it is there
			missing_keys_root.erase(key)

	if meta_data.has("extra") && meta_data.extra.has("godot"):
		for godot_key in meta_data.extra.godot:
			if(REQUIRED_MANIFEST_KEYS_EXTRA.has(godot_key)):
				missing_keys_extra.erase(godot_key)

	# Combine both arrays, and reformat the "extra" keys
	var missing_fields = missing_keys_root
	if missing_keys_extra.size() > 0:
		for godot_key in missing_keys_extra:
			var formatted_key = str("extra.godot.", godot_key)
			missing_fields.push_back(formatted_key)

	return missing_fields


# Run dependency checks on a mod, checking any dependencies it lists in its
# meta_data (ie. its manifest.json file). If a mod depends on another mod that
# hasn't been loaded, the dependent mod won't be loaded.
func _check_dependencies(mod_id:String, deps:Array):
	dev_log(str("Checking dependencies - mod_id: ", mod_id, " dependencies: ", deps), LOG_NAME)

	# loop through each dependency
	for dependency_id in deps:
		# check if dependency is missing
		if(!mod_data.has(dependency_id)):
			_handle_missing_dependency(mod_id, dependency_id)
			continue

		var dependency = mod_data[dependency_id]
		var dependency_meta_data = mod_data[dependency_id].meta_data

		# Init the importance score if it's missing

		# increase importance score by 1
		dependency.importance = dependency.importance + 1
		dev_log(str("Dependency -> ", dependency_id, " importance -> ", dependency.importance), LOG_NAME)

		# check if dependency has dependencies
		if(dependency_meta_data.dependencies.size() > 0):
			_check_dependencies(dependency_id, dependency_meta_data.dependencies)


# Handle missing dependencies: Sets `is_loadable` to false and logs an error
func _handle_missing_dependency(mod_id, dependency_id):
	mod_log(str("ERROR - missing dependency - mod_id -> ", mod_id, " dependency_id -> ", dependency_id), LOG_NAME)
	# if mod is not present in the missing dependencies array
	if(!mod_missing_dependencies.has(mod_id)):
		# add it
		mod_missing_dependencies[mod_id] = []

	mod_missing_dependencies[mod_id].append(dependency_id)
	# Flag the mod so it's not loaded later
	mod_data[mod_id].is_loadable = false


# Get the load order of mods, using a custom sorter
func _get_load_order():
	var mod_data_array = mod_data.values()

	# Add loadable mods to the mod load order array
	for mod in mod_data_array:
		if(mod.is_loadable):
			mod_load_order.append(mod)

	# Sort mods by the importance value
	mod_load_order.sort_custom(self, "_compare_Importance")


# Custom sorter that orders mods by important
func _compare_Importance(a, b):
	# if true a -> b
	# if false b -> a
	if(a.importance > b.importance):
		return true
	else:
		return false


# Instance every mod and add it as a node to the Mod Loader.
# Runs mods in the order stored in mod_load_order.
func _init_mod(mod):
	var mod_main_path = mod.required_files_path["mod_main.gd"]
	dev_log(str("Loading script from -> ", mod_main_path), LOG_NAME)
	var mod_main_script = ResourceLoader.load(mod_main_path)
	dev_log(str("Loaded script -> ", mod_main_script), LOG_NAME)
	var mod_main_instance = mod_main_script.new(self)
	mod_main_instance.name = mod.meta_data.extra.godot.id
	dev_log(str("Adding child -> ", mod_main_instance), LOG_NAME)
	add_child(mod_main_instance, true)



# Utils (Mod Loader)
# =============================================================================

# Util functions used in the mod loading process

# Check if the provided command line argument was present when launching the game
func _check_cmd_line_arg(argument) -> bool:
	for arg in OS.get_cmdline_args():
		if arg == argument:
			return true

	return false

# Get the command line argument value if present when launching the game
func _get_cmd_line_arg(argument) -> String:
	for arg in OS.get_cmdline_args():
		if arg.find("=") > -1:
			var key_value = arg.split("=")
			# True if the checked argument matches a user-specified arg key
			# (eg. checking `--mods-path` will match with `--mods-path="C://mods"`
			if key_value[0] == argument:
				return key_value[1]

	return ""

# Get the path to the (packed) mods folder, ie "res://mods" or the OS's equivalent
func _get_mod_folder_dir():
	var gameInstallDirectory = OS.get_executable_path().get_base_dir()

	if OS.get_name() == "OSX":
		gameInstallDirectory = gameInstallDirectory.get_base_dir().get_base_dir().get_base_dir()

	# Fix for running the game through the Godot editor (as the EXE path would be
	# the editor's own EXE, which won't have any mod ZIPs)
	# if OS.is_debug_build():
	if OS.has_feature("editor"):
		gameInstallDirectory = "res://"

	if (os_mods_path_override != ""):
		gameInstallDirectory = os_mods_path_override	

	mod_log(str("gameInstallDirectory: ", gameInstallDirectory), LOG_NAME)

	return gameInstallDirectory.plus_file("mods")


# Parses JSON from a given file path and returns a dictionary
func _get_json_as_dict(path):
	# mod_log(str("getting JSON as dict from path -> ", path), LOG_NAME)
	var file = File.new()
	file.open(path, File.READ)
	var content = file.get_as_text()

	return JSON.parse(content).result


func _get_file_name(path, is_lower_case = true, is_no_extension = false):
	# mod_log(str("Get file name from path -> ", path), LOG_NAME)
	var file_name = path.get_file()

	if(is_lower_case):
		# mod_log(str("Get file name in lower case"), LOG_NAME)
		file_name = file_name.to_lower()

	if(is_no_extension):
		# mod_log(str("Get file name without extension"), LOG_NAME)
		var file_extension = file_name.get_extension()
		file_name = file_name.replace(str(".",file_extension), '')

	# mod_log(str("return file name -> ", file_name), LOG_NAME)
	return file_name


# Get a flat array of all files in the target directory. This was needed in the
# original version of this script, before becoming deprecated. It may still be
# used if DEBUG_ENABLE_STORING_FILEPATHS is true.
# Source: https://gist.github.com/willnationsdev/00d97aa8339138fd7ef0d6bd42748f6e
func get_flat_view_dict(p_dir = "res://", p_match = "", p_match_is_regex = false):
	var regex = null
	if p_match_is_regex:
		regex = RegEx.new()
		regex.compile(p_match)
		if not regex.is_valid():
			return []

	var dirs = [p_dir]
	var first = true
	var data = []
	while not dirs.empty():
		var dir = Directory.new()
		var dir_name = dirs.back()
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir_name == "res://":
					first = false
				# ignore hidden, temporary, or system content
				if not file_name.begins_with(".") and not file_name.get_extension() in ["tmp", "import"]:
					# If a directory, then add to list of directories to visit
					if dir.current_is_dir():
						dirs.push_back(dir.get_current_dir() + "/" + file_name)
					# If a file, check if we already have a record for the same name
					else:
						var path = dir.get_current_dir() + ("/" if not first else "") + file_name
						# grab all
						if not p_match:
							data.append(path)
						# grab matching strings
						elif not p_match_is_regex and file_name.find(p_match, 0) != -1:
							data.append(path)
						# grab matching regex
						else:
							var regex_match = regex.search(path)
							if regex_match != null:
								data.append(path)
				# Move on to the next file in this directory
				file_name = dir.get_next()
			# We've exhausted all files in this directory. Close the iterator.
			dir.list_dir_end()
	return data



# Helpers
# =============================================================================

# Helper functions to build mods

# Add a script that extends a vanilla script. `childScriptPath` should point
# to your mod's extender script, eg "MOD/extensions/singletons/utils.gd".
# Inside that extender script, it should include "extends {target}", where
# {target} is the vanilla path, eg: `extends "res://singletons/utils.gd"`.
# Note that your extender script doesn't have to follow the same directory path
# as the vanilla file, but it's good practice to do so.
func installScriptExtension(childScriptPath:String):
	# Check path to file exists
	if !File.new().file_exists(childScriptPath):
		mod_log("ERROR - The child script path '%s' does not exist" % [childScriptPath], LOG_NAME)
		return

	var childScript = ResourceLoader.load(childScriptPath)

	# Force Godot to compile the script now.
	# We need to do this here to ensure that the inheritance chain is
	# properly set up, and multiple mods can chain-extend the same
	# class multiple times.
	# This is also needed to make Godot instantiate the extended class
	# when creating singletons.
	# The actual instance is thrown away.
	childScript.new()

	var parentScript = childScript.get_base_script()
	var parentScriptPath = parentScript.resource_path
	mod_log("Installing script extension: %s <- %s" % [parentScriptPath, childScriptPath], LOG_NAME)
	childScript.take_over_path(parentScriptPath)


# Add a translation file, eg "mytranslation.en.translation". The translation
# file should have been created in Godot already: When you improt a CSV, such
# a file will be created for you.
func addTranslationFromResource(resourcePath: String):
	var translation_object = load(resourcePath)
	TranslationServer.add_translation(translation_object)
	mod_log("Added Translation from Resource", LOG_NAME)


func appendNodeInScene(modifiedScene, nodeName:String = "", nodeParent = null, instancePath:String = "", isVisible:bool = true):
	var newNode
	if instancePath != "":
		newNode = load(instancePath).instance()
	else:
		newNode = Node.instance()
	if nodeName != "":
		newNode.name = nodeName
	if isVisible == false:
		newNode.visible = false
	if nodeParent != null:
		var tmpNode = modifiedScene.get_node(nodeParent)
		tmpNode.add_child(newNode)
		newNode.set_owner(modifiedScene)
	else:
		modifiedScene.add_child(newNode)
		newNode.set_owner(modifiedScene)


func saveScene(modifiedScene, scenePath:String):
	var packed_scene = PackedScene.new()
	packed_scene.pack(modifiedScene)
	dev_log(str("packing scene -> ", packed_scene), LOG_NAME)
	packed_scene.take_over_path(scenePath)
	dev_log(str("saveScene - taking over path - new path -> ", packed_scene.resource_path), LOG_NAME)
	_savedObjects.append(packed_scene)
