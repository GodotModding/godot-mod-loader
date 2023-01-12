extends PanelContainer

onready var loader_info_node: RichTextLabel = $Margin/HBox/LoaderInfoSection/InfoText

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

# IMPORTANT: use the ModLoaderHelper through this var in this script! Otherwise
# script compilation will break on first load since the class is not defined
# just use the normal one with autocomplete and then lowercase it
var modloaderhelper: Node = preload("res://addons/mod_loader_tools/mod_loader_helper.gd").new()


func _ready():
	if OS.get_screen_scale() > 1.0:
		for label in $HdpiFontAdjustments.get_children():
			((label as Label).get_font("font") as DynamicFont).size *= 2

	if not modloaderhelper.are_mods_enabled():
		$RestartPopup.show()
		$RestartPopup/RestartGame.popup_centered()
		$RestartPopup/RestartGame.get_ok().grab_focus()
		return

	$Margin/HBox/LoaderInfoSection/ModSelectionToggle.pressed = modloaderhelper.should_skip_mod_selection()

	$Margin/HBox/ModListDisabled/Scroll/ModList/ModCard.connect("mod_card_clicked", $DetailsPopup, "show_mod_details")


func list_mods() -> void:
	pass


func reset_mod_loader() -> void:
	var dir = Directory.new()
	dir.remove(modloaderhelper.get_override_path())


func _on_restart_game_confirmed() -> void:
	get_tree().quit()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_reset_mod_loader_pressed() -> void:
	reset_mod_loader()
	$Margin/HBox/LoaderInfoSection/ResetNote.text = "Reset done. Quit and Restart the game."


func _on_start_game_pressed() -> void:
	get_tree().set_screen_stretch(
		get_tree().get("STRETCH_MODE_%s" % ProjectSettings.get_setting("display/window/stretch/mode").to_upper()),
		get_tree().get("STRETCH_ASPECT_%s" % ProjectSettings.get_setting("display/window/stretch/aspect").to_upper()),
		Vector2(
			ProjectSettings.get_setting("display/window/size/width"),
			ProjectSettings.get_setting("display/window/size/height")
		)
	)
	get_tree().change_scene(ProjectSettings.get_setting(settings.GAME_MAIN_SCENE))


func _on_loader_info_meta_clicked(meta: String) -> void:
	OS.shell_open(meta)


func _on_loader_info_meta_hover_started(meta: String) -> void:
	loader_info_node.hint_tooltip = meta


func _on_loader_info_meta_hover_ended(meta: String) -> void:
	loader_info_node.hint_tooltip = ""


func _on_mod_selection_toggle_toggled(button_pressed: bool) -> void:
	set_skip_mod_selection(button_pressed)


static func set_skip_mod_selection(should_skip: bool) -> void:
	var override_path: String = ProjectSettings.globalize_path("res://".plus_file("override.cfg"))
	ProjectSettings.set_setting(settings.SKIP_MOD_SELECTION, should_skip)
	ProjectSettings.save_custom(override_path)


