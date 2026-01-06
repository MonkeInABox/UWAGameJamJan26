class_name EnemyHealthBar extends Node2D

@export var max_value := 100.0
@onready var value := max_value
@export var width := 128.0
@export var height := 4.0
@export var colour := Color("d90000")

@export var target: Node2D
@export var offset: Vector2

func _init(node: Node2D, offset_amount: Vector2, max_health: float, bar_width: float) -> void:
	self.z_index += 1
	self.target = node
	self.offset = offset_amount
	self.max_value = max_health
	self.value = max_health
	self.width = bar_width

func _process(_delta: float) -> void:
	self.global_position = target.global_position + self.offset

func _draw() -> void:
	self.draw_rect(Rect2(-width / 2.0, -height / 2.0, value * width / max_value, height), colour)
