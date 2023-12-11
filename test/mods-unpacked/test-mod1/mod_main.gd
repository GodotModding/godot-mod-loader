extends Node


const TEST_MOD1_DIR := "test-mod1"
const TEST_MOD1_LOG_NAME := "test-mod1:Main"

var mod_dir_path := ""
var extensions_dir_path := ""
var translations_dir_path := ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(TEST_MOD1_DIR)
	# Add extensions
	install_script_extensions()
	# Add translations
	add_translations()


func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("script_extension_sorting/script_c.gd"))



func add_translations() -> void:
	translations_dir_path = mod_dir_path.plus_file("translations")


func _ready() -> void:
	pass


