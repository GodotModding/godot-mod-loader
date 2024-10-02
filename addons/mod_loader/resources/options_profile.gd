class_name ModLoaderOptionsProfile
extends Resource


@export var enable_mods: bool = true
@export var locked_mods: Array[String] = []
@export var log_level := ModLoaderLog.VERBOSITY_LEVEL.DEBUG
@export var disabled_mods: Array[String] = []
@export var allow_modloader_autoloads_anywhere: bool = false
@export var steam_id: int = 0
@export_global_dir var override_path_to_mods = ""
@export_global_dir var override_path_to_configs = ""
@export_global_dir var override_path_to_workshop = ""
@export var ignore_deprecated_errors: bool = false
@export var ignored_mod_names_in_log: Array[String] = []
@export_group("Mod Source")
## Indicates whether to load mods from the Steam Workshop directory, or the overridden workshop path.
@export var load_from_steam_workshop: bool = false
## Indicates whether to load mods from the "mods" folder located at the game's install directory, or the overridden mods path.
@export var load_from_local: bool = true
@export_group("Mod Hooks")
## Can be used to override the default hook pack path, the hook pack is located inside the game's install directory by default.
## To override the path specify a new absolute path.
@export_global_dir var override_path_to_hook_pack := ""
## Can be used to override the default hook pack name, by default it is [constant ModLoaderStore.MOD_HOOK_PACK_NAME]
@export var override_hook_pack_name := ""
## Can be used to specify your own scene that is displayed if a game restart is required.
## For example if new mod hooks where generated.
@export_dir var restart_notification_scene_path := "res://addons/mod_loader/restart_notification.tscn"
## Can be used to disable the mod loader's restart logic. Use the [signal ModLoader.new_hooks_created] to implement your own restart logic.
@export var disable_restart := false
