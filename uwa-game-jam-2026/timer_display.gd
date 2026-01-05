class_name TimerDisplay extends Node2D

var value := 30.0
var max_value: float = 30
@export var width := 128.0

var colour_threshold_1 := max_value / 2.0
var colour_threshold_2 := max_value / 4.0

@export var font: Font
@export var colour1: Color
@export var colour2: Color
@export var colour3: Color

const font_size := 16
const padding_top := 4.0
const padding_middle := 4.0
const bar_height := 4.0

func set_max_value(val: float) -> void:
	max_value = val
	colour_threshold_1 = max_value / 2.0
	colour_threshold_2 = max_value / 4.0
	
func _draw() -> void:
	var viewport := get_viewport_rect()
	var center := viewport.size.x / 2.0
	self.draw_string(font, Vector2(center - width/2.0, font_size + padding_top), "%.2fs" % self.value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size)
	var colour := (colour1 if value > colour_threshold_1 else 
			colour1.lerp(colour2, 1 - (value - colour_threshold_2) / (colour_threshold_1 - colour_threshold_2))
			if value > colour_threshold_2 else	colour2.lerp(colour3, 1 - value / colour_threshold_2)
		)
	self.draw_rect(Rect2(center - width / 2.0, font_size + padding_top + padding_middle, value * width / max_value, bar_height), colour)
