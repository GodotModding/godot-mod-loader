# This Class provides methods to manage mod state.
# *Note: Intended to be used by game developers.*
class_name ModLoaderModManager
extends RefCounted


const LOG_NAME := "ModLoader:Manager"


# Uninstall a script extension.
#
# Parameters:
# - extension_script_path (String): The path to the extension script to be uninstalled.
#
# Returns: void
static func uninstall_script_extension(extension_script_path: String) -> void:
	# Currently this is the only thing we do, but it is better to expose
	# this function like this for further changes
	_ModLoaderScriptExtension.remove_specific_extension_from_script(extension_script_path)


# Reload all mods.
#
# *Note: This function should be called only when actually necessary
# as it can break the game and require a restart for mods
# that do not fully use the systems put in place by the mod loader,
# so anything that just uses add_node, move_node ecc...
# To not have your mod break on reload please use provided functions
# like ModLoader::save_scene, ModLoader::append_node_in_scene and
# all the functions that will be added in the next versions
# Used to reload already present mods and load new ones*
#
# Returns: void
static func reload_mods() -> void:

	# Currently this is the only thing we do, but it is better to expose
	# this function like this for further changes
	ModLoader._reload_mods()


# Disable all mods.
#
# *Note: This function should be called only when actually necessary
# as it can break the game and require a restart for mods
# that do not fully use the systems put in place by the mod loader,
# so anything that just uses add_node, move_node ecc...
# To not have your mod break on disable please use provided functions
# and implement a _disable function in your mod_main.gd that will
# handle removing all the changes that were not done through the Mod Loader*
#
# Returns: void
static func disable_mods() -> void:

	# Currently this is the only thing we do, but it is better to expose
	# this function like this for further changes
	ModLoader._disable_mods()


# Disable a mod.
#
# *Note: This function should be called only when actually necessary
# as it can break the game and require a restart for mods
# that do not fully use the systems put in place by the mod loader,
# so anything that just uses add_node, move_node ecc...
# To not have your mod break on disable please use provided functions
# and implement a _disable function in your mod_main.gd that will
# handle removing all the changes that were not done through the Mod Loader*
#
# Parameters:
# - mod_data (ModData): The ModData object representing the mod to be disabled.
#
# Returns: void
static func disable_mod(mod_data: ModData) -> void:

	# Currently this is the only thing we do, but it is better to expose
	# this function like this for further changes
	ModLoader._disable_mod(mod_data)
