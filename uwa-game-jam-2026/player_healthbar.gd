class_name HealthBar extends Node2D

var value := 100.0
var max_value := 100.0
@export var width := 128.0

@export var alert_threshold := 0.2

@export var font: Font
@export var colour := Color.RED
@export var flash_colour := Color.DARK_RED
@export var blink_time := 0.4 * 1000.0

const font_size := 16
const padding_bottom := 4.0
const padding_middle := 4.0
const bar_height := 4.0

var last_blink := Time.get_ticks_msec()
var blink_state := false

func _process(_delta: float) -> void:
	if value <= max_value * alert_threshold:
		var now := Time.get_ticks_msec()
		if last_blink + blink_time < now:
			last_blink = now
			blink_state = not blink_state
			queue_redraw()
	
func _draw() -> void:
	var viewport := get_viewport_rect()
	var center := viewport.size.x / 2.0
	var bottom := viewport.size.y
	self.draw_string(font, Vector2(center - width/2.0, bottom - padding_bottom - padding_middle - bar_height), "%.0f" % self.value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size)
	var bar_colour := flash_colour if value <= max_value * alert_threshold and blink_state else colour
	self.draw_rect(Rect2(center - width / 2.0, bottom - padding_bottom - bar_height, value * width / max_value, bar_height), bar_colour)
