extends GutTest


func load_manifest_test_mod_1() -> ModManifest:
	var mod_path := "res://mods-unpacked/test-mod1/"
	var manifest_data: Dictionary = _ModLoaderFile.load_manifest_file(mod_path)

	return ModManifest.new(manifest_data, mod_path)


func test_customize_script() -> void:
	ModLoaderStore._update_ml_options_from_options_resource("res://test_options/customize_script/options_custom_validation.tres")
	var manifest := load_manifest_test_mod_1()

	assert_eq(
		"".join(manifest.validation_messages_warning),
		"! ☞ﾟヮﾟ)☞ CUSTOM VALIDATION HERE ☜ﾟヮﾟ☜) !"
	)


func test_customize_script_no_callable() -> void:
	# Clear saved error logs before testing to prevent false positives.
	ModLoaderLog.logged_messages.by_type.error.clear()

	ModLoaderStore._update_ml_options_from_options_resource("res://test_options/customize_script_no_callable_set/options_custom_validation_no_callable_set.tres")
	var manifest := load_manifest_test_mod_1()

	var logs := ModLoaderLog.get_by_type_as_string("error")

	assert_string_contains("".join(logs), "No custom game version validation callable detected. Please provide a valid validation callable.")


func test_game_verion_validation_disabled() ->  void:
	ModLoaderStore._update_ml_options_from_options_resource("res://test_options/game_version_validation_disabled/options_game_version_validation_disabled.tres")
	var manifest := load_manifest_test_mod_1()

	assert_true(manifest.validation_messages_error.size() == 0)


func test_game_verion_validation_default() ->  void:
	ModLoaderStore._update_ml_options_from_options_resource("res://test_options/game_version_validation_default/options_game_version_validation_default.tres")
	var manifest := load_manifest_test_mod_1()

	assert_eq(
		"".join(manifest.validation_messages_error).replace("\r", "").replace("\n", "").replace("\t", ""),
		"The mod \"test-mod1\" is incompatible with the current game version.(current game version: 1000.0.0, mod compatible with game versions: [\"0.0.1\"])"
	)
