class_name ModLoaderOptionsProfile
extends Resource

# export (String) var my_string := ""
# export (Resource) var upgrade_to_process_icon = null
# export (Array, Resource) var elites: = []

@export var enable_mods: bool = true
@export var locked_mods: Array[String] = []
@export var log_level := ModLoaderLog.VERBOSITY_LEVEL.DEBUG
@export var disabled_mods: Array[String] = []
@export var allow_modloader_autoloads_anywhere: bool = false
@export var steam_workshop_enabled: bool = false
@export_dir var override_path_to_mods = ""
@export_dir var override_path_to_configs = ""
@export_dir var override_path_to_workshop = ""
@export var ignore_deprecated_errors: bool = false
@export var ignored_mod_names_in_log: Array[String] = []
