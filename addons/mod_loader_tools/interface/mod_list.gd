extends VBoxContainer

export var is_enabled_list := true

const mod_card_scene := preload("res://addons/mod_loader_tools/interface/mod_card.tscn")


func _ready() -> void:
	if is_enabled_list:
		$Bar/Heading.text = "Enabled"
		$Bar/ChangeStateAllLabel.text = "Disable All"
		$Bar/ChangeStateAll.text = ModLoaderHelper.get_font_icon("angles-left")
	else	:
		$Bar/Heading.text = "Disabled"
		$Bar/ChangeStateAllLabel.text = "Enable All"
		$Bar/ChangeStateAll.text = ModLoaderHelper.get_font_icon("angles-right")


func populate(mod_details_list: Array) -> void:
	for mod_details in mod_details_list:
		mod_details = mod_details as ModDetails
		if not mod_details:
			continue

		if not is_enabled_list == ModLoaderHelper.is_mod_enabled(mod_details.id):
			continue

		var card: ModCard = mod_card_scene.instance()
		card.mod_details = mod_details
		card.connect("mod_card_clicked", get_node("/root/ModSelector/DetailsPopup"), "show_mod_details")
		card.connect("mod_changed_state", get_node("/root/ModSelector"), "mod_changed_state")

		$Scroll/ModList.add_child(card)


func remove_mod_card(mod_card: ModCard) -> void:
	$Scroll/ModList.remove_child(mod_card)


func add_mod_card(mod_card: ModCard) -> void:
	$Scroll/ModList.add_child(mod_card)
	$Scroll/ModList.move_child(mod_card, 0) # move the card to top spot


func _on_change_state_all_pressed() -> void:
	for card in $Scroll/ModList.get_children():
		if card is ModCard:
			card.toggle_enabled_state()


