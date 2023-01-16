extends SceneTree

# IMPORTANT: use the ModLoaderHelper through this in this script! Otherwise
# script compilation will break on first load since the class is not defined
# just use the normal one with autocomplete and then lowercase it
var modloaderhelper: Node = load("res://addons/mod_loader_tools/mod_loader_helper.gd").new()

var has_interface: bool = do_main_interface_files_exist()
var allow_interrupt := false
var interrupt_attempt := 0
var skip_mod_selection: bool = modloaderhelper.should_skip_mod_selection()


func _init() -> void:
	try_setup_modloader()

	if modloaderhelper.are_mods_enabled():
		allow_interrupt = true
	elif has_interface:
		change_scene_to_mod_selection()
	else:
		get_mod_loader().init_mods()
		change_scene_to_game_main()


func _idle(delta: float) -> bool:
	if not allow_interrupt:
		return false # keep main loop running

	if not has_interface:
		allow_interrupt = false
		get_mod_loader().init_mods()
		change_scene_to_game_main()

	# first Input.is_key_pressed() is always false for some reason
	# so we check at least three times
	if interrupt_attempt > 3: # not interrupted
		allow_interrupt = false
		if skip_mod_selection:
			change_scene_to_game_main()
		else:
			change_scene_to_mod_selection()

	interrupt_attempt += 1
	if Input.is_key_pressed(KEY_ALT): # interrupted
		allow_interrupt = false
		if skip_mod_selection:
			change_scene_to_mod_selection()
		else:
			change_scene_to_game_main()

	return false


func get_mod_loader() -> Node:
	return root.get_node("/root/ModLoader")


func do_main_interface_files_exist() -> bool:
	var dir := Directory.new()
	return (
		dir.dir_exists(modloaderhelper.file_paths.INTERFACE_DIR) and
		dir.file_exists(modloaderhelper.file_paths.MOD_SELECTION_SCENE)
	)


func change_scene_to_mod_selection() -> void:
	set_screen_stretch(
		SceneTree.STRETCH_MODE_DISABLED,
		SceneTree.STRETCH_ASPECT_IGNORE,
		Vector2(1920, 1080)
	)
	change_scene(ProjectSettings.get_setting(modloaderhelper.settings.MOD_SELECTION_SCENE))


func change_scene_to_game_main() -> void:
	set_screen_stretch(
		get("STRETCH_MODE_%s" % ProjectSettings.get_setting("display/window/stretch/mode").to_upper()),
		get("STRETCH_ASPECT_%s" % ProjectSettings.get_setting("display/window/stretch/aspect").to_upper()),
		Vector2(
			ProjectSettings.get_setting("display/window/size/width"),
			ProjectSettings.get_setting("display/window/size/height")
		)
	)
	change_scene(ProjectSettings.get_setting(modloaderhelper.settings.GAME_MAIN_SCENE))


func try_setup_modloader() -> void:
	# no more setup needed if the game is already modded
	if modloaderhelper.are_mods_enabled():
		print("Mods are enabled.")
		return

	# game needs to be restarted before mods can be loaded
	# if initialized and not mods enabled yet,
	# prompt the user to quit and restart in the selector scene
	if modloaderhelper.is_loader_initialized() and not modloaderhelper.are_mods_enabled():
		ProjectSettings.set_setting(modloaderhelper.settings.MODS_ENABLED, true)
		ProjectSettings.save_custom(modloaderhelper.get_override_path())
		return

	setup_modloader()


func setup_modloader() -> void:
	print("Setting up ModLoader...")

	# register all new helper classes as global
	var classes: Array = ProjectSettings.get_setting(modloaderhelper.settings.GLOBAL_SCRIPT_CLASSES)
	var class_icons: Dictionary = ProjectSettings.get_setting(modloaderhelper.settings.GLOBAL_SCRIPT_CLASS_ICONS)

	for new_class in modloaderhelper.new_global_classes:
		var class_exists := false
		for old_class in classes:
			if new_class.class == old_class.class:
				class_exists = true
				break
		if not class_exists:
			classes.append(new_class)
			class_icons[new_class.class] = "" # empty icon, does not matter

	ProjectSettings.set_setting(modloaderhelper.settings.GLOBAL_SCRIPT_CLASSES, classes)
	ProjectSettings.set_setting(modloaderhelper.settings.GLOBAL_SCRIPT_CLASS_ICONS, class_icons)

	# rename application to make it clear to the user that they are playing modded
	# godot also creates a new user:// folder for logs (and other things using user:// for saves etc.)
	var original_name: String = ProjectSettings.get_setting(modloaderhelper.settings.APPLICATION_NAME)
	ProjectSettings.set_setting(modloaderhelper.settings.APPLICATION_NAME, original_name + " (Modded)")

	var original_autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.name
		if name.begins_with("autoload/"):
			var value: String = ProjectSettings.get_setting(name)
			original_autoloads[name] = value


	# save the mod selection scene for global access
	ProjectSettings.set_setting(modloaderhelper.settings.MOD_SELECTION_SCENE, modloaderhelper.file_paths.MOD_SELECTION_SCENE)

	# removing and adding autoloads back does not work apparently
	# even autoloads that are removed in the override are loaded
	# result -> the loader autoload is still last :/
	# remove all existing autoloads
	for autoload in original_autoloads.keys():
		ProjectSettings.set_setting(autoload, null)

	# add ModLoader autoload (the * marks the path as autoload)
	ProjectSettings.set_setting(modloaderhelper.settings.MOD_LOADER_AUTOLOAD, "*" + modloaderhelper.file_paths.MOD_LOADER_SCRIPT)
	ProjectSettings.set_setting(modloaderhelper.settings.AUTOLOAD_AVAILABLE, true)

	# add all previous autoloads back again
	for autoload in original_autoloads.keys():
		ProjectSettings.set_setting(autoload, original_autoloads[autoload])

	ProjectSettings.set_setting(modloaderhelper.settings.MODS_ENABLED, false)
	ProjectSettings.save_custom(modloaderhelper.get_override_path())

	print("Done setting up ModLoader.")

