extends GutTest


var test_is_mod_id_valid_params = [
	["abc-abc", true],
	["abcdefg-abcdefg", true],
	["abc-abcdefg", true],
	["ABC-AB_CDE", true],
	["123-123", true],

	["abc-abc-abc", false],
	["abcdef-", false],
	["-abcdef", false],
	["a-bcdef", false],
	["abcdef", false],
	["a", false],
	["abc-%ab", false],
]

# Test with distinct mod ids in arrays
# Test with overlapping mod ids in arrays
# Test with no mod ids in one array
# Test with no mod ids in both arrays
var test_validate_distinct_mod_ids_in_arrays_params = [
	[["mod1-mod1", "mod2-mod2", "mod3-mod3"], ["mod4-mod4", "mod5-mod5", "mod6-mod6"], true],
	[["mod1-mod1", "mod2-mod2", "mod3-mod3"], ["mod4-mod4", "mod5-mod5", "mod6-mod6", "mod2-mod2"], false],
	[[], ["mod4-mod4", "mod5-mod5", "mod6-mod6"], true],
	[["mod1-mod1", "mod2-mod2", "mod3-mod3"], [], true],
	[[], [], true],
]

# Test with a valid mod id array
# Test with an invalid mod id array
var test_is_mod_id_array_valid_params = [
	[["mod1-mod1", "mod2-mod2", "mod3-mod3"], true],
	[["mod1-mod1", "mod2-mod2", "invalid-mod21###"], false],
]


func test_is_mod_id_valid(params = use_parameters(test_is_mod_id_valid_params)) -> void:
	# prepare
	var mod_id = params[0]
	var expected_result = params[1]

	# test
	var result = ModManifest.is_mod_id_valid(mod_id, mod_id, "", true)

	# validate
	assert_true(
		result == expected_result,
		"Expected %s but was %s instead for mod_id \"%s\"" % [expected_result, result, mod_id]
	)


func test_validate_distinct_mod_ids_in_arrays(params = use_parameters(test_validate_distinct_mod_ids_in_arrays_params)) -> void:
	# prepare
	var mod_id = "test-mod"
	var array_one = params[0]
	var array_two = params[1]
	var array_description = ["array_one", "array_two"]
	var additional_info = "additional info"
	var expected_result = params[2]

	# test
	var result = ModManifest.validate_distinct_mod_ids_in_arrays(mod_id, array_one, array_two, array_description, additional_info, true)

	# validate
	assert_true(
		result == expected_result,
		"Expected %s but was %s instead for this arrays \"%s\" - \"%s\"" % [expected_result, result, array_one, array_two]
	)


func test_is_mod_id_array_valid(params = use_parameters(test_is_mod_id_array_valid_params)) -> void:
	# prepare
	var mod_id = "test-mod"
	var mod_id_array = params[0]
	var description = "array_description"
	var expected_result = params[1]

	# test
	var result = ModManifest.is_mod_id_array_valid(mod_id, mod_id_array, description, true)

	# validate
	assert_true(
		result == expected_result,
		"Expected %s but was %s instead for this array \"%s\"" % [expected_result, result, mod_id_array]
	)
