extends GutTest


var test_get_closing_paren_index_params = [
	["(", 0, -1],
	["func test(", 9, -1],
	["()", 0, 1],
	["func test()", 9, 10],
	["())", 0, 1],
	["func test())", 9, 10],
	["(()", 0, -1],
	["func test(()", 9, -1],
	["(())", 0, 3],
	["func test(())", 9, 12],
	["(((((()))(()))(())))", 0, 19],
	["func test(((((()))(()))(())))", 9, 28],
]


func test_get_closing_paren_index(params: Array = use_parameters(test_get_closing_paren_index_params)) -> void:
	# prepare
	var string: String = params[0]
	var opening_paren_index: int = params[1]

	var expected_result: int = params[-1]

	# test
	var result := _ModLoaderModHookPreProcessor.get_closing_paren_index(opening_paren_index, string)

	# validate
	assert_eq(
		result, expected_result,
		"Expected %s but was %s instead for string \"%s\"" % [expected_result, result, string]
	)


var test_match_func_with_whitespace_params = [
	["abc", FUNCTIONS_SAMPLE1, 0, ["func abc("]],
	["test", FUNCTIONS_SAMPLE1, 0, ["func test("]],
	["_ready", FUNCTIONS_SAMPLE2, 0, ["func _ready("]],
	["_on_hit_detector_body_entered", FUNCTIONS_SAMPLE2, 0, ["func _on_hit_detector_body_entered("]],
]

const FUNCTIONS_SAMPLE1 := """\
func abc():
	pass

func test():
	print('hello'))

func end():
	pass

"""

const FUNCTIONS_SAMPLE2 := """\
extends Portal

@export var label_level_name_override := "New Game"


func _ready() -> void:
	super()
	label_level_name.text = label_level_name_override


func _on_hit_detector_body_entered(body: Node3D) -> void:
	super(body)
	Global.reset_game()
"""


# We can't (easily) test for start and end indices due to different line endings between Windows and Linux.
func test_match_func_with_whitespace(params: Array = use_parameters(test_match_func_with_whitespace_params)) -> void:
	# prepare
	var method_name: String = params[0]
	var text: String = params[1]
	var offset: int  = params[2]

	var expected_string: String = params.back()[0]

	# test
	var result := _ModLoaderModHookPreProcessor.match_func_with_whitespace(method_name, text, offset)

	gut.p("Matched: \"%s\"" % result.get_string(), 1)

	# validate
	assert_eq(
		result.get_string(), expected_string,
		"expected %s, got %s" % [expected_string, result.get_string()]
	)


func test_process_script() -> void:
	var hook_pre_processor := _ModLoaderModHookPreProcessor.new()
	hook_pre_processor.process_begin()

	var result_a := hook_pre_processor.process_script("res://test_mod_hook_preprocessor/test_script_A.gd")
	# Using source_code.trim_prefix("#") to prevent hiding global class error.
	var result_a_expected: String = load("res://test_mod_hook_preprocessor/test_script_A_processed.gd").source_code.trim_prefix("#")
	var result_b := hook_pre_processor.process_script("res://test_mod_hook_preprocessor/test_script_B.gd")
	var result_b_expected: String = load("res://test_mod_hook_preprocessor/test_script_B_processed.gd").source_code.trim_prefix("#")
	var result_c := hook_pre_processor.process_script("res://test_mod_hook_preprocessor/test_script_C.gd", true)
	var result_c_expected: String = load("res://test_mod_hook_preprocessor/test_script_C_processed.gd").source_code.trim_prefix("#")
	# Same as C - only with spaces instead of tabs
	var result_d := hook_pre_processor.process_script("res://test_mod_hook_preprocessor/test_script_D.gd", true)
	var result_d_expected: String = load("res://test_mod_hook_preprocessor/test_script_D_processed.gd").source_code.trim_prefix("#")

	assert_eq(result_a, result_a_expected)
	assert_eq(result_b, result_b_expected)
	assert_eq(result_c, result_c_expected)
	assert_eq(result_d, result_d_expected)


func test_process_script_speed() -> void:
	var hook_pre_processor := _ModLoaderModHookPreProcessor.new()
	hook_pre_processor.process_begin()

	var start_tick := Time.get_ticks_msec()

	var result = hook_pre_processor.process_script("res://test_mod_hook_preprocessor/test_script_speed.gd")

	var end_tick := Time.get_ticks_msec()

	print("Hook Processing took %s msec." % str(end_tick - start_tick))

	assert_true((end_tick - start_tick) < 1000)
