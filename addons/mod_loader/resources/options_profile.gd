class_name ModLoaderOptionsProfile
extends Resource


## Can be used to disable mods for specific plaforms by using feature overrides
@export var enable_mods: bool = true
## List of mod ids that can't be turned on or off
@export var locked_mods: Array[String] = []

@export var disabled_mods: Array[String] = []
## Disables the requirement for the mod loader autoloads to be first
@export var allow_modloader_autoloads_anywhere: bool = false


@export_group("Logging")
@export var log_level := ModLoaderLog.VERBOSITY_LEVEL.DEBUG
## Stops the mod loader from logging any deprecation related errors.
@export var ignore_deprecated_errors: bool = false
## Ignore messages from these namespaces.[br]
## Accepts * as wildcard. [br]
## [code]ModLoader:Dependency[/code] - ignore the exact name [br]
## [code]ModLoader:*[/code] - ignore all beginning with this name [br]
@export var ignored_mod_names_in_log: Array[String] = []
@export var hint_color := Color("#70bafa")

@export_group("Game Data")
## Steam app id, can be found in the steam page url
@export var steam_id: int = 0:
	get:
		return steam_id

## Semantic game version. [br]
## Replace the getter in options_profile.gd if your game stores the version somewhere else
@export var semantic_version := "0.0.0":
	get:
		return semantic_version

@export_group("Mod Sources")
## Indicates whether to load mods from the Steam Workshop directory, or the overridden workshop path.
@export var load_from_steam_workshop: bool = false
## Indicates whether to load mods from the "mods" folder located at the game's install directory, or the overridden mods path.
@export var load_from_local: bool = true
## Path to a folder containing mods [br]
## Mod zips should be directly in this folder
@export_dir var override_path_to_mods = ""
@export_dir var override_path_to_configs = ""
## Path to a folder containing workshop items.[br]
## Mods zips are placed in another folder, usually[br]
## [code]/<workshop id>/mod.zip[/code][br]
## The real workshop path ends with [br]
## [code]/workshop/content[/code] [br]
@export_dir var override_path_to_workshop = ""

@export_group("Mod Hooks")
## Can be used to override the default hook pack path, the hook pack is located inside the game's install directory by default.
## To override the path specify a new absolute path.
@export_global_dir var override_path_to_hook_pack := ""
## Can be used to override the default hook pack name, by default it is [constant ModLoaderStore.MOD_HOOK_PACK_NAME]
@export var override_hook_pack_name := ""
## Can be used to specify your own scene that is displayed if a game restart is required.
## For example if new mod hooks were generated.
@export_dir var restart_notification_scene_path := "res://addons/mod_loader/restart_notification.tscn"
## Can be used to disable the mod loader's restart logic. Use the [signal ModLoader.new_hooks_created] to implement your own restart logic.
@export var disable_restart := false
