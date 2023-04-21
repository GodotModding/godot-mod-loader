class_name ModLoaderSteam
extends Node

const LOG_NAME := "ModLoader:ThirdParty:Steam"

# Methods related to Steam and the Steam Workshop


# Get the path to the Steam workshop folder. Only works for Steam games, as it
# traverses directories relative to where a Steam game and its workshop content
# would be installed. Based on code by Blobfish (developer of Brotato).
# For reference, these are the paths of a Steam game and its workshop folder:
#   GAME     = Steam/steamapps/common/GameName
#   WORKSHOP = Steam/steamapps/workshop/content/AppID
# Eg. Brotato:
#   GAME     = Steam/steamapps/common/Brotato
#   WORKSHOP = Steam/steamapps/workshop/content/1942280
static func get_path_to_workshop() -> String:
	if ModLoaderStore.ml_options.override_path_to_workshop:
		return ModLoaderStore.ml_options.override_path_to_workshop

	var game_install_directory := _ModLoaderPath.get_local_folder_dir()
	var path := ""

	# Traverse up to the steamapps directory (ie. `cd ..\..\` on Windows)
	var path_array := game_install_directory.split("/")
	path_array.resize(path_array.size() - 2)

	# Reconstruct the path, now that it has "common/GameName" removed
	path = "/".join(path_array)

	# Append the workgame's workshop path
	path = path.plus_file("workshop/content/" + _get_steam_app_id())

	return path


# Gets the steam app ID from steam_data.json, which should be in the root
# directory (ie. res://steam_data.json). This file is used by Godot Workshop
# Utility (GWU), which was developed by Brotato developer Blobfish:
# https://github.com/thomasgvd/godot-workshop-utility
static func _get_steam_app_id() -> String:
	var game_install_directory := _ModLoaderPath.get_local_folder_dir()
	var steam_app_id := ""
	var file := File.new()

	if file.open(game_install_directory.plus_file("steam_data.json"), File.READ) == OK:
		var file_content: Dictionary = parse_json(file.get_as_text())
		file.close()

		if not file_content.has("app_id"):
			ModLoaderLog.error("The steam_data file does not contain an app ID. Mod uploading will not work.", LOG_NAME)
			return ""

		steam_app_id = file_content.app_id
	else :
		ModLoaderLog.error("Can't open steam_data file, \"%s\". Please make sure the file exists and is valid." % game_install_directory.plus_file("steam_data.json"), LOG_NAME)

	return steam_app_id
