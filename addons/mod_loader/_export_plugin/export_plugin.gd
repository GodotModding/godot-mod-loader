extends EditorExportPlugin


const METHOD_PREFIX := "GodotModLoader"

func _get_name() -> String:
	return "Godot Mod Loader Export Plugin"


func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	if path.begins_with("res://addons"):
		return

	if not type == "GDScript":
		return

	var source_code := FileAccess.get_file_as_string(path)
	var new_script := GDScript.new()
	new_script.source_code = source_code
	new_script.reload()

	var method_store: Array[String] = []

	var mod_loader_hooks_start_string := """
# ModLoader Hooks - The following code has been automatically added by the Godot Mod Loader export plugin.
"""

	source_code = "%s\n%s" % [source_code, mod_loader_hooks_start_string]

	for method in new_script.get_script_method_list():
		var method_first_line_start := get_index_at_method_start(method.name, source_code)
		if method_first_line_start == -1 or method.name in method_store:
			continue

		var method_arg_string := get_function_parameters(method.name, source_code)
		var mod_loader_hook_string := get_mod_loader_hook(method.name, method_arg_string, path)

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


static func get_mod_loader_hook(method_name: String, method_param_string: String, script_path: String, method_prefix := METHOD_PREFIX) -> String:
	# Split parameters by commas
	var param_list := method_param_string.split(",")

	# Remove default values by splitting at '=' and taking the first part
	for i in range(param_list.size()):
		param_list[i] = param_list[i].split("=")[0]

	# Join the cleaned parameter names back into a string
	var arg_string := ",".join(param_list)
	param_list = method_param_string.split(",")

	# Remove types by splitting at ':' and taking the first part
	for i in range(param_list.size()):
		param_list[i] = param_list[i].split(":")[0]

	arg_string = ",".join(param_list)

	return """
func {%METHOD_NAME%}({%METHOD_PARAMS%}):
	ModLoaderMod.call_from_callable_stack(self, [{%METHOD_ARGS%}], "{%SCRIPT_PATH%}", "{%METHOD_NAME%}", true)
	{%METHOD_PREFIX%}_{%METHOD_NAME%}({%METHOD_ARGS%})
	ModLoaderMod.call_from_callable_stack(self, [{%METHOD_ARGS%}], "{%SCRIPT_PATH%}", "{%METHOD_NAME%}", false)
""".format({
		"%METHOD_PREFIX%": method_prefix,
		"%METHOD_NAME%": method_name,
		"%METHOD_PARAMS%": method_param_string,
		"%METHOD_ARGS%": arg_string,
		"%SCRIPT_PATH%": script_path,
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
