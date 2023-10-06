class_name _ModLoaderGodot
extends Object


# This Class provides methods for interacting with Godot.
# Currently all of the included methods are internal and should only be used by the mod loader itself.

const LOG_NAME := "ModLoader:Godot"
const AUTOLOAD_CONFIG_HELP_MSG := "To configure your autoloads, go to Project > Project Settings > Autoload."


# Check if autoload_name_before is before autoload_name_after
# Returns a bool if the position does not match.
# Optionally triggers a fatal error
static func check_autoload_order(autoload_name_before: String, autoload_name_after: String, trigger_error := false) -> bool:
	var autoload_name_before_index := get_autoload_index(autoload_name_before)
	var autoload_name_after_index := get_autoload_index(autoload_name_after)

	# Check if the Store is before the ModLoader
	if not autoload_name_before_index < autoload_name_after_index:
		var error_msg := (
			"Expected %s ( position: %s ) to be loaded before %s ( position: %s ). "
			% [autoload_name_before, autoload_name_before_index, autoload_name_after, autoload_name_after_index]
		)
		var help_msg := AUTOLOAD_CONFIG_HELP_MSG if OS.has_feature("editor") else ""

		if trigger_error:
			var final_message = error_msg + help_msg
			push_error(final_message)
			ModLoaderLog._write_to_log_file(final_message)
			ModLoaderLog._write_to_log_file(JSON.stringify(get_stack(), "  "))
			assert(false, final_message)

		return false

	return true


# Check the index position of the provided autoload (0 = 1st, 1 = 2nd, etc).
# Returns a bool if the position does not match.
# Optionally triggers a fatal error
static func check_autoload_position(autoload_name: String, position_index: int, trigger_error := false) -> bool:
	var autoload_array := get_autoload_array()
	var autoload_index := autoload_array.find(autoload_name)
	var position_matches := autoload_index == position_index

	if not position_matches and trigger_error:
		var error_msg := (
			"Expected %s to be the autoload in position %s, but this is currently %s. "
			% [autoload_name, str(position_index + 1), autoload_array[position_index]]
		)
		var help_msg := AUTOLOAD_CONFIG_HELP_MSG if OS.has_feature("editor") else ""
		var final_message = error_msg + help_msg

		push_error(final_message)
		ModLoaderLog._write_to_log_file(final_message)
		ModLoaderLog._write_to_log_file(JSON.stringify(get_stack(), "  "))
		assert(false, final_message)

	return position_matches


# Get an array of all autoloads -> ["autoload/AutoloadName", ...]
static func get_autoload_array() -> Array:
	var autoloads := []

	# Get all autoload settings
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.name
		if name.begins_with("autoload/"):
			autoloads.append(name.trim_prefix("autoload/"))

	return autoloads


# Get the index of a specific autoload
static func get_autoload_index(autoload_name: String) -> int:
	var autoloads := get_autoload_array()
	var autoload_index := autoloads.find(autoload_name)

	return autoload_index
