extends GutTest


func test_customize_script() -> void:
	ModLoaderStore._update_ml_options_from_options_resource("res://test_customize_script/options_custom_validation.tres")
	# Load manifest file
	var mod_path := "res://mods-unpacked/test-mod1/"
	var manifest_data: Dictionary = _ModLoaderFile.load_manifest_file(mod_path)
	var manifest := ModManifest.new(manifest_data, mod_path)

	assert_eq(
		"".join(manifest.validation_messages_warning),
		"! ☞ﾟヮﾟ)☞ CUSTOM VALIDATION HERE ☜ﾟヮﾟ☜) !"
	)
