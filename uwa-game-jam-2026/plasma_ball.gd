class_name PlasmaBall extends Node3D

var time_manager: TimeManager
var pool: Node

@export var velocity: Vector3
@export var damage: float
var query := PhysicsShapeQueryParameters3D.new()
var shape = SphereShape3D.new()
var collision_radius := 0.25
var explosion_radius := 0.5
var collide_with_enemies := false
@onready var audio_loop: AudioStreamPlayer3D = $audio_loop
@onready var audio_explosion: AudioStreamPlayer3D = $audio_explosion

var alive := false:
	set(value):
		self.visible = value
		if alive and not value and self.get_parent() != pool:
			self.get_parent().remove_child(self)
			self.pool.add_child(self)
		elif not alive and value and self.get_parent() != pool.get_parent():
			self.pool.remove_child(self)
			self.pool.get_parent().add_child(self)
		alive = value

func _ready() -> void:
	query.shape = shape
	time_manager.register(self,
		["position", "alive", "velocity"],
		[TYPE_VECTOR3, TYPE_BOOL, TYPE_VECTOR3],
		["", "", ""],
		[true, false, false],
	)
	self.alive = true
func _process(_delta: float) -> void:
	if time_manager.allow_time():
		if self.alive != audio_loop.playing: audio_loop.playing = self.alive
	else:
		audio_loop.stop()

func _physics_process(delta: float) -> void:
	if not self.alive or not time_manager.allow_time(): return
	var space := get_world_3d().direct_space_state
	self.position += self.velocity * delta
	query.collision_mask = 0b10001 | (0b00100 if collide_with_enemies else 0)
	query.collide_with_areas = false
	shape.radius = collision_radius
	query.transform.origin = self.global_position
	var collision := space.intersect_shape(query)
	if collision:
		query.collision_mask = 0b01010
		shape.radius = explosion_radius
		query.collide_with_areas = true
		var results := space.intersect_shape(query)
		for result in results:
			var collider: Node3D = result.collider
			if collider.has_method("damage"):
				collider.damage(self.damage)
				continue
			var parent := collider.get_parent()
			if parent.has_method("damage"):
				parent.damage(self.damage)
		audio_explosion.play()
		self.alive = false
