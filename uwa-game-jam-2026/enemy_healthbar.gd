class_name EnemyHealthbar3D extends Node2D

@export var max_value := 100.0
@onready var value := max_value:
	set(val):
		if value != val:
			queue_redraw()
		value = val
@export var width := 128.0
@export var height := 4.0
@export var colour := Color("d90000")
@onready var target: Node3D = self.get_parent().get_parent()
@onready var offset := self.position

func _process(_delta: float) -> void:
	self.position = self.get_viewport().get_camera_3d().unproject_position(target.global_position) + self.offset
	#print(self.global_position)

func _draw() -> void:
	self.draw_circle(Vector2(), 500, Color.BLUE)
	self.draw_rect(Rect2(-width / 2.0, -height / 2.0, value * width / max_value, height), colour)
