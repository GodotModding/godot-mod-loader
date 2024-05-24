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
## Settings for scanning mods before loading them into the game's mods-unpacked directory and executing any code
@export_group("Mod Scan")
## [b]!!! This is not a security measure, it will not make modding safe. !!![/b][br]
## Please check the Wiki FAQ for additional information on sandboxing and security.[br][br]
## Enable scanning mod zips before loading them into the game.
@export var enable_mod_scan := false
## Array to specify disallowed strings in script files
@export var disallowed_strings_in_script_files: Array[StringName] = [
	"OS",
	"FileAccess",
	"DirAccess",
	"Script",
	"GDScript",
	"HTTPClient",
	"HTTPRequest",
	"WebSocketPeer",
	"WebRTCDataChannel",
	"WebRTCDataChannelExtension",
	"WebRTCMultiplayerPeer",
	"WebRTCPeerConnection",
	"WebRTCPeerConnectionExtension",
	"WebSocketMultiplayerPeer",
	"ml_options",
	"res://addons/mod_loader/internal/file.gd",
	"_ModLoaderFile",
]
## Array to specify disallowed strings in scene files
@export var disallowed_strings_in_scene_files: Array[StringName] = ["HTTPRequest"]
## Array to specify allowed file extensions in mod zips
@export var allowed_file_extensions: Array[StringName] = ["tscn", "tres", "gd", "svg", "png", "jpg", "anim"]
