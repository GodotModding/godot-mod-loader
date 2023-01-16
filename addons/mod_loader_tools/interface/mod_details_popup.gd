extends Panel

var tag_scene := preload("res://addons/mod_loader_tools/interface/tag.tscn")
onready var description_node: RichTextLabel = $ModDetails/Margin/HBox/VBox/Scroll/Description


func show_mod_details(mod_details: ModDetails) -> void:
	($ModDetails/Margin/HBox/VBox/Title as Label).text = mod_details.name

	description_node.bbcode_text = mod_details.description_rich
	($ModDetails/Margin/HBox/VBox/MetaInfo/Version as Label).text = "v" + mod_details.version_number

	var authors_string := "by "
	for author in mod_details.authors:
		authors_string += author + ", "
	($ModDetails/Margin/HBox/VBox/Authors as Label).text = authors_string.trim_suffix(", ")

	for tag in $ModDetails/Margin/HBox/VBox/MetaInfo.get_children():
		if not tag is Label: # version note
			tag.queue_free()

	for tag_string in mod_details.tags:
		var tag: Control = tag_scene.instance()
		(tag.get_node("Label") as Label).text = tag_string
		($ModDetails/Margin/HBox/VBox/MetaInfo as HBoxContainer).add_child(tag)

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

