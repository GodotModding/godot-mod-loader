class_name ModLoaderOptionsProfile
extends Resource


@export var enable_mods: bool = true
@export var locked_mods: Array[String] = []
@export var log_level := ModLoaderLog.VERBOSITY_LEVEL.DEBUG
## Mods in this array will only load metadata but will not apply any modifications.
## This can be used to deactivate example mods.
## Mods in this array are overridden by the settings in the user profile.
@export var deactivated_mods: Array[String] = []
## Generate a user profile with all mods deactivated.
## This can be used after a major game update to prevent crashes.
@export var create_deactivated_mods_profile = false
## The name of the deactivated mods profile.
## Use this to customize the profile name. Make sure to change the name each time you want to deactivate all mods.
## The profile is only created if the name doesn't already exist. You can add a version suffix, for example.
@export var deactivated_mods_profile_name = "deactivated_"
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
