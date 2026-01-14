class_name Player3D extends CharacterBody3D

@export var speed := 3.0
@export var accel := 25.0

@export var max_health := 100.0:
	set(value):
		healthbar.max_value = value
		max_health = value
	get():
		return max_health
var health := max_health:
	set(value):
		if iframes_end > Time.get_ticks_msec(): return
		if health != 0 and value < health:
			sprites.modulate = Color.RED
			var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			tween.tween_property(sprites, "modulate", Color.WHITE, 0.15)
		health = clampf(value, 0.0, max_health)
		healthbar.value = health
	get():
		return health
@export var healthbar: HealthBar

@onready var time_manager: TimeManager = %"time manager"

@onready var sprites: AnimatedSprite3D = $AnimatedSprite3D
var anim_frame: int:
	get(): return self.sprites.frame
	set(value): self.sprites.frame = value
var anim_anim: StringName:
	get(): return self.sprites.animation
	set(value): self.sprites.animation = value

@abstract class Weapon extends Node3D:
	var active := false

var owned_weapons: Array[Weapon] = []
var active_weapon: Weapon = null

var iframes_end := 0
const iframes_length := 500

func _ready() -> void:
	self.owned_weapons.append_array($weapon_attachment.get_children().filter(func (child): return child is Weapon))
	if self.owned_weapons: 
		self.active_weapon = self.owned_weapons[0]
		self.active_weapon.active = true
	time_manager.register(self, 
		["position", "health", "anim_frame", "anim_anim"],
		[TYPE_VECTOR3, TYPE_FLOAT, TYPE_INT, TYPE_STRING_NAME], 
		["", "", "", ""], 
		[true, true, false, false],
		false, true,
	)

func after_reset() -> void:
	iframes_end = Time.get_ticks_msec() + iframes_length

func set_anim(dir: Vector2):
	const down_right := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	const down_left := Vector2(cos(deg_to_rad(135.0)), sin(deg_to_rad(135.0)))
	const up_right := Vector2(cos(deg_to_rad(-45.0)), sin(deg_to_rad(-45.0)))
	const up_left := Vector2(cos(deg_to_rad(-135.0)), sin(deg_to_rad(-135.0)))
	const angle_threshold := cos(deg_to_rad(45.0))
	if dir.is_zero_approx():
		self.sprites.stop()
		return
	match dir:
		Vector2.UP:
			if self.sprites.animation != &"runningRB" and self.sprites.animation != &"runningLB":
				self.sprites.play(&"runningRB")
			else: self.sprites.play()
		Vector2.DOWN:
			if self.sprites.animation != &"runningRF" and self.sprites.animation != &"runningLF":
				self.sprites.play(&"runningRF")
			else: self.sprites.play()
		Vector2.LEFT:
			if self.sprites.animation != &"runningLF" and self.sprites.animation != &"runningLB":
				self.sprites.play(&"runningLF")
			else: self.sprites.play()
		Vector2.RIGHT:
			if self.sprites.animation != &"runningRF" and self.sprites.animation != &"runningRB":
				self.sprites.play(&"runningRF")
			else: self.sprites.play()
		_:
			var normalized := dir.normalized()
			if normalized.dot(down_right) >= angle_threshold:
				self.sprites.play(&"runningRF")
			elif normalized.dot(down_left) >= angle_threshold:
				self.sprites.play(&"runningLF")
			elif normalized.dot(up_right) >= angle_threshold:
				self.sprites.play(&"runningRB")
			elif normalized.dot(up_left) >= angle_threshold:
				self.sprites.play(&"runningLB")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if self.iframes_end > now:
		var left := self.iframes_end - now
		self.visible = left % 200 >= 100
	elif self.iframes_end != 0:
		self.iframes_end = 0
		self.visible = true

func _physics_process(delta: float) -> void:
	var is_alive := health > 0
	if time_manager.allow_time():
		var input_dir := Input.get_vector("left", "right", "up", "down") if is_alive else Vector2()
		
		set_anim(input_dir)
		
		var input_rotated := input_dir.rotated(-PI/4)
		
		var input_dir_3 := Vector3(input_rotated.x, 0, input_rotated.y)
		
		var delta_velocity := (self.get_gravity() + input_dir_3 * accel) * delta
		
		self.velocity += delta_velocity * 0.5
		self.velocity *= 0.85 if input_dir.is_zero_approx() else 0.95
		#if self.velocity.length_squared() >= speed * speed: self.velocity = input_dir * speed
		var current_speed_squared := self.velocity.length_squared()
		if current_speed_squared >= speed * speed: self.velocity *= speed / sqrt(current_speed_squared)
		
		# code taken and modified from the godot c++ source for CharacterBody2D::move_and_slide()
		var motion := self.velocity * delta
		for _iter in 4:
			var collision := move_and_collide(motion)
			if collision == null:
				break
			if collision.get_remainder().is_zero_approx():
				motion = Vector3()
				break
			if collision.get_angle(0, -self.velocity.normalized()) < self.wall_min_slide_angle:
				motion = Vector3()
			else:
				motion = collision.get_remainder().slide(collision.get_normal())
			if motion.dot(self.velocity) <= 0.0:
				motion = Vector3()
			if motion.is_zero_approx():
				break

		self.velocity += delta_velocity * 0.5
	else:
		self.velocity = Vector3()
		
