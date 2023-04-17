class_name ModLoaderGodot
extends Object

# API methods for interacting with Godot

const LOG_NAME := "ModLoader:Godot"


# Check the index position of the provided autoload (0 = 1st, 1 = 2nd, etc).
# Returns a bool if the position does not match.
# Optionally triggers a fatal error
static func check_autoload_position(autoload_name: String, position_index: int, trigger_error: bool = false) -> bool:
	var autoload_array := ModLoaderUtils.get_autoload_array()
	var autoload_index := autoload_array.find(autoload_name)
	var position_matches := autoload_index == position_index

	if not position_matches and trigger_error:
		var error_msg := "Expected %s to be the autoload in position %s, but this is currently %s." % [autoload_name, str(position_index + 1), autoload_array[position_index]]
		var help_msg := ""

		if OS.has_feature("editor"):
			help_msg = " To configure your autoloads, go to Project > Project Settings > Autoload."

		ModLoaderLog.fatal(error_msg + help_msg, LOG_NAME)

	return position_matches
