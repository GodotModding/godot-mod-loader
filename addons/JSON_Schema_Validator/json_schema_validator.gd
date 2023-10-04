class_name JSONSchema
extends RefCounted


# JSON Schema main script
# Inherits from Reference for easy use

const SMALL_FLOAT_THRESHOLD = 0.001
const MAX_DECIMAL_PLACES = 3

const DEF_KEY_NAME = "schema root"
const DEF_ERROR_STRING = "##error##"

const JST_ARRAY = "array"
const JST_BOOLEAN = "boolean"
const JST_INTEGER = "integer"
const JST_NULL = "null"
const JST_NUMBER = "number"
const JST_OBJECT = "object"
const JST_STRING = "string"

const JSKW_TYPE = "type"
const JSKW_PROP = "properties"
const JSKW_REQ = "required"
const JSKW_TITLE = "title"
const JSKW_DESCR = "description"
const JSKW_DEFAULT = "default"
const JSKW_EXAMPLES = "examples"
const JSKW_COMMENT = "$comment"
const JSKW_ENUM = "enum"
const JSKW_CONST = "const"
const JSKW_PREFIX_ITEMS = "prefixItems"
const JSKW_ITEMS = "items"
const JSKW_MIN_ITEMS = "minItems"
const JSKW_MAX_ITEMS = "maxItems"
const JSKW_CONTAINS = "contains"
const JSKW_ADD_ITEMS = "additionalItems"
const JSKW_UNIQUE_ITEMS = "uniqueItems"
const JSKW_MULT_OF = "multipleOf"
const JSKW_MINIMUM = "minimum"
const JSKW_MIN_EX = "exclusiveMinimum"
const JSKW_MAXIMUM = "maximum"
const JSKW_MAX_EX = "exclusiveMaximum"
const JSKW_PROP_ADD = "additionalProperties"
const JSKW_PROP_PATTERN = "patternProperties"
const JSKW_PROP_NAMES = "propertyNames"
const JSKW_PROP_MIN = "minProperties"
const JSKW_PROP_MAX = "maxProperties"
const JSKW_DEPEND = "dependencies"
const JSKW_LENGTH_MIN = "minLength"
const JSKW_LENGTH_MAX = "maxLength"
const JSKW_PATTERN = "pattern"
const JSKW_FORMAT = "format"
const JSKW_COLOR = "color"

const JSM_GREATER = "greater"
const JSM_GREATER_EQ = "greater or equal"
const JSM_LESS = "less"
const JSM_LESS_EQ = "less or equal"
const JSM_OBJ_DICT = "object (dictionary)"

const JSL_AND = "%s and %s"
const JSL_OR = "%s or %s"

const ERR_SCHEMA_FALSE = "Schema declared as deny all"
const ERR_WRONG_SCHEMA_GEN = "Schema error: "
const ERR_WRONG_SCHEMA_TYPE = "Schema error: schema must be empty object or object with 'type' keyword or boolean value"
const ERR_WRONG_SHEMA_NOTA = "Schema error: expected that all elements of '%s.%s' must be '%s'"
const ERR_WRONG_PROP_TYPE = "Schema error: any schema item must be object with 'type' keyword"
const ERR_REQ_PROP_GEN = "Schema error: expected array of required properties for '%s'"
const ERR_REQ_PROP_MISSING = "Missing required property: '%s' for '%s'"
const ERR_NO_PROP_ADD = "Additional properties are not required: found '%s'"
const ERR_FEW_PROP = "%d propertie(s) are not enough properties, at least %d are required"
const ERR_MORE_PROP = "%d propertie(s) are too many properties, at most %d are allowed"
const ERR_FEW_ITEMS = "%s item(s) are not enough items, at least %s are required"
const ERR_MORE_ITEMS = "%s item(s) are too many items, at most %s are allowed"
const ERR_INVALID_JSON_GEN = "Validation fails with message: %s"
const ERR_INVALID_JSON_EXT = "Invalid JSON data passed with message: %s"
const ERR_TYPE_MISMATCH_GEN = "Type mismatch: expected %s for '%s'"
const ERR_INVALID_NUMBER = "The %s key that equals %s should have a maximum of %s decimal places"
const ERR_INVALID_MULT = "Multiplier in key %s that equals %s must be greater or equal to %s"
const ERR_MULT_D = "Key %s that equal %d must be multiple of %d"
const ERR_MULT_F = "Key %s that equal %f must be multiple of %f"
const ERR_RANGE_D = "Key %s that equal %d must be %s than %d"
const ERR_RANGE_F = "Key %s that equal %f must be %s than %f"
const ERR_RANGE_S = "Length of '%s' (%d) %s than declared (%d)"
const ERR_WRONG_PATTERN = "String '%s' does not match its corresponding pattern"
const ERR_FORMAT = "String '%s' does not match its corresponding format '%s'"

# This is one and only function that need you to call outside
# If all validation checks passes, this OK
func validate(json_data : String, schema: String) -> String:
	var error: int

	var json = JSON.new()
	# General validation input data as JSON file
	error = json.parse(json_data)
	if error: return ERR_INVALID_JSON_EXT % error_string(error)

	# General validation input schema as JSONSchema file
	error = json.parse(schema)
	if not error == OK : return ERR_WRONG_SCHEMA_GEN + error_string(error)
	var test_json_conv = JSON.new()
	test_json_conv.parse(schema)
	var parsed_schema = test_json_conv.get_data()
	match typeof(parsed_schema):
		TYPE_BOOL:
			if !parsed_schema:
				return ERR_INVALID_JSON_GEN % ERR_SCHEMA_FALSE
			else:
				return ""
		TYPE_DICTIONARY:
			if parsed_schema.is_empty():
				return ""
			elif parsed_schema.keys().size() > 0 && !parsed_schema.has(JSKW_TYPE):
				return ERR_WRONG_SCHEMA_TYPE
		_: return ERR_WRONG_SCHEMA_TYPE

	# All inputs seems valid. Begin type validation
	# Normal return empty string, meaning OK
	return _type_selection(json_data, parsed_schema)

func _to_string():
	return "[JSONSchema:%d]" % get_instance_id()

# TODO: title, description, default, examples, $comment, enum, const
func _type_selection(json_data: String, schema: Dictionary, key: String = DEF_KEY_NAME) -> String:
	# If the schema is an empty object it always passes validation
	if schema.is_empty():
		return ""

	if typeof(schema) == TYPE_BOOL:
		# If the schema is true it always passes validation
		if schema:
			return ""
		# If the schema is false it always vales validation
		else:
			return ERR_INVALID_JSON_GEN + "false is always invalid"

	var typearr: Array = _var_to_array(schema.type)
	var test_json_conv = JSON.new()
	test_json_conv.parse(json_data)
	var parsed_data = test_json_conv.get_data()
	var error: String = ERR_TYPE_MISMATCH_GEN % [typearr, key]
	for type in typearr:
		match type:
			JST_ARRAY:
				if typeof(parsed_data) == TYPE_ARRAY:
					error = _validate_array(parsed_data, schema, key)
				else:
					error = ERR_TYPE_MISMATCH_GEN % [[JST_ARRAY], key]
			JST_BOOLEAN:
				if typeof(parsed_data) != TYPE_BOOL:
					return ERR_TYPE_MISMATCH_GEN % [[JST_BOOLEAN], key]
				else:
					error = ""
			JST_INTEGER:
				if typeof(parsed_data) == TYPE_INT:
					error = _validate_integer(parsed_data, schema, key)
				if typeof(parsed_data) == TYPE_FLOAT && parsed_data == int(parsed_data):
					error = _validate_integer(int(parsed_data), schema, key)
			JST_NULL:
				if typeof(parsed_data) != TYPE_NIL:
					return ERR_TYPE_MISMATCH_GEN % [[JST_NULL], key]
				else:
					error = ""
			JST_NUMBER:
				if typeof(parsed_data) == TYPE_FLOAT:
					error = _validate_number(parsed_data, schema, key)
				else:
					error = ERR_TYPE_MISMATCH_GEN % [[JST_NUMBER], key]
			JST_OBJECT:
				if typeof(parsed_data) == TYPE_DICTIONARY:
					error = _validate_object(parsed_data, schema, key)
				else:
					error = ERR_TYPE_MISMATCH_GEN % [[JST_OBJECT], key]
			JST_STRING:
				if typeof(parsed_data) == TYPE_STRING:
					error = _validate_string(parsed_data, schema, key)
				else:
					error = ERR_TYPE_MISMATCH_GEN % [[JST_STRING], key]
	return error


func _var_to_array(variant) -> Array:
	var result : Array = []
	if typeof(variant) == TYPE_ARRAY:
		result = variant
	else:
		result.append(variant)
	return result

func _validate_array(input_data: Array, input_schema: Dictionary, property_name: String = DEF_KEY_NAME) -> String:
	# TODO: contains minContains maxContains uniqueItems

	# Initialize variables
	var error : String = "" # Variable to store any error messages
	var items_array : Array # Array of items in the schema
	var suberror : Array = [] # Array of suberrors in each item
	var additional_items_schema: Dictionary # Schema for additional items in the input data
	var is_additional_item_allowed: bool # Flag to check if additional items are allowed

	# Check if minItems key exists in the schema
	if input_schema.has(JSKW_MIN_ITEMS):
		# Check if non negative number
		if input_schema.minItems < 0:
			return ERR_WRONG_SCHEMA_GEN + "minItems must be a non-negative number."

		if input_data.size() < input_schema.minItems:
			return ERR_FEW_ITEMS % [input_data.size(), input_schema.minItems]

	# Check if maxItems key exists in the schema
	if input_schema.has(JSKW_MAX_ITEMS):
			# Check if non negative number
			if input_schema.maxItems < 0:
				return ERR_WRONG_SCHEMA_GEN + "minItems must be a non-negative number."

			if input_data.size() > input_schema.maxItems:
				return ERR_MORE_ITEMS % [input_data.size(), input_schema.maxItems]

	# Check if prefixItems key exists in the schema
	if input_schema.has(JSKW_PREFIX_ITEMS):
		# Check if items key exists in the schema
		if not input_schema.has(JSKW_ITEMS):
			return ERR_REQ_PROP_MISSING % [JSKW_ITEMS, JSKW_PREFIX_ITEMS]

		# Return error if items key is not a bool or a dictionary
		if not typeof(input_schema.items) == TYPE_DICTIONARY and not typeof(input_schema.items) == TYPE_BOOL:
			return ERR_WRONG_SCHEMA_TYPE

		if typeof(input_schema.items) == TYPE_BOOL:
			# Check if additional items in the input data are allowed
			if input_schema.items == false:
				# Check if there are more items in the input data than specified in prefixItems
				if input_data.size() > input_schema.prefixItems.size():
					# Create an error message if there are more items than allowed
					var substr := "Array '%s' is of size %s but no addition items allowed." % [input_data, input_data.size()]
					return ERR_INVALID_JSON_GEN % substr
			# If the 'items' key is set to true all types are allowed for addition items.
			else:
				additional_items_schema = {}

		# Check if items key is a dictionary
		if typeof(input_schema.items) == TYPE_DICTIONARY:
			# Any items after the specified ones in prefixItems have to be validated with this schema
			# Set the schema for additional array items
			additional_items_schema = input_schema.items

		# Check if all entries in prefixItems are a dictionary
		for schema in input_schema.prefixItems:
			if typeof(schema) != TYPE_DICTIONARY:
				return ERR_WRONG_SHEMA_NOTA % [property_name, JSKW_ITEMS, JST_OBJECT]

		# Check every item in the input data
		for index in input_data.size():
			var item = input_data[index]
			var current_schema: Dictionary
			var key_substr: String

			if index <= input_schema.prefixItems.size() - 1:
				# As long as there are prefixItems in the array work with those
				current_schema = input_schema.prefixItems[index]
				key_substr = ".prefixItems"
			else:
				# After that use the items schema
				current_schema = additional_items_schema
				key_substr = ".items"

			var sub_error_message := _type_selection(JSON.stringify(item), current_schema, property_name + key_substr + "[" + str(index) + "]")
			if not sub_error_message == "":
				suberror.append(sub_error_message)

		if suberror.size() > 0:
			return ERR_INVALID_JSON_GEN % str(suberror)

		# Return inside this if block, because we don't want to validate the items key twice.
		return error

	# Check if items key exists in the schema
	if input_schema.has(JSKW_ITEMS):
		#'items' must be an object
		if not typeof(input_schema.items) == TYPE_DICTIONARY:
			return ERR_WRONG_SHEMA_NOTA % [property_name, JSKW_ITEMS, JST_OBJECT]

		# Check every item of input Array on
		for index in input_data.size():
			index = index - 1

			# Validate the array item with the schema defined by the 'items' key
			var sub_error_message := _type_selection(JSON.stringify(input_data[index]), input_schema.items, property_name + "[" + str(index) + "]")
			if not sub_error_message == "":
				suberror.append(sub_error_message)

			if suberror.size() > 0:
				return ERR_INVALID_JSON_GEN % str(suberror)

	return error

func _validate_boolean(input_data: bool, input_schema: Dictionary, property_name: String = DEF_KEY_NAME) -> String:
	# nothing to check
	return ""

func _validate_integer(input_data: int, input_schema: Dictionary, property_name: String = DEF_KEY_NAME) -> String:
	# all processing is performed in
	return _validate_number(input_data, input_schema, property_name)

func _validate_null(input_data, input_schema: Dictionary, property_name: String = DEF_KEY_NAME) -> String:
	# nothing to check
	return ""

func _validate_number(input_data: float, input_schema: Dictionary, property_name: String = DEF_KEY_NAME) -> String:
	var types: Array = _var_to_array(input_schema.type)
	# integer mode turns on only if types has integer and has not number
	var integer_mode: bool = types.has(JST_INTEGER) && !types.has(JST_NUMBER)

	# Processing multiple check
	if input_schema.has(JSKW_MULT_OF):
		var mult: float
		var mod: float
		var is_zero: bool

		# Get the multipleOf value from the schema and convert to float
		mult = float(input_schema[JSKW_MULT_OF])
		# Convert to integer if integer_mode is enabled
		mult = int(mult) if integer_mode else mult

		# Check if the number has more decimal places then allowed
		var decimal_places := str(input_data).get_slice('.', 1)
		if not decimal_places.is_empty() and decimal_places.length() > MAX_DECIMAL_PLACES:
			return ERR_INVALID_NUMBER % [property_name, input_data, str(MAX_DECIMAL_PLACES)]

		# Check if multipleOf is smaller than SMALL_FLOAT_THRESHOLD
		if not mult >= SMALL_FLOAT_THRESHOLD:
			return ERR_INVALID_MULT % [property_name, mult, str(SMALL_FLOAT_THRESHOLD)]

		# Multiply by a big number if input is smaller than 1 to prevent float issues
		if input_data < 1.0 or mult < 1.0:
			mod = fmod(input_data * 1000, mult * 1000)
		else:
			mod = fmod(input_data, mult)

		# Check if the remainder is close to zero
		is_zero = is_zero_approx(mod)

		# Return error message if remainder is not close to zero
		if not is_zero:
			if integer_mode:
				return ERR_MULT_D % [property_name, input_data, mult]
			else:
				return ERR_MULT_F % [property_name, input_data, mult]

	# processing minimum check
	if input_schema.has(JSKW_MINIMUM):
		var minimum = float(input_schema[JSKW_MINIMUM])
		minimum = int(minimum) if integer_mode else minimum
		if input_data < minimum:
			if integer_mode:
				return ERR_RANGE_D % [property_name, input_data, JSM_GREATER_EQ, minimum]
			else:
				return ERR_RANGE_F % [property_name, input_data, JSM_GREATER_EQ, minimum]

	# processing exclusive minimum check
	if input_schema.has(JSKW_MIN_EX):
		var minimum = float(input_schema[JSKW_MIN_EX])
		minimum = int(minimum) if integer_mode else minimum
		if input_data <= minimum:
			if integer_mode:
				return ERR_RANGE_D % [property_name, input_data, JSM_GREATER, minimum]
			else:
				return ERR_RANGE_F % [property_name, input_data, JSM_GREATER, minimum]

	# processing maximum check
	if input_schema.has(JSKW_MAXIMUM):
		var maximum = float(input_schema[JSKW_MAXIMUM])
		maximum = int(maximum) if integer_mode else maximum
		if input_data > maximum:
			if integer_mode:
				return ERR_RANGE_D % [property_name, input_data, JSM_LESS_EQ, maximum]
			else:
				return ERR_RANGE_F % [property_name, input_data, JSM_LESS_EQ, maximum]

	# processing exclusive minimum check
	if input_schema.has(JSKW_MAX_EX):
		var maximum = float(input_schema[JSKW_MAX_EX])
		maximum = int(maximum) if integer_mode else maximum
		if input_data >= maximum:
			if integer_mode:
				return ERR_RANGE_D % [property_name, input_data, JSM_LESS, maximum]
			else:
				return ERR_RANGE_F % [property_name, input_data, JSM_LESS, maximum]

	return ""

func _validate_object(input_data: Dictionary, input_schema: Dictionary, property_name: String = DEF_KEY_NAME) -> String:
	# TODO: patternProperties
	var error : String = ""

	# Process dependencies
	if input_schema.has(JSKW_DEPEND):
		for dependency in input_schema.dependencies.keys():
			if input_data.has(dependency):
				match typeof(input_schema.dependencies[dependency]):
					TYPE_ARRAY:
						if input_schema.has(JSKW_REQ):
							for property in input_schema.dependencies[dependency]:
								input_schema.required.append(property)
						else:
							input_schema.required = input_schema.dependencies[dependency]
					TYPE_DICTIONARY:
						for key in input_schema.dependencies[dependency].keys():
							if input_schema.has(key):
								match typeof(input_schema[key]):
									TYPE_ARRAY:
										for element in input_schema.dependencies[dependency][key]:
											input_schema[key].append(element)
									TYPE_DICTIONARY:
										for element in input_schema.dependencies[dependency][key].keys():
											input_schema[key][element] = input_schema.dependencies[dependency][key][element]
									_:
										input_schema[key] = input_schema.dependencies[dependency][key]
							else:
								input_schema[key] = input_schema.dependencies[dependency][key]
					_:
						return ERR_WRONG_SCHEMA_GEN + ERR_TYPE_MISMATCH_GEN % [JSL_OR % [JST_ARRAY, JSM_OBJ_DICT], property_name]

	# Process properties
	if input_schema.has(JSKW_PROP):

		# Process required
		if input_schema.has(JSKW_REQ):
			if typeof(input_schema.required) != TYPE_ARRAY: return ERR_REQ_PROP_GEN % property_name
			for i in input_schema.required:
				if !input_data.has(i): return ERR_REQ_PROP_MISSING % [i, property_name]

		# Continue validating schema subelements
		if typeof(input_schema.properties) != TYPE_DICTIONARY:
			return ERR_WRONG_SCHEMA_GEN + ERR_TYPE_MISMATCH_GEN % [JSM_OBJ_DICT, property_name]

		# Process property items
		for key in input_schema.properties:
			if !input_schema.properties[key].has(JSKW_TYPE):
				return ERR_WRONG_PROP_TYPE
			if input_data.has(key):
				error = _type_selection(JSON.stringify(input_data[key]), input_schema.properties[key], key)
			else:
				pass
			if error: return error

	# Process additional properties
	if input_schema.has(JSKW_PROP_ADD):
		match typeof(input_schema.additionalProperties):
			TYPE_BOOL:
				if not input_schema.additionalProperties:
					for key in input_data:
						if not input_schema.properties.has(key):
							return ERR_NO_PROP_ADD % key
			TYPE_DICTIONARY:
				for key in input_data:
					if not input_schema.properties.has(key):
						return _type_selection(JSON.stringify(input_data[key]), input_schema.additionalProperties, key)
			_:
				return ERR_WRONG_SCHEMA_GEN + ERR_TYPE_MISMATCH_GEN % [JSL_OR % [JST_BOOLEAN, JSM_OBJ_DICT], property_name]

	# Process properties names
	if input_schema.has(JSKW_PROP_NAMES):
		if typeof(input_schema.propertyNames) != TYPE_DICTIONARY:
			return ERR_WRONG_SCHEMA_GEN + ERR_TYPE_MISMATCH_GEN % [JSM_OBJ_DICT, property_name]
		for key in input_data:
			error = _validate_string(key, input_schema.propertyNames, key)
			if error: return error

	# Process minProperties maxProperties
	if input_schema.has(JSKW_PROP_MIN):
		if typeof(input_schema[JSKW_PROP_MIN]) != TYPE_FLOAT:
			return ERR_WRONG_SCHEMA_GEN + ERR_TYPE_MISMATCH_GEN % [JST_INTEGER, property_name]
		if input_data.keys().size() < input_schema[JSKW_PROP_MIN]:
			return ERR_FEW_PROP % [input_data.keys().size(), input_schema[JSKW_PROP_MIN]]

	if input_schema.has(JSKW_PROP_MAX):
		if typeof(input_schema[JSKW_PROP_MAX]) != TYPE_FLOAT:
			return ERR_WRONG_SCHEMA_GEN + ERR_TYPE_MISMATCH_GEN % [JST_INTEGER, property_name]
		if input_data.keys().size() > input_schema[JSKW_PROP_MAX]:
			return ERR_MORE_PROP % [input_data.keys().size(), input_schema[JSKW_PROP_MAX]]

	return error

func _validate_string(input_data: String, input_schema: Dictionary, property_name: String = DEF_KEY_NAME) -> String:
	# TODO: format
	var error : String = ""
	if input_schema.has(JSKW_LENGTH_MIN):
		if not (typeof(input_schema[JSKW_LENGTH_MIN]) == TYPE_INT || typeof(input_schema[JSKW_LENGTH_MIN]) == TYPE_FLOAT):
			return ERR_TYPE_MISMATCH_GEN % [JST_INTEGER, property_name+"."+JSKW_LENGTH_MIN]
		if input_data.length() < input_schema[JSKW_LENGTH_MIN]:
			return ERR_INVALID_JSON_GEN % ERR_RANGE_S % [property_name, input_data.length(), JSM_LESS ,input_schema[JSKW_LENGTH_MIN]]

	if input_schema.has(JSKW_LENGTH_MAX):
		if not (typeof(input_schema[JSKW_LENGTH_MAX]) == TYPE_INT || typeof(input_schema[JSKW_LENGTH_MAX]) == TYPE_FLOAT):
			return ERR_TYPE_MISMATCH_GEN % [JST_INTEGER, property_name+"."+JSKW_LENGTH_MAX]
		if input_data.length() > input_schema[JSKW_LENGTH_MAX]:
			return ERR_INVALID_JSON_GEN % ERR_RANGE_S % [property_name, input_data.length(), JSM_GREATER, input_schema[JSKW_LENGTH_MAX]]

	if input_schema.has(JSKW_PATTERN):
		if not (typeof(input_schema[JSKW_PATTERN]) == TYPE_STRING):
			return ERR_TYPE_MISMATCH_GEN % [JST_STRING, property_name+"."+JSKW_PATTERN]
		var regex = RegEx.new()
		regex.compile(input_schema[JSKW_PATTERN])
		if regex.search(input_data) == null:
			return ERR_INVALID_JSON_GEN % ERR_WRONG_PATTERN % property_name

	if input_schema.has(JSKW_FORMAT):
		# validate "color" format
		if input_schema.format.to_lower() == JSKW_COLOR:
			if not input_data.is_valid_html_color():
				return ERR_INVALID_JSON_GEN % ERR_FORMAT % [property_name, JSKW_COLOR]

	return error
