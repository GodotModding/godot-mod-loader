#class_name ModHookPreprocessorTestScriptD
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


func vanilla_2078567355__ready() -> void:
    pass


func vanilla_2078567355_method(
    one, #Some comment
    two, 	three:  int, # More comments
        four
):
    pass


func vanilla_2078567355_super_something():
    pass


func vanilla_2078567355_super_something_else():
    print("oy")


func vanilla_2078567355_sup_func_two(): pass


func vanilla_2078567355_sup_func():
    pass


#func other_test_func(some_param: Cool):
    #pass # test if comments match
func vanilla_2078567355_other_test_func():
    pass


func vanilla_2078567355_hello_hello() -> void:
    pass


func vanilla_2078567355_hellohello(hello: String) -> void: # Hello? hello! hello()
    pass


func vanilla_2078567355_hello_hello_2(testing: String)\
 -> String:
    return ""


func vanilla_2078567355_hello() -> void:
    pass


func vanilla_2078567355_hello_again() -> void:
    pass


#func more_comment_testing(some_param: Cool) -> void:
    #pass # test if comments match
# 	func more_comment_testing(some_param: Cool) -> void:
    #pass # test if comments match
func vanilla_2078567355_more_comment_testing() -> void:
    pass


static func vanilla_2078567355_static_super():
    pass


func vanilla_2078567355_this_is_so_cursed():
    pass


func vanilla_2078567355_this_too():
    pass


# func please_stop()
#func please_stop()
#      	func please_stop()
     #      	func please_stop()
func vanilla_2078567355_please_stop():
    pass


func vanilla_2078567355_why_would_you(put: int, \
    backslashes := "\\", in_here := "?!\n"
    ):
    pass


class SomeTestingSubclass:
    # check that we are not getting inner funcs with the same name
    func get_something():
        return "something"

    func set_something():
        pass


func vanilla_2078567355_param_super(one: int, two: String) -> int:
    return one


func vanilla_2078567355_other_param_super(one: int, two: String) -> int:
    return one


func vanilla_2078567355_get_something():
    return "something"


func vanilla_2078567355_set_something():
    pass


func actually_get_something():
    pass


func actual_setter(val):
    six = val


func vanilla_2078567355_set_exclude_me():
    pass


func vanilla_2078567355_get_exclude_me():
    pass


func vanilla_2078567355_definitely_a_coroutine(args := []):
    await tree_entered


func vanilla_2078567355_definitely_a_coroutine2(args := []):
    var callback := func():
        print("test")
    return await callback.callv(args)


func vanilla_2078567355_definitely_a_coroutine3(args := []):
    var callback := func():
        print("test")
    return await callback.callv([self] + args)


func vanilla_2078567355_definitely_a_coroutine4(args := []):
    await get_tree().create_timer(1).timeout


func vanilla_2078567355_absolutely_not_a_coroutine(args := []):
    get_something() # await is a keyword
    pass


func vanilla_2078567355_definitely_a_coroutine5(args := []):
    print("# hello", await get_something())


func vanilla_2078567355_definitely_a_coroutine6(args := []):
    print(""" test
    # hello""", await get_something())


func vanilla_2078567355_absolutely_not_a_coroutine2(args := []):
    print(""" test
    # hello""", get_something()) # don't await


func vanilla_2078567355_definitely_a_coroutine7(args := []):
    print("# \'hello", await get_something())


# ModLoader Hooks - The following code has been automatically added by the Godot Mod Loader.


func _ready():
 if _ModLoaderHooks.any_mod_hooked:
  _ModLoaderHooks.call_hooks(vanilla_2078567355__ready, [], 2398426479)
 else:
  vanilla_2078567355__ready()


func method(one, #Somecomment
two, three: int, #Morecomments
four):
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_method, [one, two, three, four], 2931452028)
 else:
  return vanilla_2078567355_method(one, two, three, four)


func super_something():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_super_something, [], 3528315479)
 else:
  return vanilla_2078567355_super_something()


func super_something_else():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_super_something_else, [], 4154602879)
 else:
  return vanilla_2078567355_super_something_else()


func sup_func_two():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_sup_func_two, [], 1831710071)
 else:
  return vanilla_2078567355_sup_func_two()


func sup_func():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_sup_func, [], 2519279934)
 else:
  return vanilla_2078567355_sup_func()


func other_test_func():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_other_test_func, [], 3091176327)
 else:
  return vanilla_2078567355_other_test_func()


func hello_hello():
 if _ModLoaderHooks.any_mod_hooked:
  _ModLoaderHooks.call_hooks(vanilla_2078567355_hello_hello, [], 452508802)
 else:
  vanilla_2078567355_hello_hello()


func hellohello(hello: String):
 if _ModLoaderHooks.any_mod_hooked:
  _ModLoaderHooks.call_hooks(vanilla_2078567355_hellohello, [hello], 2627295971)
 else:
  vanilla_2078567355_hellohello(hello)


func hello_hello_2(testing: String) -> String:
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_hello_hello_2, [testing], 3155816819)
 else:
  return vanilla_2078567355_hello_hello_2(testing)


func hello():
 if _ModLoaderHooks.any_mod_hooked:
  _ModLoaderHooks.call_hooks(vanilla_2078567355_hello, [], 3727108367)
 else:
  vanilla_2078567355_hello()


func hello_again():
 if _ModLoaderHooks.any_mod_hooked:
  _ModLoaderHooks.call_hooks(vanilla_2078567355_hello_again, [], 444267150)
 else:
  vanilla_2078567355_hello_again()


func more_comment_testing():
 if _ModLoaderHooks.any_mod_hooked:
  _ModLoaderHooks.call_hooks(vanilla_2078567355_more_comment_testing, [], 3973755357)
 else:
  vanilla_2078567355_more_comment_testing()


static func static_super():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_static_super, [], 1925519633)
 else:
  return vanilla_2078567355_static_super()


func this_is_so_cursed():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_this_is_so_cursed, [], 3065284404)
 else:
  return vanilla_2078567355_this_is_so_cursed()


func this_too():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_this_too, [], 2328353604)
 else:
  return vanilla_2078567355_this_too()


func please_stop():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_please_stop, [], 1295645626)
 else:
  return vanilla_2078567355_please_stop()


func why_would_you(put: int, \
backslashes: ="\\", in_here: ="?!\n"):
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_why_would_you, [put, backslashes, in_here], 3877879289)
 else:
  return vanilla_2078567355_why_would_you(put, backslashes, in_here)


func param_super(one: int, two: String) -> int:
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_param_super, [one, two], 816188570)
 else:
  return vanilla_2078567355_param_super(one, two)


func other_param_super(one: int, two: String) -> int:
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_other_param_super, [one, two], 3369296539)
 else:
  return vanilla_2078567355_other_param_super(one, two)


func get_something():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_get_something, [], 2056777800)
 else:
  return vanilla_2078567355_get_something()


func set_something():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_set_something, [], 856449620)
 else:
  return vanilla_2078567355_set_something()


func set_exclude_me():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_set_exclude_me, [], 1454662913)
 else:
  return vanilla_2078567355_set_exclude_me()


func get_exclude_me():
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_get_exclude_me, [], 2410787189)
 else:
  return vanilla_2078567355_get_exclude_me()


func definitely_a_coroutine(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return await _ModLoaderHooks.call_hooks_async(vanilla_2078567355_definitely_a_coroutine, [args], 1863787359)
 else:
  return await vanilla_2078567355_definitely_a_coroutine(args)


func definitely_a_coroutine2(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return await _ModLoaderHooks.call_hooks_async(vanilla_2078567355_definitely_a_coroutine2, [args], 1375440753)
 else:
  return await vanilla_2078567355_definitely_a_coroutine2(args)


func definitely_a_coroutine3(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return await _ModLoaderHooks.call_hooks_async(vanilla_2078567355_definitely_a_coroutine3, [args], 1375440754)
 else:
  return await vanilla_2078567355_definitely_a_coroutine3(args)


func definitely_a_coroutine4(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return await _ModLoaderHooks.call_hooks_async(vanilla_2078567355_definitely_a_coroutine4, [args], 1375440755)
 else:
  return await vanilla_2078567355_definitely_a_coroutine4(args)


func absolutely_not_a_coroutine(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_absolutely_not_a_coroutine, [args], 784241254)
 else:
  return vanilla_2078567355_absolutely_not_a_coroutine(args)


func definitely_a_coroutine5(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return await _ModLoaderHooks.call_hooks_async(vanilla_2078567355_definitely_a_coroutine5, [args], 1375440756)
 else:
  return await vanilla_2078567355_definitely_a_coroutine5(args)


func definitely_a_coroutine6(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return await _ModLoaderHooks.call_hooks_async(vanilla_2078567355_definitely_a_coroutine6, [args], 1375440757)
 else:
  return await vanilla_2078567355_definitely_a_coroutine6(args)


func absolutely_not_a_coroutine2(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return _ModLoaderHooks.call_hooks(vanilla_2078567355_absolutely_not_a_coroutine2, [args], 110157656)
 else:
  return vanilla_2078567355_absolutely_not_a_coroutine2(args)


func definitely_a_coroutine7(args: =[]):
 if _ModLoaderHooks.any_mod_hooked:
  return await _ModLoaderHooks.call_hooks_async(vanilla_2078567355_definitely_a_coroutine7, [args], 1375440758)
 else:
  return await vanilla_2078567355_definitely_a_coroutine7(args)
