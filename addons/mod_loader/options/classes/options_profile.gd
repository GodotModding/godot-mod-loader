class_name ModLoaderOptionsProfile
extends Resource

# export (String) var my_string := ""
# export (Resource) var upgrade_to_process_icon = null
# export (Array, Resource) var elites: = []

enum ModLoaderDebugLevel { ERROR, WARNING, INFO, DEBUG }

export (bool) var enable_mods = true
export (ModLoaderDebugLevel) var log_level: = ModLoaderDebugLevel.DEBUG
export (String) var path_to_mods = "res://mods"
export (String) var path_to_configs = "res://configs"
export (bool) var use_steam_workshop_path = false
