extends Node
class_name ModLoaderHelper

const settings := {
	"AUTOLOAD_AVAILABLE": "application/run/autoload_available",
	"MODS_ENABLED": "application/run/mods_enabled",
	"MOD_SELECTION_SCENE": "application/run/mod_selection_scene",
	"SKIP_MOD_SELECTION": "application/run/skip_mod_selection",

	"APPLICATION_NAME": "application/config/name",
	"GAME_MAIN_SCENE": "application/run/main_scene",
	"MOD_LOADER_AUTOLOAD": "autoload/ModLoader",

	"GLOBAL_SCRIPT_CLASSES": "_global_script_classes",
	"GLOBAL_SCRIPT_CLASS_ICONS": "_global_script_class_icons",

	"MOD_ENABLED_STATE_DICT": "application/run/mod_enabled_state_dict",
}

const mod_selection_scene := "res://addons/mod_loader_tools/interface/mod_selector.tscn"
const mod_loader_script := "res://addons/mod_loader_tools/mod_loader.gd"

const new_global_classes := [
	{ "base": "Resource", "class": "ModDetails", "language": "GDScript", "path": "res://addons/mod_loader_tools/mod_details.gd" },
	{ "base": "Node", "class": "ModLoaderHelper", "language": "GDScript", "path": "res://addons/mod_loader_tools/mod_loader_helper.gd" },
	{ "base": "VBoxContainer", "class": "ModList", "language": "GDScript", "path": "res://addons/mod_loader_tools/interface/mod_list.gd" },
	{ "base": "PanelContainer", "class": "ModCard", "language": "GDScript", "path": "res://addons/mod_loader_tools/interface/mod_card.gd" },
]

# Required keys in a mod's manifest.json file
const REQUIRED_MANIFEST_KEYS_ROOT = [
	"name",
	"version_number",
	"website_url",
	"description",
	"dependencies",
	"extra",
]

# Required keys in manifest's `json.extra.godot`
const REQUIRED_MANIFEST_KEYS_EXTRA = [
	"id",
	"incompatibilities",
	"authors",
	"compatible_game_version",
]


static func get_override_path() -> String:
	var base_path := ""
	if OS.has_feature("editor"):
		base_path = ProjectSettings.globalize_path("res://")
	else:
		# this is technically different to res:// in macos, but we want the
		# executable dir anyway, so it is exactly what we need
		base_path = OS.get_executable_path().get_base_dir()

	return base_path.plus_file("override.cfg")


static func are_mods_enabled() -> bool:
	return is_project_setting_true(settings.MODS_ENABLED)


static func is_loader_initialized() -> bool:
	return is_project_setting_true(settings.AUTOLOAD_AVAILABLE)


static func should_skip_mod_selection() -> bool:
	return cmd_line_arg_exists("--skip-mod-selection") or\
		is_project_setting_true(settings.SKIP_MOD_SELECTION)


static func is_project_setting_true(project_setting: String) -> bool:
	return ProjectSettings.has_setting(project_setting) and\
		ProjectSettings.get_setting(project_setting)


static func cmd_line_arg_exists(argument: String) -> bool:
	for arg in OS.get_cmdline_args():
		if arg == argument:
			return true
	return false


static func get_enabled_state_dict() -> Dictionary:
	if not ProjectSettings.has_setting(settings.MOD_ENABLED_STATE_DICT):
		return {}
	return ProjectSettings.get_setting(settings.MOD_ENABLED_STATE_DICT)


static func is_mod_enabled(mod_id: String) -> bool:
	var mod_enabled_state_dict: Dictionary = get_enabled_state_dict()
	if not mod_enabled_state_dict.has(mod_id):
		return false
	return bool(mod_enabled_state_dict[mod_id])


static func toggle_mod_enabled_state(mod_id: String) -> void:
	var mod_enabled_state_dict: Dictionary = get_enabled_state_dict()
	mod_enabled_state_dict[mod_id] = not is_mod_enabled(mod_id)
	ProjectSettings.set_setting(settings.MOD_ENABLED_STATE_DICT, mod_enabled_state_dict)
	ProjectSettings.save_custom(get_override_path())


# 3.x does not support ligatures (eg. "tag" being replaced by the glyph)
# so the glyph is used directly (but it's invisible in the code editor :/ )
# the name is the same as used in font awesome
# refer to https://fontawesome.com/search?o=r&m=free&s=solid&f=classic
static func get_font_icon(icon_name: String) -> String:
	match icon_name:
		"angles-left": return ""
		"angles-right": return ""
		"caret-left": return ""
		"caret-right": return ""
		"triangle-exclamation": return ""
		"link": return ""
		"ban": return ""
		"tag": return ""
		_: push_error("icon '%s' not found" % icon_name)
	return ""


