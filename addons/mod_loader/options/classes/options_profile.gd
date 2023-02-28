class_name ModLoaderOptionsProfile
extends Resource

# export (String) var my_string := ""
# export (Resource) var upgrade_to_process_icon = null
# export (Array, Resource) var elites: = []

export (bool) var enable_mods = true
export (ModLoaderUtils.verbosity_level) var log_level: = ModLoaderUtils.verbosity_level.DEBUG
export (String, DIR) var path_to_mods = "res://mods"
export (String, DIR) var path_to_configs = "res://configs"
export (bool) var use_steam_workshop_path = false
