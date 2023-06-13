class_name ModLoaderDeprecated
extends Node

# API methods for deprecating funcs. Can be used by mods with public APIs.

const LOG_NAME := "ModLoader:Deprecated"


# A method has changed its name/class
static func deprecated_changed(old_method: String, new_method: String, since_version: String, show_removal_note: bool = true) -> void:
	_deprecated_log(str(
		"DEPRECATED: ",
		"The method \"%s\" has been deprecated since version %s. " % [old_method, since_version],
		"Please use \"%s\" instead. " % new_method,
		"The old method will be removed with the next major update, and will break your code if not changed. " if show_removal_note else ""
	))


# A method has been entirely removed, with no replacement
# (should never be needed but good to have just in case)
static func deprecated_removed(old_method: String, since_version: String, show_removal_note: bool = true) -> void:
	_deprecated_log(str(
		"DEPRECATED: ",
		"The method \"%s\" has been deprecated since version %s, and is no longer available. " % [old_method, since_version],
		"There is currently no replacement method. ",
		"The method will be removed with the next major update, and will break your code if not changed. " if show_removal_note else ""
	))


# Freeform deprecation message.
# Allows you to add a deprecation comment without specifying the old/new method
static func deprecated_message(msg: String, since_version: String = "") -> void:
	var since_text := " (since version %s)" % since_version if since_version else ""
	_deprecated_log(str("DEPRECATED: ", msg, since_text))


# Internal func for logging with support to trigger warnings instead of fatal
# errors
static func _deprecated_log(msg: String) -> void:
	if ModLoaderStore.ml_options.ignore_deprecated_errors or OS.has_feature("standalone"):
		ModLoaderLog.warning(msg, LOG_NAME)
	else:
		ModLoaderLog.fatal(msg, LOG_NAME)
