extends EditorExportPlugin


const METHOD_PREFIX := "GodotModLoader"

func _get_name() -> String:
	return "Godot Mod Loader Export Plugin"


func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	if path.begins_with("res://addons") or path.begins_with("res://mods-unpacked"):
		return

	if not type == "GDScript":
		return

	var current_script := load(path) as GDScript
	var source_code := current_script.source_code

	print(path)

	var method_store: Array[String] = []

	var mod_loader_hooks_start_string := """
# ModLoader Hooks - The following code has been automatically added by the Godot Mod Loader export plugin.
"""

	source_code = "%s\n%s" % [source_code, mod_loader_hooks_start_string]

	print("--------------------Property List")
	print(JSON.stringify(current_script.get_script_property_list(), "\t"))
	print("--------------------Constant Map")
	print(JSON.stringify(current_script.get_script_constant_map(), "\t"))
	print("-------------------- Method List")
	print(JSON.stringify(current_script.get_script_method_list(), "\t"))
	print("--------------------")

	for method in current_script.get_script_method_list():
		var method_first_line_start := get_index_at_method_start(method.name, source_code)
		if method_first_line_start == -1 or method.name in method_store:
			continue
		#print(method.flags)
		var type_string := type_string(method.return.type) if not method.return.type == 0 else ""
		var is_static := true if method.flags == METHOD_FLAG_STATIC + METHOD_FLAG_NORMAL else false
		var method_arg_string_with_defaults_and_types := get_function_parameters(method.name, source_code)
		var method_arg_string_names_only := get_function_arg_name_string(method.args)
		var mod_loader_hook_string := get_mod_loader_hook(
			method.name,
			method_arg_string_names_only,
			method_arg_string_with_defaults_and_types,
			type_string,
			method.return.usage,
			is_static,
			path
		)

		# Store the method name
		# Not sure if there is a way to get only the local methods in a script,
		# get_script_method_list() returns a full list,
		# including the methods from the scripts it extends,
		# which leads to multiple entries in the list if they are overridden by the child script.
		method_store.push_back(method.name)
		source_code = prefix_method_name(method.name, source_code)
		source_code = "%s\n%s" % [source_code, mod_loader_hook_string]

	skip()
	add_file(path, source_code.to_utf8_buffer(), false)


static func handle_class_name(text: String) -> String:
	var class_name_start_index := text.find("class_name")
	if class_name_start_index == -1:
		return ""
	var class_name_end_index := text.find("\n", class_name_start_index)
	var class_name_line := text.substr(class_name_start_index, class_name_end_index - class_name_start_index)

	return class_name_line


static func handle_self_ref(global_name: String, text: String) -> String:
	return text.replace("self", "self as %s" % global_name)


static func get_function_arg_name_string(args: Array) -> String:
	var arg_string := ""
	for arg in args:
		arg_string += "%s, " % arg.name

	return arg_string


static func get_function_parameters(method_name: String, text: String) -> String:
	# Regular expression to match the function definition with arbitrary whitespace
	var pattern := "func\\s+" + method_name + "\\s*\\("
	var regex := RegEx.new()
	regex.compile(pattern)

	# Search for the function definition
	var result := regex.search(text)
	if result == null:
		return ""

	# Find the index of the opening parenthesis
	var opening_paren_index := result.get_end() - 1
	if opening_paren_index == -1:
		return ""

	# Use a stack to match parentheses
	var stack := []
	var closing_paren_index := opening_paren_index
	while closing_paren_index < text.length():
		var char := text[closing_paren_index]
		if char == '(':
			stack.push_back('(')
		elif char == ')':
			stack.pop_back()
			if stack.size() == 0:
				break
		closing_paren_index += 1

	# If the stack is not empty, that means there's no matching closing parenthesis
	if stack.size() != 0:
		return ""

	# Extract the substring between the parentheses
	var param_string := text.substr(opening_paren_index + 1, closing_paren_index - opening_paren_index - 1)

	# Remove all whitespace characters (spaces, newlines, tabs) from the parameter string
	param_string = param_string.replace(" ", "")
	param_string = param_string.replace("\n", "")
	param_string = param_string.replace("\t", "")

	return param_string


static func get_method_arg_string(method_name: String, text: String) -> String:
	var starting_index := text.find("func %s(" % method_name)
	return ""


static func prefix_method_name(method_name: String, text: String, prefix := METHOD_PREFIX) -> String:
	# Regular expression to match the function definition with arbitrary whitespace
	var pattern := "func\\s+%s\\s*\\(" % method_name
	var regex := RegEx.new()
	regex.compile(pattern)

	var result := regex.search(text)

	if result:
		return text.replace(result.get_string(), "func %s_%s(" % [prefix, method_name])
	else:
		print("WHAT?!")
		return text


static func get_mod_loader_hook(
	method_name: String,
	method_arg_string_names_only: String,
	method_arg_string_with_defaults_and_types: String,
	method_type: String,
	return_prop_usage: int,
	is_static: bool,
	script_path: String,
	method_prefix := METHOD_PREFIX) -> String:
	var type_string := " -> %s" % method_type if not method_type.is_empty() else ""
	var static_string := "static " if is_static else ""
	# Cannot use "self" inside a static function.
	var self_string := "null" if is_static else "self"
	var return_var := "var %s = " % "return_var" if not method_type.is_empty() or return_prop_usage == 131072 else ""
	var method_return := "return %s" % "return_var" if not method_type.is_empty() or return_prop_usage == 131072 else ""

	return """
{%STATIC%}func {%METHOD_NAME%}({%METHOD_PARAMS%}){%RETURN_TYPE_STRING%}:
	ModLoaderMod.call_from_callable_stack({%SELF%}, [{%METHOD_ARGS%}], "{%SCRIPT_PATH%}", "{%METHOD_NAME%}", true)
	{%METHOD_RETURN_VAR%}{%METHOD_PREFIX%}_{%METHOD_NAME%}({%METHOD_ARGS%})
	ModLoaderMod.call_from_callable_stack({%SELF%}, [{%METHOD_ARGS%}], "{%SCRIPT_PATH%}", "{%METHOD_NAME%}", false)
	{%METHOD_RETURN%}
""".format({
		"%METHOD_PREFIX%": method_prefix,
		"%METHOD_NAME%": method_name,
		"%METHOD_PARAMS%": method_arg_string_with_defaults_and_types,
		"%RETURN_TYPE_STRING%": type_string,
		"%METHOD_ARGS%": method_arg_string_names_only,
		"%SCRIPT_PATH%": script_path,
		"%METHOD_RETURN_VAR%": return_var,
		"%METHOD_RETURN%": method_return,
		"%STATIC%": static_string,
		"%SELF%": self_string,
	})


static func get_index_at_method_start(method_name: String, text: String) -> int:
	# Regular expression to match the function definition with arbitrary whitespace
	var pattern := "func\\s+%s\\s*\\(" % method_name
	var regex := RegEx.new()
	regex.compile(pattern)

	var result := regex.search(text)

	if result:
		return text.find("\n", result.get_end())
	else:
		return -1
