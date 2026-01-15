class_name PlasmaBallPool extends Node

var plasma_ball := preload("res://plasma_ball.tscn")
@onready var time_manager: TimeManager = %"time manager"
@onready var available_node := $available

func get_ball() -> PlasmaBall:
	var available := available_node.get_children().filter(func (node): return node is PlasmaBall)
	if available: 
		available[0].alive = true
		return available[0]
	var new: PlasmaBall = plasma_ball.instantiate()
	new.pool = self.available_node
	new.time_manager = time_manager
	self.add_child(new)
	return new
