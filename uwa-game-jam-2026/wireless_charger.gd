extends Area3D

@onready var time_manager: TimeManager = %"time manager"

var enabled := true:
	set(value):
		$AnimatedSprite3D.animation = &"glow" if value else &"off"
		enabled = value
		$OmniLight3D.visible = value

func _on_area_entered(area: Area3D) -> void:
	if enabled and time_manager.allow_time():
		if area.get_parent() is Player3D:
			time_manager.checkpoint()
			self.enabled = false

func _on_area_exited(_area: Area3D) -> void:
	pass
