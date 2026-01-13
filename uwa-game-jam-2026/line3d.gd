class_name Line3D extends Node2D

var a: Vector3:
	set(value): 
		if a != value: queue_redraw()
		a = value
	get(): return a
var b: Vector3:
	set(value): 
		if b != value: queue_redraw()
		b = value
		queue_redraw()
	get(): return b
	
var color: Color:
	set(value): 
		if color != value: queue_redraw()
		color = value
		queue_redraw()
	get(): return color

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	draw_line(cam.unproject_position(a), cam.unproject_position(b), color)
