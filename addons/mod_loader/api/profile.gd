class_name ModLoaderUserProfile
extends Object


# This Class provides methods for working with user profiles.


# API profile functions
# =============================================================================

static func save_mod_options() -> void:
	pass


static func enable_mod(mod_id: String, profile: String = "Default") -> void:
	pass


static func disable_mod(mod_id: String, profile: String = "Default") -> void:
	pass


static func create(profile: String) -> void:
	pass


func update(profile: String) -> void:
	pass


func delete(profile: String) -> void:
	pass


# Internal profile functions
# =============================================================================

static func _load_mod_options() -> void:
	pass