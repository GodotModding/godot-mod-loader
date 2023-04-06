class_name LogEntry
extends Resource

var mod_name: String
var message: String
var type: String
var time: String


func _init(_mod_name: String, _message: String, _type: String, _time: String) -> void:
	mod_name = _mod_name
	message = _message
	type = _type
	time = _time


func get_entry() -> String:
	var prefix := "%s %s: " % [type.to_upper(), mod_name]
	return time + prefix + message


func get_prefix() -> String:
	return "%s %s: " % [type.to_upper(), mod_name]


func get_md5() -> String:
	return get_entry().md5_text()
