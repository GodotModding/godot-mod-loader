extends PanelContainer
class_name ModSelector

onready var loader_info_node: RichTextLabel = $Margin/HBox/LoaderInfoSection/InfoText

const settings := {
	"SKIP_MOD_SELECTION": "application/run/skip_mod_selection",
}

# IMPORTANT: use the ModLoaderHelper through this var in this script! Otherwise
# script compilation will break on first load since the class is not defined
# just use the normal one with autocomplete and then lowercase it
var modloaderhelper: Node = preload("res://addons/mod_loader_tools/mod_loader_helper.gd").new()


func _ready():
	if not modloaderhelper.are_mods_enabled():
		$RestartPopup.show()
		$RestartPopup/RestartGame.popup_centered()
		$RestartPopup/RestartGame.get_ok().grab_focus()
		return

	$Margin/HBox/LoaderInfoSection/SkipModSelectionToggle.pressed = modloaderhelper.should_skip_mod_selection()

	fill_mod_lists()


func fill_mod_lists() -> void:
	var details_list := []
	for data in ModLoader.mod_data:
		if (ModLoader.mod_data[data].is_loadable):
			var mod_data: Dictionary = ModLoader.mod_data[data].meta_data
			var mod_details := ModDetails.new(mod_data)
			details_list.append(mod_details)

	var disabled_list: ModList = $Margin/HBox/ModListDisabled
	disabled_list.populate(details_list)

	var enabled_list: ModList = $Margin/HBox/ModListEnabled
	enabled_list.populate(details_list)


func mod_changed_state(mod_card: ModCard) -> void:
	var disabled_list: ModList = $Margin/HBox/ModListDisabled
	var enabled_list: ModList = $Margin/HBox/ModListEnabled
	if ModLoaderHelper.is_mod_enabled(mod_card.mod_details.id):
		disabled_list.remove_mod_card(mod_card)
		enabled_list.add_mod_card(mod_card)
	else:
		enabled_list.remove_mod_card(mod_card)
		disabled_list.add_mod_card(mod_card)


static func set_skip_mod_selection(should_skip: bool) -> void:
	var override_path: String = ProjectSettings.globalize_path("res://".plus_file("override.cfg"))
	ProjectSettings.set_setting(settings.SKIP_MOD_SELECTION, should_skip)
	ProjectSettings.save_custom(override_path)


func scale_font_size(factor: float) -> void:
	factor = clamp(factor, 0.7, 1.4)
	for label in $HdpiFontAdjustments.get_children():
		label = label as Label
		var font: DynamicFont = label.get_font("font")
		if not label.text:
			label.text = str(font.size) # note the base size
		font.size = float(label.text) * factor * OS.get_screen_scale()


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
	ModLoader.init_mods()
	get_tree().set_screen_stretch(
		get_tree().get("STRETCH_MODE_%s" % ProjectSettings.get_setting("display/window/stretch/mode").to_upper()),
		get_tree().get("STRETCH_ASPECT_%s" % ProjectSettings.get_setting("display/window/stretch/aspect").to_upper()),
		Vector2(
			ProjectSettings.get_setting("display/window/size/width"),
			ProjectSettings.get_setting("display/window/size/height")
		)
	)
	get_tree().change_scene(ProjectSettings.get_setting(modloaderhelper.settings.GAME_MAIN_SCENE))


func _on_loader_info_meta_clicked(meta: String) -> void:
	OS.shell_open(meta)


func _on_loader_info_meta_hover_started(meta: String) -> void:
	loader_info_node.hint_tooltip = meta


func _on_loader_info_meta_hover_ended(meta: String) -> void:
	loader_info_node.hint_tooltip = ""


func _on_mod_selection_toggle_toggled(button_pressed: bool) -> void:
	set_skip_mod_selection(button_pressed)


func _on_mod_selector_item_rect_changed() -> void:
	var new_scale := rect_size.x / 2500 # somewhat arbitrary :/
	scale_font_size(new_scale)

