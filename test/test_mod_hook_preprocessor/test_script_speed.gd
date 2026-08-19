class_name ModHookPreprocessorTestScriptSpeed
extends Node

var six: set = actual_setter
#var six: set = set_exclude_me
var seven: set= actual_setter, get = actually_get_something
var eight: get = actually_get_something, set= actual_setter
var nine: int: set= actual_setter, get = actually_get_something
var thirteen: int: set= actual_setter ,get = actually_get_something
var ten: Array[String]: get = actually_get_something, set= actual_setter
var eleven: = 4 #set= set_exclude_me, get = get_exclude_me
var twelve: set= actual_setter#, get = get_exclude_me
var four10: get = actually_get_something, set= actual_setter
var _5teen: get = actually_get_something, set= actual_setter
var _16: get = actually_get_something, set= actual_setter
var _seven_teen: get = actually_get_something, set= actual_setter
var eighteen: get = actually_get_something, \
set= actual_setter

@export var one : Vector2 = Vector2.ZERO :
	set(value):
		one = value
		print("")
		pass
		get_groups()
	get:
		return one

var two: int = 0:
	set(v): two = v

var three: int = 0:
	get: return three + 5

var four: int = 0:
	get: return three + 6

var five:
	get:
		set_something()
		return five *2
	set (value):
		one = value
		print("")
		pass
		get_groups()


func _ready() -> void:
	pass


func method(
	one, #Some comment
	two, 	three:  int, # More comments
		four
):
	pass


func super_something():
	pass


func super_something_else():
	print("oy")


func sup_func_two(): pass


func sup_func():
	pass


#func other_test_func(some_param: Cool):
	#pass # test if comments match
func other_test_func():
	pass


func hello_hello() -> void:
	pass


func hellohello(hello: String) -> void: # Hello? hello! hello()
	pass


func hello_hello_2 # Hellow
(testing: String)\
 -> String:
	return ""


func hello() -> void:
	pass


func hello_again() -> void:
	pass


#func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
# 	func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
func more_comment_testing() -> void:
	pass


static func static_super():
	pass


func this_is_so_cursed
():
	pass


func this_too\
():
	pass


# func please_stop()
#func please_stop()
#      	func please_stop()
	 #      	func please_stop()
func please_stop\
#func please_stop(some_param: CoolClass)
# func please_stop(some_param: CoolClass) wow (
# wow ()
#( wow
		 \
	 ():
	pass


func why_would_you(put: int, \
	backslashes := "\\", in_here := "?!\n"
	):
	pass


class SomeTestingSubclass:
	# check that we are not getting inner funcs with the same name
	func get_something():
		return "something"

	func set_something():
		pass


func param_super(one: int, two: String) -> int:
	return one


func other_param_super(one: int, two: String) -> int:
	return one


func get_something():
	return "something"


func set_something():
	pass


func actually_get_something():
	pass


func actual_setter(val):
	six = val


func set_exclude_me():
	pass


func get_exclude_me():
	pass


func definitely_a_coroutine(args := []):
	await tree_entered


func definitely_a_coroutine2(args := []):
	var callback := func():
		print("test")
	return await callback.callv(args)


func definitely_a_coroutine3(args := []):
	var callback := func():
		print("test")
	return await callback.callv([self] + args)


func definitely_a_coroutine4(args := []):
	await get_tree().create_timer(1).timeout


func absolutely_not_a_coroutine(args := []):
	get_something() # await is a keyword
	pass


func definitely_a_coroutine5(args := []):
	print("# hello", await get_something())


func definitely_a_coroutine6(args := []):
	print(""" test
	# hello""", await get_something())


func absolutely_not_a_coroutine2(args := []):
	print(""" test
	# hello""", get_something()) # don't await


func definitely_a_coroutine7(args := []):
	print("# \'hello", await get_something())


func method2(
	one, #Some comment
	two, 	three:  int, # More comments
		four
):
	pass


func super_something2():
	pass


func super_something_else2():
	print("oy")


func sup_func_two2(): pass


func sup_func2():
	pass


#func other_test_func(some_param: Cool):
	#pass # test if comments match
func other_test_func2():
	pass


func hello_hello2() -> void:
	pass


func hellohello2(hello: String) -> void: # Hello? hello! hello()
	pass


func hello_hello_22 # Hellow
(testing: String)\
 -> String:
	return ""


func hello2() -> void:
	pass


func hello_again2() -> void:
	pass


#func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
# 	func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
func more_comment_testing2() -> void:
	pass


static func static_super2():
	pass


func this_is_so_cursed2
():
	pass


func this_too2\
():
	pass


# func please_stop()
#func please_stop()
#      	func please_stop()
	 #      	func please_stop()
func please_stop2\
#func please_stop(some_param: CoolClass)
# func please_stop(some_param: CoolClass) wow (
# wow ()
#( wow
		 \
	 ():
	pass


func why_would_you2(put: int, \
	backslashes := "\\", in_here := "?!\n"
	):
	pass


class SomeTestingSubclass2:
	# check that we are not getting inner funcs with the same name
	func get_something():
		return "something"

	func set_something():
		pass


func param_super2(one: int, two: String) -> int:
	return one


func other_param_super2(one: int, two: String) -> int:
	return one


func get_something2():
	return "something"


func set_something2():
	pass


func actually_get_something2():
	pass


func actual_setter2(val):
	six = val


func set_exclude_me2():
	pass


func get_exclude_me2():
	pass


func definitely_a_coroutine23(args := []):
	await tree_entered


func definitely_a_coroutine22(args := []):
	var callback := func():
		print("test")
	return await callback.callv(args)


func definitely_a_coroutine32(args := []):
	var callback := func():
		print("test")
	return await callback.callv([self] + args)


func definitely_a_coroutine42(args := []):
	await get_tree().create_timer(1).timeout


func absolutely_not_a_coroutine22(args := []):
	get_something() # await is a keyword
	pass


func definitely_a_coroutine52(args := []):
	print("# hello", await get_something())


func definitely_a_coroutine62(args := []):
	print(""" test
	# hello""", await get_something())


func absolutely_not_a_coroutine222(args := []):
	print(""" test
	# hello""", get_something()) # don't await


func definitely_a_coroutine72(args := []):
	print("# \'hello", await get_something())


func method5(
	one, #Some comment
	two, 	three:  int, # More comments
		four
):
	pass


func super_something5():
	pass


func super_something_else5():
	print("oy")


func sup_func_two5(): pass


func sup_func5():
	pass


#func other_test_func(some_param: Cool):
	#pass # test if comments match
func other_test_func5():
	pass


func hello_hello5() -> void:
	pass


func hellohello5(hello: String) -> void: # Hello? hello! hello()
	pass


func hello_hello_25 # Hellow
(testing: String)\
 -> String:
	return ""


func hello5() -> void:
	pass


func hello_again5() -> void:
	pass


#func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
# 	func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
func more_comment_testing5() -> void:
	pass


static func static_super5():
	pass


func this_is_so_cursed5
():
	pass


func this_too5\
():
	pass


# func please_stop()
#func please_stop()
#      	func please_stop()
	 #      	func please_stop()
func please_stop5\
#func please_stop(some_param: CoolClass)
# func please_stop(some_param: CoolClass) wow (
# wow ()
#( wow
		 \
	 ():
	pass


func why_would_you5(put: int, \
	backslashes := "\\", in_here := "?!\n"
	):
	pass


class SomeTestingSubclass5:
	# check that we are not getting inner funcs with the same name
	func get_something():
		return "something"

	func set_something():
		pass


func param_super5(one: int, two: String) -> int:
	return one


func other_param_super5(one: int, two: String) -> int:
	return one


func get_something5():
	return "something"


func set_something5():
	pass


func actually_get_something5():
	pass


func actual_setter5(val):
	six = val


func set_exclude_me5():
	pass


func get_exclude_me5():
	pass


func definitely_a_coroutine55(args := []):
	await tree_entered


func definitely_a_coroutine25(args := []):
	var callback := func():
		print("test")
	return await callback.callv(args)


func definitely_a_coroutine35(args := []):
	var callback := func():
		print("test")
	return await callback.callv([self] + args)


func definitely_a_coroutine45(args := []):
	await get_tree().create_timer(1).timeout


func absolutely_not_a_coroutine5(args := []):
	get_something() # await is a keyword
	pass


func definitely_a_coroutine54(args := []):
	print("# hello", await get_something())


func definitely_a_coroutine65(args := []):
	print(""" test
	# hello""", await get_something())


func absolutely_not_a_coroutine25(args := []):
	print(""" test
	# hello""", get_something()) # don't await


func definitely_a_coroutine75(args := []):
	print("# \'hello", await get_something())


func method25(
	one, #Some comment
	two, 	three:  int, # More comments
		four
):
	pass


func super_something25():
	pass


func super_something_else25():
	print("oy")


func sup_func_two25(): pass


func sup_func25():
	pass


#func other_test_func(some_param: Cool):
	#pass # test if comments match
func other_test_func25():
	pass


func hello_hello25() -> void:
	pass


func hellohello25(hello: String) -> void: # Hello? hello! hello()
	pass


func hello_hello_225 # Hellow
(testing: String)\
 -> String:
	return ""


func hello25() -> void:
	pass


func hello_again25() -> void:
	pass


#func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
# 	func more_comment_testing(some_param: Cool) -> void:
	#pass # test if comments match
func more_comment_testing25() -> void:
	pass


static func static_super25():
	pass


func this_is_so_cursed25
():
	pass


func this_too25\
():
	pass


# func please_stop()
#func please_stop()
#      	func please_stop()
	 #      	func please_stop()
func please_stop25\
#func please_stop(some_param: CoolClass)
# func please_stop(some_param: CoolClass) wow (
# wow ()
#( wow
		 \
	 ():
	pass


func why_would_you25(put: int, \
	backslashes := "\\", in_here := "?!\n"
	):
	pass


class SomeTestingSubclass25:
	# check that we are not getting inner funcs with the same name
	func get_something():
		return "something"

	func set_something():
		pass


func param_super25(one: int, two: String) -> int:
	return one


func other_param_super25(one: int, two: String) -> int:
	return one


func get_something25():
	return "something"


func set_something25():
	pass


func actually_get_something25():
	pass


func actual_setter25(val):
	six = val


func set_exclude_me25():
	pass


func get_exclude_me25():
	pass


func definitely_a_coroutine235(args := []):
	await tree_entered


func definitely_a_coroutine225(args := []):
	var callback := func():
		print("test")
	return await callback.callv(args)


func definitely_a_coroutine325(args := []):
	var callback := func():
		print("test")
	return await callback.callv([self] + args)


func definitely_a_coroutine425(args := []):
	await get_tree().create_timer(1).timeout


func absolutely_not_a_coroutine225(args := []):
	get_something() # await is a keyword
	pass


func definitely_a_coroutine525(args := []):
	print("# hello", await get_something())


func definitely_a_coroutine625(args := []):
	print(""" test
	# hello""", await get_something())


func absolutely_not_a_coroutine2225(args := []):
	print(""" test
	# hello""", get_something()) # don't await


func definitely_a_coroutine725(args := []):
	print("# \'hello", await get_something())
