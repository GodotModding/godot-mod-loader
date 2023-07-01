class_name _ModLoaderScriptExtension
extends Reference


# This Class provides methods for working with script extensions.
# Currently all of the included methods are internal and should only be used by the mod loader itself.

const LOG_NAME := "ModLoader:ScriptExtension"

# Sort script extensions by inheritance and apply them in order
static func handle_script_extensions() -> void:
	var extension_paths := []
	for extension_path in ModLoaderStore.script_extensions:
		if File.new().file_exists(extension_path):
			extension_paths.push_back(extension_path)
		else:
			ModLoaderLog.error("The child script path '%s' does not exist" % [extension_path], LOG_NAME)
			
	# Sort by inheritance
	extension_paths.sort_custom(InheritanceSorting.new(), "_check_inheritances")
	
	# Load and install all extensions
	for extension in extension_paths:
		var script: Script = apply_extension(extension)
		_reload_vanilla_child_classes_for(script)


# Sorts script paths by their ancestors.  Scripts are organized by their common
# acnestors then sorted such that scripts extending script A will be before
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


static func apply_extension(extension_path: String) -> Script:
	# Check path to file exists
	if not File.new().file_exists(extension_path):
		ModLoaderLog.error("The child script path '%s' does not exist" % [extension_path], LOG_NAME)
		return null

	var child_script: Script = ResourceLoader.load(extension_path)
	# Adding metadata that contains the extension script path
	# We cannot get that path in any other way
	# Passing the child_script as is would return the base script path
	# Passing the .duplicate() would return a '' path
	child_script.set_meta("extension_script_path", extension_path)

	# Force Godot to compile the script now.
	# We need to do this here to ensure that the inheritance chain is
	# properly set up, and multiple mods can chain-extend the same
	# class multiple times.
	# This is also needed to make Godot instantiate the extended class
	# when creating singletons.
	# The actual instance is thrown away.
	child_script.new()

	var parent_script: Script = child_script.get_base_script()
	var parent_script_path: String = parent_script.resource_path

	# We want to save scripts for resetting later
	# All the scripts are saved in order already
	if not ModLoaderStore.saved_scripts.has(parent_script_path):
		ModLoaderStore.saved_scripts[parent_script_path] = []
		# The first entry in the saved script array that has the path
		# used as a key will be the duplicate of the not modified script
		ModLoaderStore.saved_scripts[parent_script_path].append(parent_script.duplicate())

	ModLoaderStore.saved_scripts[parent_script_path].append(child_script)

	ModLoaderLog.info("Installing script extension: %s <- %s" % [parent_script_path, extension_path], LOG_NAME)
	child_script.take_over_path(parent_script_path)

	return child_script

# Reload all children classes of the vanilla class we just extended
# Calling reload() the children of an extended class seems to allow them to be extended
# e.g if B is a child class of A, reloading B after apply an extender of A allows extenders of B to properly extend B, taking A's extender(s) into account
static func _reload_vanilla_child_classes_for(script: Script) -> void:
	if script == null:
		return
	var current_child_classes := []
	var actual_path: String = script.get_base_script().resource_path
	var classes: Array = ProjectSettings.get_setting("_global_script_classes")

	for _class in classes:
		if _class.path == actual_path:
			current_child_classes.push_back(_class)
			break

	for _class in current_child_classes:
		for child_class in classes:

			if child_class.base == _class.class:
				load(child_class.path).reload()


# Used to remove a specific extension
static func remove_specific_extension_from_script(extension_path: String) -> void:
	# Check path to file exists
	if not _ModLoaderFile.file_exists(extension_path):
		ModLoaderLog.error("The extension script path \"%s\" does not exist" % [extension_path], LOG_NAME)
		return

	var extension_script: Script = ResourceLoader.load(extension_path)
	var parent_script: Script = extension_script.get_base_script()
	var parent_script_path: String = parent_script.resource_path

	# Check if the script to reset has been extended
	if not ModLoaderStore.saved_scripts.has(parent_script_path):
		ModLoaderLog.error("The extension parent script path \"%s\" has not been extended" % [parent_script_path], LOG_NAME)
		return

	# Check if the script to reset has anything actually saved
	# If we ever encounter this it means something went very wrong in extending
	if not ModLoaderStore.saved_scripts[parent_script_path].size() > 0:
		ModLoaderLog.error("The extension script path \"%s\" does not have the base script saved, this should never happen, if you encounter this please create an issue in the github repository" % [parent_script_path], LOG_NAME)
		return

	var parent_script_extensions: Array = ModLoaderStore.saved_scripts[parent_script_path].duplicate()
	parent_script_extensions.remove(0)

	# Searching for the extension that we want to remove
	var found_script_extension: Script = null
	for script_extension in parent_script_extensions:
		if script_extension.get_meta("extension_script_path") == extension_path:
			found_script_extension = script_extension
			break

	if found_script_extension == null:
		ModLoaderLog.error("The extension script path \"%s\" has not been found in the saved extension of the base script" % [parent_script_path], LOG_NAME)
		return
	parent_script_extensions.erase(found_script_extension)

	# Preparing the script to have all other extensions reapllied
	_remove_all_extensions_from_script(parent_script_path)

	# Reapplying all the extensions without the removed one
	for script_extension in parent_script_extensions:
		apply_extension(script_extension.get_meta("extension_script_path"))


# Used to fully reset the provided script to a state prior of any extension
static func _remove_all_extensions_from_script(parent_script_path: String) -> void:
	# Check path to file exists
	if not _ModLoaderFile.file_exists(parent_script_path):
		ModLoaderLog.error("The parent script path \"%s\" does not exist" % [parent_script_path], LOG_NAME)
		return

	# Check if the script to reset has been extended
	if not ModLoaderStore.saved_scripts.has(parent_script_path):
		ModLoaderLog.error("The parent script path \"%s\" has not been extended" % [parent_script_path], LOG_NAME)
		return

	# Check if the script to reset has anything actually saved
	# If we ever encounter this it means something went very wrong in extending
	if not ModLoaderStore.saved_scripts[parent_script_path].size() > 0:
		ModLoaderLog.error("The parent script path \"%s\" does not have the base script saved, \nthis should never happen, if you encounter this please create an issue in the github repository" % [parent_script_path], LOG_NAME)
		return

	var parent_script: Script = ModLoaderStore.saved_scripts[parent_script_path][0]
	parent_script.take_over_path(parent_script_path)

	# Remove the script after it has been reset so we do not do it again
	ModLoaderStore.saved_scripts.erase(parent_script_path)


# Used to remove all extensions that are of a specific mod
static func remove_all_extensions_of_mod(mod: ModData) -> void:
	var _to_remove_extension_paths: Array = ModLoaderStore.saved_extension_paths[mod.manifest.get_mod_id()]
	for extension_path in _to_remove_extension_paths:
		remove_specific_extension_from_script(extension_path)
		ModLoaderStore.saved_extension_paths.erase(mod.manifest.get_mod_id())
