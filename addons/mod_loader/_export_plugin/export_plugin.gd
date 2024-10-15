extends EditorExportPlugin

const ModHookPreprocessorScript := preload("res://addons/mod_loader/internal/mod_hook_preprocessor.gd")
static var ModHookPreprocessor


func _get_name() -> String:
	return "Godot Mod Loader Export Plugin"


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	ModHookPreprocessor = ModHookPreprocessorScript.new()
	ModHookPreprocessor.process_begin()


func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	if path.begins_with("res://addons") or path.begins_with("res://mods-unpacked"):
		return

	if type != "GDScript":
		return

	skip()
	add_file(
		path,
		ModHookPreprocessor.process_script(path).to_utf8_buffer(),
		false
	)
