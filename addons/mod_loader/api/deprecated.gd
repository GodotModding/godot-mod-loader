class_name ModLoaderDeprecated
extends Object
##
## API methods for deprecating funcs. Can be used by mods with public APIs.


const LOG_NAME := "ModLoader:Deprecated"


## Marks a method that has changed its name or class.[br]
## [br]
## [b]Parameters:[/b][br]
## - [code]old_method[/code] ([String]): The name of the deprecated method.[br]
## - [code]new_method[/code] ([String]): The name of the new method to use.[br]
## - [code]since_version[/code] ([String]): The version number from which the method has been deprecated.[br]
## - [code]show_removal_note[/code] ([bool]): (optional) If true, includes a note about future removal of the old method. Default is true.[br]
## [br]
## [b]Returns:[/b][br]
## - [code]void[/code]
static func deprecated_changed(old_method: String, new_method: String, since_version: String, show_removal_note: bool = true) -> void:
	_deprecated_log(str(
		"DEPRECATED: ",
		"The method \"%s\" has been deprecated since version %s. " % [old_method, since_version],
		"Please use \"%s\" instead. " % new_method,
		"The old method will be removed with the next major update, and will break your code if not changed. " if show_removal_note else ""
	))


## Marks a method that has been entirely removed, with no replacement.[br]
## Note: This should rarely be needed but is included for completeness.[br]
## [br]
## [b]Parameters:[/b][br]
## - [code]old_method[/code] ([String]): The name of the removed method.[br]
## - [code]since_version[/code] ([String]): The version number from which the method has been deprecated.[br]
## - [code]show_removal_note[/code] ([bool]): (optional) If true, includes a note about future removal of the old method. Default is true.[br]
## [br]
## [b]Returns:[/b][br]
## - [code]void[/code]
static func deprecated_removed(old_method: String, since_version: String, show_removal_note: bool = true) -> void:
	_deprecated_log(str(
		"DEPRECATED: ",
		"The method \"%s\" has been deprecated since version %s, and is no longer available. " % [old_method, since_version],
		"There is currently no replacement method. ",
		"The method will be removed with the next major update, and will break your code if not changed. " if show_removal_note else ""
	))


## Marks a method with a freeform deprecation message.[br]
## [br]
## [b]Parameters:[/b][br]
## - [code]msg[/code] ([String]): The deprecation message.[br]
## - [code]since_version[/code] ([String]): (optional) The version number from which the deprecation applies.[br]
## [br]
## [b]Returns:[/b][br]
## - [code]void[/code]
static func deprecated_message(msg: String, since_version: String = "") -> void:
	var since_text := " (since version %s)" % since_version if since_version else ""
	_deprecated_log(str("DEPRECATED: ", msg, since_text))


## Internal function for logging deprecation messages with support to trigger warnings instead of fatal errors.[br]
## [br]
## [b]Parameters:[/b][br]
## - [code]msg[/code] ([String]): The deprecation message.[br]
## [br]
## [b]Returns:[/b][br]
## - [code]void[/code]
static func _deprecated_log(msg: String) -> void:
	if ModLoaderStore and ModLoaderStore.ml_options.ignore_deprecated_errors or OS.has_feature("standalone"):
		ModLoaderLog.warning(msg, LOG_NAME)
	else:
		ModLoaderLog.fatal(msg, LOG_NAME)
