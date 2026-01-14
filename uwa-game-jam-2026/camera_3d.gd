extends Camera3D

@onready var player: Player3D = $"../player"
@onready var offset := self.position


func _process(delta: float) -> void:
	var target := player.position + self.offset
	self.position = self.position.lerp(target, 1.0 - pow(0.01, delta))
