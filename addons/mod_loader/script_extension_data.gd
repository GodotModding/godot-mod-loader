class_name ScriptExtensionData
extends Resource


var extension_path:String

var parent_script_path:String

var mod_id:String


func _init(p_extension_path:String, p_parent_script_path:String, p_mod_id:String):
	extension_path = p_extension_path
	parent_script_path = p_parent_script_path
	mod_id = p_mod_id

