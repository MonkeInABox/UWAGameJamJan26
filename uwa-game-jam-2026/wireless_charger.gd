extends Area3D

@onready var time_manager: TimeManager = %"time manager"

func _on_area_entered(area: Area3D) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		if area.get_parent() is Player3D:
			time_manager.checkpoint()
	
