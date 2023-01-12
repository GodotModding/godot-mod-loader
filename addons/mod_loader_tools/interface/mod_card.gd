extends PanelContainer

signal mod_card_clicked(mod_details)

var mod_details: ModDetails


func _ready() -> void:
	if true:
		$HBox/AspectRatioContainer/ToggleAction.text = ModLoaderHelper.get_font_icon("angles-right")
	else:
		$HBox/AspectRatioContainer/ToggleAction.text = ModLoaderHelper.get_font_icon("angles-left")


func _on_mod_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			emit_signal("mod_card_clicked", mod_details)

