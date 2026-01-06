extends CharacterBody2D

@export var speed := 250.0
@export var accel := 2500.0

@export var max_health := 100.0:
	set(value):
		healthbar.max_value = value
		max_health = value
	get():
		return max_health
var health := max_health:
	set(value):
		health = clampf(value, 0.0, max_health)
		healthbar.value = health
	get():
		return health
@export var healthbar: HealthBar

@onready var time_manager: TimeManager = %"time manager"

func _ready() -> void:
	time_manager.register(self, 
		["position", "health"],
		[Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_FLOAT], 
		["", ""], 
		[true, true]
	)

func _physics_process(delta: float) -> void:
	var is_alive := health > 0
	if time_manager.state == TimeManager.STATE_NORMAL:
		var input_dir := Input.get_vector("left", "right", "up", "down") if is_alive else Vector2()
		self.velocity += input_dir * accel * delta * 0.5
		self.velocity *= 0.85 if input_dir.is_zero_approx() else 0.95
		#if self.velocity.length_squared() >= speed * speed: self.velocity = input_dir * speed
		var current_speed_squared = self.velocity.length_squared()
		if current_speed_squared >= speed * speed: self.velocity *= speed / sqrt(current_speed_squared)
		
		# code taken and modified from the godot c++ source for CharacterBody2D::move_and_slide()
		var motion := self.velocity * delta
		for _iter in 4:
			var collision := move_and_collide(motion)
			if collision == null:
				break
			if collision.get_remainder().is_zero_approx():
				motion = Vector2()
				break
			if collision.get_angle(-self.velocity.normalized()) < self.wall_min_slide_angle:
				motion = Vector2()
			else:
				motion = collision.get_remainder().slide(collision.get_normal())
				
			if motion.dot(self.velocity) <= 0.0:
				motion = Vector2()
				
			if motion.is_zero_approx():
				break

		self.velocity += input_dir * accel * delta * 0.5
	else:
		self.velocity = Vector2()
		
