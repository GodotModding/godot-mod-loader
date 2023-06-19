extends Resource
class_name ModUserProfile


# This Class is used to represent a User Profile for the ModLoader.

var name := ""
var mod_list := {}


func _init(_name := "", _mod_list := {}) -> void:
	name = _name
	mod_list = _mod_list
