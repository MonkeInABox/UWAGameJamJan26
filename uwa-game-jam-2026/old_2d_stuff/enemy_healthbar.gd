class_name EnemyHealthBar extends Node2D

@export var max_value := 100.0
@onready var value := max_value:
	set(val):
		if value != val:
			queue_redraw()
		value = val
@export var width := 128.0
@export var height := 4.0
@export var colour := Color("d90000")

func _draw() -> void:
	self.draw_rect(Rect2(-width / 2.0, -height / 2.0, value * width / max_value, height), colour)
