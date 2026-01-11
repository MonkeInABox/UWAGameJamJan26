extends Sprite3D

var target: Node3D

func _ready() -> void:
	self.target = self.get_parent()
	self.target.remove_child.call_deferred(self)
	self.target.get_parent().add_child.call_deferred(self)

func _process(_delta: float) -> void:
	self.global_position = target.global_position
	#self.global_rotation = 0
	if self.target.health > 0:
		@warning_ignore("integer_division")
		self.frame_coords.y = (Time.get_ticks_msec() / int(100.0 / 8)) % 8
	self.frame_coords.x = posmod(int(target.rotation.y / TAU * 32.0), 16)
