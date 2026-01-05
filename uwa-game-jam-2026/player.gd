extends Node2D

@export var speed := 250.0

@onready var time_manager: TimeManager = %"time manager"

func _ready() -> void:
	time_manager.register(self, ["position"], [Variant.Type.TYPE_VECTOR2], [""], [true])

func _process(delta: float) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		var input_dir := Input.get_vector("left", "right", "up", "down")
		# temporary
		self.position += input_dir * speed * delta
