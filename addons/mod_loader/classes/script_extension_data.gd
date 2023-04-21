class_name ScriptExtensionData
extends Resource

# Stores all Data defining a script extension

# Full path to the extension file
var extension_path: String

# Full path to the vanilla script extended
var parent_script_path: String

# Mod requesting the extension
var mod_id: String


func _init(p_extension_path: String, p_parent_script_path: String, p_mod_id: String):
	extension_path = p_extension_path
	parent_script_path = p_parent_script_path
	mod_id = p_mod_id

