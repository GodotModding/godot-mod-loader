extends PanelContainer
class_name ModCard

signal mod_card_clicked(mod_details)
signal mod_changed_state(mod_card)

var mod_details: ModDetails setget set_mod_details

var tag_scene := preload("res://addons/mod_loader_tools/interface/tag.tscn")

func set_mod_details(_mod_details: ModDetails) -> void:
	mod_details = _mod_details
	($HBox/VBox/HBox/Title as Label).text = mod_details.name
	($HBox/VBox/Description as RichTextLabel).text = mod_details.description
	($HBox/VBox/MetaInfo/Version as Label).text = "v" + mod_details.version_number

	var authors_string := "by "
	for author in mod_details.authors:
		authors_string += author + ", "
	($HBox/VBox/HBox/Autors as Label).text = authors_string.trim_suffix(", ")

	for tag_string in mod_details.tags:
		var tag: Control = tag_scene.instance()
		(tag.get_node("Label") as Label).text = tag_string
		$HBox/VBox/MetaInfo.add_child(tag)

	update_button_icon()


func update_button_icon() -> void:
	if ModLoaderHelper.is_mod_enabled(mod_details.id):
		$HBox/AspectRatioContainer/ChangeState.text = ModLoaderHelper.get_font_icon("angles-left")
	else:
		$HBox/AspectRatioContainer/ChangeState.text = ModLoaderHelper.get_font_icon("angles-right")


func toggle_enabled_state() -> void:
	ModLoaderHelper.toggle_mod_enabled_state(mod_details.id)
	update_button_icon()
	emit_signal("mod_changed_state", self)


func _on_mod_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			emit_signal("mod_card_clicked", mod_details)


func _on_change_state_pressed() -> void:
	toggle_enabled_state()

