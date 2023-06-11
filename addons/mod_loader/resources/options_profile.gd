class_name ModLoaderOptionsProfile
extends Resource

# export (String) var my_string := ""
# export (Resource) var upgrade_to_process_icon = null
# export (Array, Resource) var elites: = []

export (bool) var enable_mods = true
export (Array, String) var locked_mods = []
export (ModLoaderLog.VERBOSITY_LEVEL) var log_level := ModLoaderLog.VERBOSITY_LEVEL.DEBUG
export (Array, String) var disabled_mods = []
export (bool) var allow_modloader_autoloads_anywhere = false
export (bool) var steam_workshop_enabled = false
export (String, DIR) var override_path_to_mods = ""
export (String, DIR) var override_path_to_configs = ""
export (String, DIR) var override_path_to_workshop = ""
export (bool) var ignore_deprecated_errors = false
export (Array, String) var ignored_mod_names_in_log = []
