extends Area3D

@onready var time_manager: TimeManager = %"time manager"
@onready var base: AnimatedSprite3D = $base
@onready var fx: AnimatedSprite3D = $fx
@export var player: Player3D
@export var destination: Node3D
@export var text_hint: Label3D
@export var enemies_to_kill: Array[Node3D]

var enabled := false:
	set(value):
		self.base.animation = &"on" if value else &"off"
		self.fx.visible = value
		enabled = value
		text_hint.visible = not value
		
func _ready() -> void:
	enabled = false
	time_manager.register(self, ["enabled"], [TYPE_BOOL], [""], [false])

func _process(_delta: float) -> void:
	if time_manager.allow_time():
		if enemies_to_kill.all(func (enemy): return enemy.health <= 0.0):
			self.enabled = true

func _on_area_entered(area: Area3D) -> void:
	if enabled and area.get_parent() == player:
		time_manager.state = TimeManager.STATE_DISABLED
		player.teleporting = true
		await get_tree().create_timer(1.8).timeout
		player.teleporting = false
		player.global_position = destination.global_position
		
