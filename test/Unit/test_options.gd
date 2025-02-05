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
