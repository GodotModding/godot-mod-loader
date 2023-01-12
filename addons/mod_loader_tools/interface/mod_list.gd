extends VBoxContainer

export var list_disabled_mods := true


func _ready() -> void:
	if list_disabled_mods:
		$Bar/Heading.text = "Disabled"
		$Bar/AllActionLabel.text = "Enable All"
		$Bar/AllAction.text = ModLoaderHelper.get_font_icon("angles-right")
	else	:
		$Bar/Heading.text = "Enabled"
		$Bar/AllActionLabel.text = "Disable All"
		$Bar/AllAction.text = ModLoaderHelper.get_font_icon("angles-left")

