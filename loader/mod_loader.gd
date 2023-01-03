# ModLoader - A mod loader for GDScript
#
# Written in 2021 by harrygiel <harrygiel@gmail.com>,
# in 2021 by Mariusz Chwalba <mariusz@chwalba.net>,
# in 2022 by Vladimir Panteleev <git@cy.md>
# in 2023 by KANA <kai@kana.jetzt>
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

const MOD_LOG_PATH = "user://mods.log"
const REQUIRED_MOD_FILES = ["modmain.gd", "_meta.json"]
const REQUIRED_META_TAGS = [
	"id",
	"name",
	"version",
	"compatible_game_version",
	"authors",
	"description",
]
const REQUIRE_CMD_LINE = false
var mod_data = {}
var mod_load_order = []
#	var missing_dependencies = {
#		"mod_id": ["dep_mod_id_0", "dep_mod_id_2"]
#	}
var mod_missing_dependencies = {}

func _init():
	# if mods are not enabled - don't load mods
	if REQUIRE_CMD_LINE && (!_check_cmd_line_arg("--enable-mods")):
		return

	_load_mod_zips()
	mod_log("ModLoader: Unziped all Mods")

	for mod_id in mod_data:
		var mod = mod_data[mod_id]

		# verify files
		_check_mod_files(mod_id)
		if(!mod.is_loadable):
			continue

		# load meta data into mod_data
		_load_meta_data(mod_id)
		if(!mod.is_loadable):
			continue

	# run dependency check after loading meta_data
	for mod_id in mod_data:
		_check_dependencies(mod_id, mod_data[mod_id].meta_data.dependencies)

	# Sort mod_load_order by the importance score of the mod
	_get_load_order()

	dev_log(str("ModLoader: mod_load_order -> ", JSON.print(mod_load_order, '   ')))

	# Instance every mod and add it as a node to the Mod Loader
	for mod in mod_load_order:
		mod_log(str("ModLoader: Initializing -> ", mod.meta_data.id))
		_init_mod(mod)


	dev_log(str("ModLoader: mod_data: ", JSON.print(mod_data, '   ')))

func dev_log(text:String, mod_name:String = "", pretty:bool = false):
	if(_check_cmd_line_arg("--mod-dev")):
		mod_log(text, mod_name, pretty)


# Log info for a mod. Accepts the mod name as the 2nd arg, which prefixes
# the logged string with "{mod_name}: "
func mod_log(text:String, mod_name:String = "", pretty:bool = false)->void:
	# Prefix with "{mod_name}: "
	if mod_name != "":
		text = mod_name + ": "

	var date_time = Time.get_datetime_dict_from_system()
	var date_time_string = str(date_time.day,'.',date_time.month,'.',date_time.year,' - ', date_time.hour,':',date_time.minute,':',date_time.second)

	print(str(date_time_string,'   ', text))

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
		log_file.store_string("\n" + str(date_time_string,'   ', JSON.print(text, " ")))
	else:
		log_file.store_string("\n" + str(date_time_string,'   ', text))
	log_file.close()

func _load_mod_zips():
	# Path to the games mod folder
	var game_mod_folder_path = _get_mod_folder_dir()

	var dir = Directory.new()
	if dir.open(game_mod_folder_path) != OK:
		mod_log("ModLoader: Can't open mod folder %s." % game_mod_folder_path)
		return
	if dir.list_dir_begin() != OK:
		mod_log("ModLoader: Can't read mod folder %s." % game_mod_folder_path)
		return

	# Get all zip folders inside the game mod folder
	while true:
		# Get the next file in the directory
		var mod_zip_file_name = dir.get_next()
		# If there is no more file
		if mod_zip_file_name == '':
			# Stop loading mod zip files
			break

		# If the current file is a directory
		if dir.current_is_dir():
			# Go to the next file
			continue

		var mod_folder_path = game_mod_folder_path.plus_file(mod_zip_file_name)
		var mod_folder_global_path = ProjectSettings.globalize_path(mod_folder_path)
		var is_mod_loaded_success = ProjectSettings.load_resource_pack(mod_folder_global_path, true)

		# If there was an error loading the mod zip file
		if !is_mod_loaded_success:
			# Log the error and continue with the next file
			mod_log(str("ModLoader: ", mod_zip_file_name, "failed to load."))
			continue

		# Mod successfully loaded!
		mod_log(str("ModLoader: ", mod_zip_file_name, " loaded."))

		# Init the mod data
		_init_mod_data(mod_folder_path)

	dir.list_dir_end()

func _init_mod_data(mod_folder_path):
		# The file name should be a valid mod id
		var mod_id = _get_file_name(mod_folder_path, false, true)

		mod_data[mod_id] = {}
		mod_data[mod_id].file_paths = []
		mod_data[mod_id].required_files_path = {}
		mod_data[mod_id].is_loadable = true
		mod_data[mod_id].importance = 0

		# Get the mod file paths
		var local_mod_path = str("res://", mod_id)
		mod_data[mod_id].file_paths = get_flat_view_dict(local_mod_path)

# Make sure the required mod files are there
func _check_mod_files(mod_id):
	# Loop through each mod
	var found_files =  []

	# Get the file paths of the current mod
	var mod = mod_data[mod_id]
	var file_paths = mod.file_paths

	for file_path in file_paths:
		var file_name = file_path.get_file().to_lower()

		# Check if it is in the required_files array
		if(REQUIRED_MOD_FILES.has(file_name)):
			# Check if it is not in the root of the mod folder
			if(!_check_file_is_in_root(file_path, file_name)):
				mod_log(str("ModLoader: ERROR - ", mod_id, " required file ", file_name, " is not at the root of the mod folder."))
				mod.is_loadable = false
				# We can break the loop early if a required file is in the wrong location
				break

			# If the file is required add it to found files
			found_files.append(file_name)
			# Add a key to required files dict
			mod.required_files_path[_get_file_name(file_path, true, true)] = file_path

	if(REQUIRED_MOD_FILES.size() == found_files.size()):
		dev_log(str("ModLoader: ", mod_id, " all required Files found."))
	else:
		# Don't show this error if the "required file not in root" error is shown before
		if(!mod.has("is_loadable") || mod.is_loadable):
			# Flag mods with missing files so they don't get loaded later
			mod.is_loadable = false
			mod_log(str("ModLoader: ERROR - only found ", found_files, " but this files are required -> ", REQUIRED_MOD_FILES))

# TODO: Make it possible to have required files in different locations - not just the root
func _check_file_is_in_root(path, file_name):
	var path_split = path.split("/")

	if(path_split[3].to_lower() == file_name):
		return true
	else:
		return false

# Load meta data into mod_data
func _load_meta_data(mod_id):
	mod_log(str("ModLoader: Loading meta_data for -> ", mod_id))
	var mod = mod_data[mod_id]

	# Load meta data file
	var meta_path = str("res://",mod_id,"/_meta.json")
	var meta_data = _get_json_as_dict(meta_path)

	dev_log(str("ModLoader: ", mod_id, " loaded meta data -> ", meta_data))

	# Check if the meta data has all required fields
	var missing_fields = _check_meta_file(meta_data)
	if(missing_fields.size() > 0):
		mod_log(str("ModLoader: ERROR - ", mod_id, " ", missing_fields, " are required in _meta.json."))
		# Flag mod - so it's not loaded later
		mod.is_loadable = false
		# Continue with the next mod
		return

	# Add the meta data to the mod
	mod.meta_data = meta_data

# Make sure the meta file has all required fields
func _check_meta_file(meta_data):
	var missing_fields = REQUIRED_META_TAGS

	for key in meta_data:
		if(REQUIRED_META_TAGS.has(key)):
			# remove the entry from missing fields if it is there
			missing_fields.erase(key)

	return missing_fields

# Check if dependencies are there
func _check_dependencies(mod_id:String, deps:Array):
	dev_log(str("ModLoader: Checking dependencies - mod_id: ", mod_id, " dependencies: ", deps))

	# loop through each dependency
	for dependency_id in deps:
		var dependency = mod_data[dependency_id]
		var dependency_meta_data = mod_data[dependency_id].meta_data

		# Init the importance score if it's missing

		# check if dependency is missing
		if(!mod_data.has(dependency_id)):
			_handle_missing_dependency(mod_id, dependency_id)
			continue

		# increase importance score by 1
		dependency.importance = dependency.importance + 1
		dev_log(str("ModLoader: Dependency -> ", dependency_id, " importance -> ", dependency.importance))

		# check if dependency has dependencies
		if(dependency_meta_data.dependencies.size() > 0):
			_check_dependencies(dependency_id, dependency_meta_data.dependencies)

func _handle_missing_dependency(mod_id, dependency_id):
	mod_log(str("ModLoader: ERROR - missing dependency - mod_id -> ", mod_id, " dependency_id -> ", dependency_id))
	# if mod is not present in the missing dependencies array
	if(!mod_missing_dependencies.has(mod_id)):
		# add it
		mod_missing_dependencies[mod_id] = []

	mod_missing_dependencies[mod_id].append(dependency_id)
	# Flag the mod so it's not loaded later
	mod_data[mod_id].is_loadable = false

func _get_load_order():
	var mod_data_array = mod_data.values()

	# Add loadable mods to the mod load order array
	for mod in mod_data_array:
		if(mod.is_loadable):
			mod_load_order.append(mod)

	# Sort mods by the importance value
	mod_load_order.sort_custom(self, "_compare_Importance")

func _compare_Importance(a, b):
	# if true a -> b
	# if false b -> a
	if(a.importance > b.importance):
		return true
	else:
		return false

func _init_mod(mod):
		var mod_main_path = mod.required_files_path.modmain
		dev_log(str("ModLoader: Loading script from -> ", mod_main_path))
		var mod_main_script = ResourceLoader.load(mod_main_path)
		dev_log(str("ModLoader: Loaded script -> ", mod_main_script))
		var mod_main_instance = mod_main_script.new(self)
		mod_main_instance.name = mod.meta_data.id
		dev_log(str("modLoader: Adding child -> ", mod_main_instance))
		add_child(mod_main_instance, true)



#####################################################
################# MOD LOADER UTILS ##################
#####################################################

# Util functions used in the mod loading process

func _check_cmd_line_arg(argument) -> bool:
	for arg in OS.get_cmdline_args():
		if arg == argument:
			return true

	return false

func _get_mod_folder_dir():
	var gameInstallDirectory = OS.get_executable_path().get_base_dir()

	if OS.get_name() == "OSX":
		gameInstallDirectory = gameInstallDirectory.get_base_dir().get_base_dir().get_base_dir()

	# Fix for running the game through the Godot editor (as the EXE path would be
	# the editor's own EXE, which won't have any mod ZIPs)
	if OS.is_debug_build():
		gameInstallDirectory = "res://"

	mod_log(str("gameInstallDirectory: ", gameInstallDirectory))

	return gameInstallDirectory.plus_file("mods")

# Parses JSON from a given file path and returns a dictionary
func _get_json_as_dict(path):
	# mod_log(str("ModLoader: getting JSON as dict from path -> ", path))
	var file = File.new()
	file.open(path, File.READ)
	var content = file.get_as_text()

	return JSON.parse(content).result

func _get_file_name(path, is_lower_case = true, is_no_extension = false):
	# mod_log(str("ModLoader: Get file name from path -> ", path))
	var file_name = path.get_file()

	if(is_lower_case):
		# mod_log(str("ModLoader: Get file name in lower case"))
		file_name = file_name.to_lower()

	if(is_no_extension):
		# mod_log(str("ModLoader: Get file name without extension"))
		var file_extension = file_name.get_extension()
		file_name = file_name.replace(str(".",file_extension), '')

	# mod_log(str("ModLoader: return file name -> ", file_name))
	return file_name

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


#####################################################
################## MODDING HELPERS ##################
#####################################################

# Helper functions to build mods

func installScriptExtension(childScriptPath:String):
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
	mod_log("ModLoader: Installing script extension: %s <- %s" % [parentScriptPath, childScriptPath])
	childScript.take_over_path(parentScriptPath)


func addTranslationFromResource(resourcePath: String):
	var translation_object = load(resourcePath)
	TranslationServer.add_translation(translation_object)
	mod_log("ModLoader: Added Translation from Resource")

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

# Things to keep to ensure they are not garbage collected
var _savedObjects = []

func saveScene(modifiedScene, scenePath:String):
	var packed_scene = PackedScene.new()
	packed_scene.pack(modifiedScene)
	dev_log(str("ModLoader: packing scene -> ", packed_scene))
	packed_scene.take_over_path(scenePath)
	dev_log(str("ModLoader: saveScene - taking over path - new path -> ", packed_scene.resource_path))
	_savedObjects.append(packed_scene)
