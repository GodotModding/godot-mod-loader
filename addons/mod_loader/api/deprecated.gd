# API methods for deprecating funcs. Can be used by mods with public APIs.
class_name ModLoaderDeprecated
extends Node


const LOG_NAME := "ModLoader:Deprecated"


# Marks a method that has changed its name or class.
#
# Parameters:
# - old_method (String): The name of the deprecated method.
# - new_method (String): The name of the new method to use.
# - since_version (String): The version number from which the method has been deprecated.
# - show_removal_note (bool): (optional) If true, includes a note about future removal of the old method. Default is true.
#
# Returns: void
static func deprecated_changed(old_method: String, new_method: String, since_version: String, show_removal_note: bool = true) -> void:
	_deprecated_log(str(
		"DEPRECATED: ",
		"The method \"%s\" has been deprecated since version %s. " % [old_method, since_version],
		"Please use \"%s\" instead. " % new_method,
		"The old method will be removed with the next major update, and will break your code if not changed. " if show_removal_note else ""
	))


# Marks a method that has been entirely removed, with no replacement.
# Note: This should rarely be needed but is included for completeness.
#
# Parameters:
# - old_method (String): The name of the removed method.
# - since_version (String): The version number from which the method has been deprecated.
# - show_removal_note (bool): (optional) If true, includes a note about future removal of the old method. Default is true.
#
# Returns: void
static func deprecated_removed(old_method: String, since_version: String, show_removal_note: bool = true) -> void:
	_deprecated_log(str(
		"DEPRECATED: ",
		"The method \"%s\" has been deprecated since version %s, and is no longer available. " % [old_method, since_version],
		"There is currently no replacement method. ",
		"The method will be removed with the next major update, and will break your code if not changed. " if show_removal_note else ""
	))


# Marks a method with a freeform deprecation message.
#
# Parameters:
# - msg (String): The deprecation message.
# - since_version (String): (optional) The version number from which the deprecation applies.
#
# Returns: void
static func deprecated_message(msg: String, since_version: String = "") -> void:
	var since_text := " (since version %s)" % since_version if since_version else ""
	_deprecated_log(str("DEPRECATED: ", msg, since_text))


# Internal function for logging deprecation messages with support to trigger warnings instead of fatal errors.
#
# Parameters:
# - msg (String): The deprecation message.
#
# Returns: void
static func _deprecated_log(msg: String) -> void:
	if ModLoaderStore and ModLoaderStore.ml_options.ignore_deprecated_errors or OS.has_feature("standalone"):
		ModLoaderLog.warning(msg, LOG_NAME)
	else:
		ModLoaderLog.fatal(msg, LOG_NAME)
