extends Object

const REQUIRE_EXPLICIT_ADDITION := false
const METHOD_PREFIX := "vanilla_"
const HASH_COLLISION_ERROR := \
	"MODDING EXPORT ERROR: Hash collision between %s and %s. The collision can be resolved by renaming one of the methods or changing their script's path."
const MOD_LOADER_HOOKS_START_STRING := \
	"\n# ModLoader Hooks - The following code has been automatically added by the Godot Mod Loader export plugin."


## finds function names used as setters and getters (excluding inline definitions)
## group 2 and 4 contain the xetter names
static var regex_getter_setter := RegEx.create_from_string("(.*?[sg]et\\s*=\\s*)(\\w+)(\\g<1>)?(\\g<2>)?")

## finds every instance where super() is called
## returns only the super word, excluding the (, as match to make substitution easier
static var regex_super_call := RegEx.create_from_string("\\bsuper(?=\\s*\\()")

## matches the indented function body
## needs to start from the : of a function definition to work (offset)
## the body of a function is every line that is empty or starts with an indent or comment
static var regex_func_body := RegEx.create_from_string("(?smn)\\N*(\\n^(([\\t #]+\\N*)|$))*")


var hashmap := {}


func process_begin() -> void:
	hashmap.clear()


func process_script(path: String) -> String:
	var current_script := load(path) as GDScript
	var source_code := current_script.source_code
	var source_code_additions := ""

	# We need to stop all vanilla methods from forming inheritance chains,
	# since the generated methods will fulfill inheritance requirements
	var class_prefix := str(hash(path))
	var method_store: Array[String] = []

	var getters_setters := collect_getters_and_setters(source_code)

	var moddable_methods := current_script.get_script_method_list().filter(
		func is_func_moddable(method: Dictionary):
			if getters_setters.has(method.name):
				return false

			var method_first_line_start := get_index_at_method_start(method.name, source_code)
			if method_first_line_start == -1:
				return false

			if not is_func_marked_moddable(method_first_line_start, source_code):
				return false

			return true
	)

	for method in moddable_methods:
		if method.name in method_store:
			continue

		var type_string := get_return_type_string(method.return)
		var is_static := true if method.flags == METHOD_FLAG_STATIC + METHOD_FLAG_NORMAL else false
		var method_arg_string_with_defaults_and_types := get_function_parameters(method.name, source_code, is_static)
		var method_arg_string_names_only := get_function_arg_name_string(method.args)

		var hash_before := ModLoaderMod.get_hook_hash(path, method.name, true)
		var hash_after := ModLoaderMod.get_hook_hash(path, method.name, false)
		var hash_before_data := [path, method.name,true]
		var hash_after_data := [path, method.name,false]
		if hashmap.has(hash_before):
			push_error(HASH_COLLISION_ERROR%[hashmap[hash_before], hash_before_data])
		if hashmap.has(hash_after):
			push_error(HASH_COLLISION_ERROR %[hashmap[hash_after], hash_after_data])
		hashmap[hash_before] = hash_before_data
		hashmap[hash_after] = hash_after_data

		var mod_loader_hook_string := get_mod_loader_hook(
			method.name,
			method_arg_string_names_only,
			method_arg_string_with_defaults_and_types,
			type_string,
			method.return.usage,
			is_static,
			path,
			hash_before,
			hash_after,
			METHOD_PREFIX + class_prefix,
		)

		# Store the method name
		# Not sure if there is a way to get only the local methods in a script,
		# get_script_method_list() returns a full list,
		# including the methods from the scripts it extends,
		# which leads to multiple entries in the list if they are overridden by the child script.
		method_store.push_back(method.name)
		source_code = edit_vanilla_method(method.name, is_static, source_code, METHOD_PREFIX + class_prefix)
		source_code_additions += "\n%s" % mod_loader_hook_string

	#if we have some additions to the code, append them at the end
	if source_code_additions != "":
		source_code = "%s\n%s\n%s" % [source_code, MOD_LOADER_HOOKS_START_STRING, source_code_additions]

	return source_code



static func get_function_arg_name_string(args: Array) -> String:
	var arg_string := ""
	for x in args.size():
		if x == args.size() -1:
			arg_string += args[x].name
		else:
			arg_string += "%s, " % args[x].name

	return arg_string


static func get_function_parameters(method_name: String, text: String, is_static: bool, offset := 0) -> String:
	var result := match_func_with_whitespace(method_name, text, offset)
	if result == null:
		return ""

	# Find the index of the opening parenthesis
	var opening_paren_index := result.get_end() - 1
	if opening_paren_index == -1:
		return ""

	if not is_top_level_func(text, result.get_start(), is_static):
		return get_function_parameters(method_name, text, is_static, result.get_end())

	var closing_paren_index := get_closing_paren_index(opening_paren_index, text)
	if closing_paren_index == -1:
		return ""

	# Extract the substring between the parentheses
	var param_string := text.substr(opening_paren_index + 1, closing_paren_index - opening_paren_index - 1)

	# Clean whitespace characters (spaces, newlines, tabs)
	param_string = param_string.strip_edges()\
		.replace(" ", "")\
		.replace("\n", "")\
		.replace("\t", "")\
		.replace(",", ", ")\
		.replace(":", ": ")

	return param_string


static func get_closing_paren_index(opening_paren_index: int, text: String) -> int:
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
		return -1

	return closing_paren_index


static func edit_vanilla_method(method_name: String, is_static: bool, text: String, prefix := METHOD_PREFIX, offset := 0) -> String:
	var func_def := match_func_with_whitespace(method_name, text, offset)

	if not func_def:
		return text

	if not is_top_level_func(text, func_def.get_start(), is_static):
		return edit_vanilla_method(method_name, is_static, text, prefix, func_def.get_end())

	text = fix_method_super(method_name, func_def.get_end(), text)
	text = text.erase(func_def.get_start(), func_def.get_end() - func_def.get_start())
	text = text.insert(func_def.get_start(), "func %s_%s(" % [prefix, method_name])

	return text


static func fix_method_super(method_name: String, func_def_end: int, text: String, offset := 0) -> String:
	var closing_paren_index := get_closing_paren_index(func_def_end, text)
	var func_body_start_index := text.find(":", closing_paren_index) +1

	var func_body := regex_func_body.search(text, func_body_start_index)
	if not func_body:
		return text
	var func_body_end_index := func_body.get_end()

	text = regex_super_call.sub(
		text, "super.%s" % method_name,
		true, func_body_start_index, func_body_end_index
	)

	return text


static func match_func_with_whitespace(method_name: String, text: String, offset := 0) -> RegExMatch:
	var func_with_whitespace := RegEx.create_from_string("func\\s+%s\\s*\\(" % method_name)

	# Search for the function definition
	return func_with_whitespace.search(text, offset)


static func get_mod_loader_hook(
	method_name: String,
	method_arg_string_names_only: String,
	method_arg_string_with_defaults_and_types: String,
	method_type: String,
	return_prop_usage: int,
	is_static: bool,
	script_path: String,
	hash_before:int,
	hash_after:int,
	method_prefix := METHOD_PREFIX) -> String:
	var type_string := " -> %s" % method_type if not method_type.is_empty() else ""
	var static_string := "static " if is_static else ""
	# Cannot use "self" inside a static function.
	var self_string := "null" if is_static else "self"
	var return_var := "var %s = " % "return_var" if not method_type.is_empty() or return_prop_usage == 131072 else ""
	var method_return := "return %s" % "return_var" if not method_type.is_empty() or return_prop_usage == 131072 else ""

	return """
{%STATIC%}func {%METHOD_NAME%}({%METHOD_PARAMS%}){%RETURN_TYPE_STRING%}:
	if ModLoaderStore.any_mod_hooked:
		ModLoaderMod.call_hooks({%SELF%}, [{%METHOD_ARGS%}], {%HOOK_ID_BEFORE%})
	{%METHOD_RETURN_VAR%}{%METHOD_PREFIX%}_{%METHOD_NAME%}({%METHOD_ARGS%})
	if ModLoaderStore.any_mod_hooked:
		ModLoaderMod.call_hooks({%SELF%}, [{%METHOD_ARGS%}], {%HOOK_ID_AFTER%})
	{%METHOD_RETURN%}""".format({
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
		"%HOOK_ID_BEFORE%" : hash_before,
		"%HOOK_ID_AFTER%" : hash_after,
	})


static func get_previous_line_to(text: String, index: int) -> String:
	if index <= 0 or index >= text.length():
		return ""

	var start_index := index - 1
	# Find the end of the previous line
	while start_index > 0 and text[start_index] != "\n":
		start_index -= 1

	if start_index == 0:
		return ""

	start_index -= 1

	# Find the start of the previous line
	var end_index := start_index
	while start_index > 0 and text[start_index - 1] != "\n":
		start_index -= 1

	return text.substr(start_index, end_index - start_index + 1)


static func is_func_marked_moddable(method_start_idx, text) -> bool:
	var prevline := get_previous_line_to(text, method_start_idx)

	if prevline.contains("@not-moddable"):
		return false
	if not REQUIRE_EXPLICIT_ADDITION:
		return true

	return prevline.contains("@moddable")


static func get_index_at_method_start(method_name: String, text: String) -> int:
	var result := match_func_with_whitespace(method_name, text)

	if result:
		return text.find("\n", result.get_end())
	else:
		return -1


static func is_top_level_func(text: String, result_start_index: int, is_static := false) -> bool:
	if is_static:
		result_start_index = text.rfind("static", result_start_index)

	var line_start_index := text.rfind("\n", result_start_index) + 1
	var pre_func_length := result_start_index - line_start_index

	if pre_func_length > 0:
		return false

	return true


static func get_return_type_string(return_data: Dictionary) -> String:
	if return_data.type == 0:
		return ""
	var type_base: String
	if return_data.has("class_name") and not str(return_data.class_name).is_empty():
		type_base = str(return_data.class_name)
	else:
		type_base = type_string(return_data.type)

	var type_hint := "" if return_data.hint_string.is_empty() else ("[%s]" % return_data.hint_string)

	return "%s%s" % [type_base, type_hint]


static func collect_getters_and_setters(text: String) -> Dictionary:
	var result := {}
	# a valid match has 2 or 4 groups, split into the method names and the rest of the line
	# (var example: set = )(example_setter)(, get = )(example_getter)
	# if things between the names are empty or commented, exclude them
	for mat in regex_getter_setter.search_all(text):
		if mat.get_string(1).is_empty() or mat.get_string(1).contains("#"):
			continue
		result[mat.get_string(2)] = null

		if mat.get_string(3).is_empty() or mat.get_string(3).contains("#"):
			continue
		result[mat.get_string(4)] = null

	return result
