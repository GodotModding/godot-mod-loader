class_name ModLoaderOptionsProfile
extends Resource
##
## Class to define and store Mod Loader Options.


## Settings for the game version validation.
enum VERSION_VALIDATION {
	## The default semver version validation
	DEFAULT,
	## Activate this option to disable validation of the game version specified in [member semantic_version]
	## and the mod's [member ModManifest.compatible_game_version].
	DISABLED,
	## Activate this option to use a custom game version validation, use the [member customize_script_path]
	## to specify a script to customize the Mod Loader Options. In this script you have to set [member custom_game_version_validation_callable]
	## with a custom validation [Callable].
	##
	##[codeblock]
	##extends RefCounted
	##
	##
	##func _init(mod_loader_store: ModLoaderStore) -> void:
	##   # Setting the custom_game_version_validation_callable here.
	##   # Use `OS.has_feature(feature_tag)` to apply different validations for different feature tags.
	##   mod_loader_store.ml_options.custom_game_version_validation_callable = custom_is_game_version_compatible
	##
	##
	##func custom_is_game_version_compatible(manifest: ModManifest) -> bool:
	##   print("! ☞ﾟヮﾟ)☞ CUSTOM VALIDATION HERE ☜ﾟヮﾟ☜) !")
	##
	##   var mod_id := manifest.get_mod_id()
	##
	##   for version in manifest.compatible_game_version:
	##      if not version == "pizza":
	##         manifest.validation_messages_warning.push_back(
	##            "The mod \"%s\" may not be compatible with the current game version.
	##            Enable at your own risk. (current game version: %s, mod compatible with game versions: %s)" %
	##            [mod_id, MyGlobalVars.MyGameVersion, manifest.compatible_game_version]
	##         )
	##         return false
	##
	##   return true
	##[/codeblock]
	##
	## Using the customization script allows you to place your custom code outside of the addon directory to simplify mod loader updates.
	##
	CUSTOM,
}

## Can be used to disable mods for specific plaforms by using feature overrides
@export var enable_mods: bool = true
## List of mod ids that can't be turned on or off
@export var locked_mods: Array[String] = []
## List of mods that will not be loaded
@export var disabled_mods: Array[String] = []
## Disables the requirement for the mod loader autoloads to be first
@export var allow_modloader_autoloads_anywhere: bool = false


@export_group("Logging")
## Sets the logging verbosity level.
## Refer to [enum ModLoaderLog.VERBOSITY_LEVEL] for more details.
@export var log_level := ModLoaderLog.VERBOSITY_LEVEL.DEBUG
## Stops the mod loader from logging any deprecation related errors.
@export var ignore_deprecated_errors: bool = false
## Ignore messages from these namespaces.[br]
## Accepts * as wildcard. [br]
## [code]ModLoader:Dependency[/code] - ignore the exact name [br]
## [code]ModLoader:*[/code] - ignore all beginning with this name [br]
@export var ignored_mod_names_in_log: Array[String] = []

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
## Use this option to override the default path where configs are stored.
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

@export_group("Mod Validation")
## Settings for validation of the game version specified in [member semantic_version]
## and the mod's [member ModManifest.compatible_game_version].
@export var game_version_validation:= VERSION_VALIDATION.DEFAULT
## This is the callable that is called during [ModManifest] validation.
## See the example at [enum VERSION_VALIDATION] [code]CUSTOM[/code] to learn how to set this.
var custom_game_version_validation_callable: Callable
## Use this to specify a script to customize mod loader options.
## Can be used to set custom options properties.
## The customize_script is initialized with the [ModLoaderStore] as the first and only argument.
## See [enum VERSION_VALIDATION] [code]CUSTOM[/code] for an example on how to use it.
@export_file var customize_script_path: String

## This is where the instance of [member customize_script_path] is stored.
var customize_script_instance: RefCounted
