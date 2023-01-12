extends Panel

onready var description_node: RichTextLabel = $ModDetails/Margin/HBox/VBox/Scroll/Description



func show_mod_details(mod_details: ModDetails) -> void:
	pass
	show()


func _on_mod_description_meta_clicked(meta: String) -> void:
	OS.shell_open(meta)


func _on_mod_description_meta_hover_started(meta: String) -> void:
	description_node.hint_tooltip = meta


func _on_mod_description_meta_hover_ended(meta: String) -> void:
	description_node.hint_tooltip = ""



func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == BUTTON_LEFT:
			hide()

