extends Control


@export var wait_time := 1.0
@export var count_down_from := 3

@onready var timer: Label = %Timer


func _ready() -> void:
	for i in count_down_from:
		timer.text = str(count_down_from - i)
		await get_tree().create_timer(wait_time).timeout

	OS.set_restart_on_exit(true)
	get_tree().quit()
