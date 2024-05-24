class_name ModLoaderOptionsProfile
extends Resource


@export var enable_mods: bool = true
@export var locked_mods: Array[String] = []
@export var log_level := ModLoaderLog.VERBOSITY_LEVEL.DEBUG
@export var disabled_mods: Array[String] = []
@export var allow_modloader_autoloads_anywhere: bool = false
@export var steam_id: int = 0
@export_dir var override_path_to_mods = ""
@export_dir var override_path_to_configs = ""
@export_dir var override_path_to_workshop = ""
@export var ignore_deprecated_errors: bool = false
@export var ignored_mod_names_in_log: Array[String] = []
@export_group("Mod Source")
## Indicates whether to load mods from the Steam Workshop directory, or the overridden workshop path.
@export var load_from_steam_workshop: bool = false
## Indicates whether to load mods from the "mods" folder located at the game's install directory, or the overridden mods path.
@export var load_from_local: bool = true
