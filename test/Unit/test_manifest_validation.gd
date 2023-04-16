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


func test_validate_distinct_mod_ids_in_arrays():
	var array_one: PoolStringArray = ["mod1-mod1", "mod2-mod2", "mod3-mod3"]
	var array_two: PoolStringArray = ["mod4-mod4", "mod5-mod5", "mod6-mod6"]
	var array_description: PoolStringArray = ["array_1", "array_2"]
	var mod_id = "test-mod"
	var additional_info = "additional info"

	# Test with distinct mod ids in arrays
	var result = ModManifest.validate_distinct_mod_ids_in_arrays(mod_id, array_one, array_two, ["array_one", "array_two"], additional_info, true)
	assert_eq(result, true)

	# Test with overlapping mod ids in arrays
	array_two = ["mod4-mod4", "mod5-mod5", "mod6-mod6", "mod2-mod2"]
	result = ModManifest.validate_distinct_mod_ids_in_arrays(mod_id, array_one, array_two, ["array_one", "array_two"], additional_info, true)
	assert_eq(result, false)

	# Test with no mod ids in one array
	array_two = []
	result = ModManifest.validate_distinct_mod_ids_in_arrays(mod_id, array_one, array_two, ["array_one", "array_two"], additional_info, true)
	assert_eq(result, true)

	# Test with no mod ids in both arrays
	array_one = []
	array_two = []
	result = ModManifest.validate_distinct_mod_ids_in_arrays(mod_id, array_one, array_two, ["array_one", "array_two"], additional_info, true)
	assert_eq(result, true)


func test_is_mod_id_array_valid():
	var mod_id_array = PoolStringArray(["mod1-mod1", "mod2-mod2", "mod3-mod3"])

	# Test with a valid mod id array
	var result = ModManifest.is_mod_id_array_valid("own-mod", mod_id_array, "dependencies", true)
	assert_eq(result, true)

	# Test with an invalid mod id array
	mod_id_array = PoolStringArray(["mod1-mod1", "mod2-mod2", "invalid-mod21###"])
	result = ModManifest.is_mod_id_array_valid("own-mod", mod_id_array, "dependencies", true)
	assert_eq(result, false)
