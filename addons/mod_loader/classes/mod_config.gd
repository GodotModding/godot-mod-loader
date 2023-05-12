class_name ModConfig
extends Resource


const LOG_NAME := "ModLoader:ModConfig"

var name: String
var mod_id: String
var schema: Dictionary
var data: Dictionary
var save_path: String
var is_valid := false


func _init(_mod_id: String, _data: Dictionary, _save_path: String, _schema: Dictionary = {}) -> void:
	name = _ModLoaderPath.get_file_name_from_path(_save_path, true, true)
	mod_id = _mod_id
	schema = ModLoaderStore.mod_data[_mod_id].manifest.config_schema if _schema.empty() else _schema
	data = _data
	save_path = _save_path

	var error_message := validate()

	if not error_message == "":
		ModLoaderLog.error("Mod Config for mod \"%s\" failed JSON Schema Validation with error message: \"%s\"" % [mod_id, error_message], LOG_NAME)
		return

	is_valid = true


func get_data_as_string() -> String:
	return JSON.print(data)


func get_schema_as_string() -> String:
	return JSON.print(schema)


# Empty string if validation was successful
func validate() -> String:
	var json_schema := JSONSchema.new()
	var error := json_schema.validate(get_data_as_string(), get_schema_as_string())

	return error


func is_valid() -> bool:
	if not validate() == "":
		is_valid = false
		return false

	is_valid = true
	return true


func save_to_disc() -> bool:
	var is_success := _ModLoaderFile.save_dictionary_to_json_file(data, save_path)
	return is_success


func remove_from_disc() -> bool:
	var is_success := _ModLoaderFile.remove_file(save_path)
	return is_success
