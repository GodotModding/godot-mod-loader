class_name _ModLoaderScriptExtension
extends RefCounted

# This Class provides methods for working with script extensions.
# Currently all of the included methods are internal and should only be used by the mod loader itself.

const LOG_NAME := "ModLoader:ScriptExtension"


# Sort script extensions by inheritance and apply them in order
static func handle_script_extensions() -> void:
	var extension_paths := []
	for path in ModLoaderStore.script_extensions:
		if FileAccess.file_exists(path):
			extension_paths.push_back(path)
		else:
			ModLoaderLog.error("Extension script path '%s' does not exist" % [path], LOG_NAME)

	# sort by inheritance
	extension_paths.sort_custom(InheritanceSorting.new()._check_inheritances)

	# used to replace the extends clause in the script
	var extendsRegex := RegEx.new()
	extendsRegex.compile("(?m)^extends \\\"(.*)\\\"")

	var chains = {}

	# prepare extensions chains: apply extends overrides, copy orig, ...
	for path in extension_paths:
		var script: Script = ResourceLoader.load(path)
		var extending_script: Script = script.get_base_script()
		if not extending_script:
			ModLoaderLog.error("Extension script '%s' does not inherit from any other script" % [path], LOG_NAME)
			continue
		var extending_path: String = extending_script.resource_path
		if extending_path.is_empty():
			ModLoaderLog.error("extending_path in '%s' is empty ??" % [path], LOG_NAME)
			continue

		if not chains.has(extending_path):
			var orig_path := "res://mod_loader_temp/" + extending_path.trim_prefix("res://")
			# copy original script to the new path
			_write_file(orig_path, extending_script.source_code)
			chains[extending_path] = [ResourceLoader.load(orig_path)]

		var prev_path: String = chains[extending_path].front().resource_path
		ModLoaderLog.info("Patching extends: %s -> %s" % [path, prev_path], LOG_NAME)
		var patched_path := "res://mod_loader_temp/" + script.resource_path.trim_prefix("res://")
		_write_file(patched_path, extendsRegex.sub(script.source_code, "extends \"" + prev_path + "\""))
		chains[extending_path].push_front(ResourceLoader.load(patched_path))

	# apply final source code override and reload everything
	for extending_path in chains:
		var chain: Array = chains[extending_path]

		# overwrite real original script's code with the last extension,
		# the hierarchy would eventually reach our copied original script
		ModLoaderLog.info("Overwriting: %s -> %s" % [chain.front().resource_path, extending_path], LOG_NAME)
		var extending_script: Script = ResourceLoader.load(extending_path)
		extending_script.source_code = chain.front().source_code

		# reload order goes from orig to last applied extension
		ModLoaderLog.info("Reloading chain: %s" % [extending_path], LOG_NAME)
		for i in range(chain.size() - 1, 0, -1):
			var script: Script = chain[i]
			ModLoaderLog.info("  Reloading: %s" % [script.resource_path], LOG_NAME)
			script.reload()
		ModLoaderLog.info("  Reloading: %s" % [extending_path], LOG_NAME)
		extending_script.reload()

		# clear temp directory
		for i in range(chain.size() - 1, -1, -1):
			var p: String = chain[i].resource_path.trim_prefix("res://")
			while true:
				var err := DirAccess.remove_absolute(p)
				if err != Error.OK:
					break
				p = p.get_base_dir()
				if not p.begins_with("mod_loader_temp"):
					break

static func _write_file(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir().trim_prefix("res://"))
	FileAccess.open(path, FileAccess.ModeFlags.WRITE).store_string(contents)

# Sorts script paths by their ancestors.  Scripts are organized by their common
# ancestors then sorted such that scripts extending script A will be before
# a script extending script B if A is an ancestor of B.
class InheritanceSorting:
	var stack_cache := {}

	# Comparator function.  return true if a should go before b.  This may
	# enforce conditions beyond the stated inheritance relationship.
	func _check_inheritances(extension_a: String, extension_b: String) -> bool:
		var a_stack := cached_inheritances_stack(extension_a)
		var b_stack := cached_inheritances_stack(extension_b)

		var last_index: int
		for index in a_stack.size():
			if index >= b_stack.size():
				return false
			if a_stack[index] != b_stack[index]:
				return a_stack[index] < b_stack[index]
			last_index = index

		if last_index < b_stack.size():
			return true

		return extension_a < extension_b

	# Returns a list of scripts representing all the ancestors of the extension
	# script with the most recent ancestor last.
	#
	# Results are stored in a cache keyed by extension path
	func cached_inheritances_stack(extension_path: String) -> Array:
		if stack_cache.has(extension_path):
			return stack_cache[extension_path]

		var stack := []

		var parent_script: Script = load(extension_path)
		while parent_script:
			stack.push_front(parent_script.resource_path)
			parent_script = parent_script.get_base_script()
		stack.pop_back()

		stack_cache[extension_path] = stack
		return stack
