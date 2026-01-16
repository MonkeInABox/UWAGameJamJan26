class_name BasicEnemy extends CharacterBody3D

@export var player: Player3D
@onready var time_manager: TimeManager = %"time manager"
@export var nav: NavigationAgent3D
var target: Vector3
var last_seen_target: int = -1
var can_see_player := false
var wander_timer := 0
var wander_pos: Vector3
@export var speed := 3.0
@export var accel := 25.0
@export var max_health := 20.0:
	set(value):
		if health == max_health: health = value
		max_health = value
		if healthbar: healthbar.max_value = value
	get():
		return max_health
@onready var health := max_health:
	set(value):
		if health != 0.0 and value < health and sprite:
			sprite.modulate = Color.RED
			var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		health = clampf(value, 0.0, max_health)
		if healthbar: healthbar.value = health
	get():
		return health
@export var healthbar: EnemyHealthbar3D
@export var sprite: AnimatedSprite3D
@export var collisionbox_shape: CollisionShape3D
@export var damagebox_shape: CollisionShape3D
var anim_frame: int:
	get(): return self.sprite.frame
	set(value): self.sprite.frame = value
var anim_anim: StringName:
	get(): return self.sprite.animation
	set(value): self.sprite.animation = value

func damage(amount: float) -> void:
	self.health -= amount

##
## -1 = no direction
## 0 = up right
## 1 = down right
## 2 = down left
## 3 = up left
static func pick_diagonal_direction(dir: Vector2) -> int:
	const down_right := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	const down_left := Vector2(cos(deg_to_rad(135.0)), sin(deg_to_rad(135.0)))
	const up_right := Vector2(cos(deg_to_rad(-45.0)), sin(deg_to_rad(-45.0)))
	const up_left := Vector2(cos(deg_to_rad(-135.0)), sin(deg_to_rad(-135.0)))
	const angle_threshold := cos(deg_to_rad(45.0))
	if dir.is_zero_approx():
		return -1
	var normalized := dir.normalized()
	if normalized.dot(down_right) >= angle_threshold:
		return 1
	elif normalized.dot(down_left) >= angle_threshold:
		return 2
	elif normalized.dot(up_right) >= angle_threshold:
		return 0
	elif normalized.dot(up_left) >= angle_threshold:
		return 3
	breakpoint
	return -1

func set_anim(dir: Vector2):
	if dir.is_zero_approx():
		self.sprite.stop()
		return
	match dir:
		Vector2.UP:
			if self.sprite.animation != &"running_up_right" and self.sprite.animation != &"running_up_left":
				self.sprite.play(&"running_up_right")
			else: self.sprite.play()
		Vector2.DOWN:
			if self.sprite.animation != &"running_down_right" and self.sprite.animation != &"running_down_left":
				self.sprite.play(&"running_down_right")
			else: self.sprite.play()
		Vector2.LEFT:
			if self.sprite.animation != &"running_down_left" and self.sprite.animation != &"running_up_left":
				self.sprite.play(&"running_down_left")
			else: self.sprite.play()
		Vector2.RIGHT:
			if self.sprite.animation != &"running_down_right" and self.sprite.animation != &"running_up_right":
				self.sprite.play(&"running_down_right")
			else: self.sprite.play()
		_:
			match pick_diagonal_direction(dir):
				0: self.sprite.play(&"running_up_right")
				1: self.sprite.play(&"running_down_right")
				2: self.sprite.play(&"running_down_left")
				3: self.sprite.play(&"running_up_left")

func do_move(dir: Vector2, delta: float) -> void:
	var dir_3 := Vector3(dir.x, 0, dir.y)
	
	var delta_velocity := (self.get_gravity() + dir_3 * accel) * delta
	
	self.velocity += delta_velocity * 0.5
	self.velocity *= 0.85 if dir.is_zero_approx() else 0.95
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
	if motion.y == 0: self.velocity.y = 0

func find_target(target_pos: Vector3, need_los: bool = true) -> void:
	var space := get_world_3d().direct_space_state
	var result := space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, target_pos, 0b10001))
	var now := Time.get_ticks_msec()
	if not need_los:
		nav.target_position = target_pos
	if result and result.collider == player:
		nav.target_position = target_pos
		self.target = target_pos
		self.last_seen_target = Time.get_ticks_msec()
		self.can_see_player = true
	elif self.last_seen_target != -1:
		self.can_see_player = false
		var result2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, self.nav.target_position))
		if result2:
			self.target = nav.get_next_path_position()
		else:
			self.target = self.nav.target_position
		var dist := self.nav.target_position - self.global_position
		if (Vector2(dist.x, dist.z).length_squared() < 0.5 * 0.5 and absf(dist.y) < 1.0) or now - self.last_seen_target >= 10 * 1000:
			self.last_seen_target = -1
	else:
		var wander_dist := self.wander_pos - self.global_position
		if self.wander_timer < now or Vector2(wander_dist.x, wander_dist.z).length_squared() < 0.5 * 0.5:
			self.wander_pos = self.global_position + Vector3(randfn(0, 10),0,randfn(0, 10))
			self.wander_timer = now + randi_range(500, 3000)
		self.nav.target_position = wander_pos
		self.target = self.nav.get_next_path_position()

func set_collision_layers(is_alive: bool) -> void:
	if is_alive:
		self.collision_layer |= 0b100
		self.collision_mask |= 0b101
	else:
		self.collision_layer &= ~0b100
		self.collision_mask &= ~0b101
	damagebox_shape.disabled = not is_alive

func _ready() -> void:
	time_manager.register(self, 
		["position", "health", "anim_frame", "anim_anim"],
		[TYPE_VECTOR3, TYPE_FLOAT, TYPE_INT, TYPE_STRING_NAME], 
		["", "", "", ""], 
		[true, true, false, false],
	)

func _physics_process(delta: float) -> void:
	var is_alive := self.health > 0.0
	set_collision_layers(is_alive)

	if time_manager.allow_time():
		if not is_alive:
			self.sprite.stop()
			return
		find_target(player.position + Vector3(0.0, 0.5, 0.0))
		var to_target := self.target - self.global_position
		var move_dir := Vector2(to_target.x, to_target.z).normalized()
		do_move(move_dir, delta)
		set_anim(move_dir.rotated(PI/4))
	else:
		self.velocity = Vector3()
