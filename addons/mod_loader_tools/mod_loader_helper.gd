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
}

const mod_selection_scene := "res://addons/mod_loader_tools/interface/mod_selector.tscn"
const mod_loader_script := "res://addons/mod_loader_tools/mod_loader.gd"

const new_global_classes := [
	{ "base": "Resource", "class": "ModDetails", "language": "GDScript", "path": "res://addons/mod_loader_tools/mod_details.gd" },
	{ "base": "Node", "class": "ModLoaderHelper", "language": "GDScript", "path": "res://addons/mod_loader_tools/mod_loader_helper.gd" }
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
	return ProjectSettings.has_setting(settings.MODS_ENABLED) and\
		ProjectSettings.get_setting(settings.MODS_ENABLED)


static func is_loader_initialized() -> bool:
	return ProjectSettings.has_setting(settings.AUTOLOAD_AVAILABLE) and\
		ProjectSettings.get_setting(settings.AUTOLOAD_AVAILABLE)


static func should_skip_mod_selection() -> bool:
	return cmd_line_arg_exists("--skip-mod-selection") or\
		ProjectSettings.has_setting(settings.SKIP_MOD_SELECTION) and\
		ProjectSettings.get_setting(settings.SKIP_MOD_SELECTION)


static func is_project_setting_true(project_setting: String) -> bool:
	return ProjectSettings.has_setting(project_setting) and\
		ProjectSettings.get_setting(project_setting)


static func cmd_line_arg_exists(argument: String) -> bool:
	for arg in OS.get_cmdline_args():
		if arg == argument:
			return true
	return false


# because 3.x does not support ligatures used in the icon font
# so the glyph is used directly (but it's invisible in the code editor :/ )
# the name is the same as used in font awesome
# refer to https://fontawesome.com/icons/angles-right?s=solid&f=classic
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
