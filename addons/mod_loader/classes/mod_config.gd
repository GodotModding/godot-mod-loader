class_name ModConfig
extends Resource


var mod_id: String
var schema: Dictionary
var data: Dictionary
var save_path: String


func get_data_as_string() -> String:
	return JSON.print(data)


func get_schema_as_string() -> String:
	return JSON.print(schema)
