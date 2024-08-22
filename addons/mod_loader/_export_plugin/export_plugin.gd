extends EditorExportPlugin


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
	
	for method in new_script.get_script_method_list():
		var method_first_line_start := get_index_at_method_start(method.name, source_code)
		if method_first_line_start == -1 or method.name in method_store:
			continue
		var method_first_line_end := source_code.find("\n", method_first_line_start)
		var tab_count := source_code.count("\t", method_first_line_start, method_first_line_end)
		var tab_string := ""
		# Store the method name
		# Not sure if there is a way to get only the local methods in a script, 
		# get_script_method_list() returns a full list, 
		# including the methods from the scripts it extends,
		# which leads to multiple entries in the list if they are overridden by the child script.
		method_store.push_back(method.name)

		for i in tab_count:
			tab_string = "%s\t" % tab_string

		source_code = source_code.insert(
				method_first_line_start,
				tab_string + "ModLoaderMod.call_from_callable_stack(self, '%s', '%s', true)\n" % [path, method.name]
			)

		var method_end_index := get_index_at_method_end(method.name, source_code)
		source_code = source_code.insert(
				method_end_index,
				"\n" + tab_string + "ModLoaderMod.call_from_callable_stack(self, '%s', '%s', false)" % [path, method.name]
			)

	skip()
	add_file(path, source_code.to_utf8_buffer(), false)


static func get_index_at_method_start(method_name: String, text: String) -> int:
	var starting_index := text.find("func %s(" % method_name)
	
	if starting_index == -1:
		return -1
	
	var method_start_index := text.find("\n", starting_index)

	return method_start_index + 1


# TODO: How do we handle returns?
static func get_index_at_method_end(method_name: String, text: String) -> int:
	var starting_index := text.rfind("func %s(" % method_name)
	
	if starting_index == -1:
		return -1
	else:
		# Start behind func
		starting_index = starting_index + 5

	# Find the end of the method
	var next_method_line_index := text.find("func ", starting_index)
	var method_end := -1

	if next_method_line_index == -1:
		# Backtrack empty lines from the end of the file
		method_end = text.length() -1
	else:
		# Get the line before the next function line
		method_end = text.rfind("\n", next_method_line_index)

	# Backtrack to the last non-empty line
	var last_non_empty_line_index := method_end
	while last_non_empty_line_index > starting_index:
		last_non_empty_line_index -= 1
		# Remove spaces, tabs and newlines (whitespace) to check if the line really is empty
		if text[last_non_empty_line_index].rstrip("\t\n "):
			# Get the beginning of the line
			var line_start_index := text.rfind("\n", last_non_empty_line_index) + 1
			var line_end_index := text.find("\n", line_start_index)
			# Check if the line declares a variable
			if text.count("var ", line_start_index, line_end_index) > 0:
				continue
			if text.count("const ", line_start_index, line_end_index) > 0:
				continue
			# Check if the last line is a top level return
			var current_line := text.substr(line_start_index, line_end_index - line_start_index)
			print(current_line)
			if current_line.begins_with("\treturn "):
				continue
			
			break # encountered a filled line

	return last_non_empty_line_index +1
