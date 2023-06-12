# Helper class script
# Inherits from File, but loads JSON data with optional Schema validation
# Assign valid JSONSchema instance and provide schema to suitable fields
# to load data with automatic validation by provided schema
# otherwise data loads with internal JSON formatting checking

class_name JSONFile extends File

var schema_validator : JSONSchema
var json_schema : String

func save_data(a) -> void: # argument is untyped Variant
	if is_open():
		store_line(to_json(a))
	pass

func load_data():
	var result
	if is_open():
		result = get_as_text()
		var err : String
		if schema_validator:
			err = schema_validator.validate(result, json_schema) 
		else:
			err = validate_json(result)
		if err:
			result = err
		else:
			result = parse_json(result)
	return result
