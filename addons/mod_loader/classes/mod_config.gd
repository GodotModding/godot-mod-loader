class_name ModConfig
extends Resource


const LOG_NAME := "ModLoader:ModConfig"

var mod_id: String
var schema: Dictionary
var data: Dictionary
var save_path: String


func get_data_as_string() -> String:
	return JSON.print(data)


func get_schema_as_string() -> String:
	return JSON.print(schema)


func is_valid() -> bool:
	var json_schema := JSONSchema.new()
	var error := json_schema.validate(get_data_as_string(), get_schema_as_string())

	if not error == "":
		ModLoaderLog.fatal(error, LOG_NAME)
		return false

	return true
