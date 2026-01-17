extends RigidBody3D


@export var player: Node3D
@onready var time_manager: TimeManager = %"time manager"
@onready var nav: NavigationAgent3D = $"NavigationAgent3D"

var target: Vector3
var last_seen_target: int = -1
var last_hit := Time.get_ticks_msec()
var hit_cooldown_ms := 100

const visualize_ai = false

@export var max_health := 20.0:
	set(value):
		max_health = value
		healthbar.max_value = value
	get():
		return max_health
var health := max_health:
	set(value):
		if health != 0.0 and value < health:
			sprite.modulate = Color.RED
			var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		health = clampf(value, 0.0, max_health)
		healthbar.value = health
	get():
		return health
@onready var healthbar: EnemyHealthbar3D = $"healthbar"
@onready var sprite: Sprite3D = $"physics enemy visuals"
@onready var collisionbox_shape: CollisionShape3D = $CollisionShape3D
@onready var damagebox_shape: CollisionShape3D = $damagebox/CollisionShape3D
#@onready var hurtbox_shape: CollisionShape3D = $hurtbox/CollisionShape3D
@onready var audio_loop: AudioStreamPlayer3D = $enginesfx
@onready var audio_impact: AudioStreamPlayer3D = $impactsfx

@export var contact_damage := 5.0

func damage(amount: float) -> void:
	self.health -= amount

func _ready() -> void:
	time_manager.register(self, 
		["position", "quaternion", "health"], 
		[TYPE_VECTOR3, TYPE_QUATERNION, TYPE_FLOAT], 
		["", "", ""], 
		[true, true, true], 
	true, true)

var last_result: Dictionary

func after_reset() -> void:
	PhysicsServer3D.body_set_state(
		get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D.IDENTITY.translated(self.position),
	)
	self.freeze = false
func before_reset() -> void:
	self.freeze = true
	self.linear_velocity = Vector3()
	self.angular_velocity = Vector3()
	self.last_seen_target = -1
	
var height_pid_integral := 0.0
var height_pid_error := 0.0
var height_pid_p := 4.0
var height_pid_i := 1.0
var height_pid_d := 1.0

#@onready var debug_vis: Line3D = $"Line3D"
#@onready var debug_vis2: Line3D = $"Line3D2"
#@onready var debug_vis3: Line3D = $"Line3D3"

var currently_contacting: Dictionary[Area3D, bool] = {}

func _physics_process(delta: float) -> void:
	var is_alive := self.health > 0.0
	if is_alive:
		self.collision_layer |= 0b100
		self.collision_mask |= 0b101
	else:
		self.collision_layer &= ~0b100
		self.collision_mask &= ~0b101
	
	damagebox_shape.disabled = not is_alive
	if time_manager.allow_time():
		if audio_loop.playing != is_alive: audio_loop.playing = is_alive
		if not is_alive:
			return
		var space := get_world_3d().direct_space_state
		var player_pos := player.position + Vector3(0.0, 0.5, 0.0)
		var result := space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, player_pos, 0b10001))
		
		#debug_vis.a = self.global_position
		#debug_vis.b = result.position if result else player.global_position
		#debug_vis.color = Color.BLUE if result and result.collider == player else Color.RED
		
		var now := Time.get_ticks_msec()
		if result and result.collider == player:
			self.sleeping = false
			nav.target_position = player_pos
			#debug_vis3.b = self.nav.target_position
			#debug_vis3.color = Color.TRANSPARENT
			#debug_vis2.color = Color.TRANSPARENT
			self.target = player_pos
			self.last_seen_target = Time.get_ticks_msec()
		elif self.last_seen_target != -1:
			var result2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, self.nav.target_position))
			if result2:
				self.target = nav.get_next_path_position()
			else:
				self.target = self.nav.target_position
				
			if ((self.nav.target_position - self.position).length_squared() < 0.5 * 0.5 and self.linear_velocity.length_squared() < 0.5 * 0.5) or now - self.last_seen_target >= 10 * 1000:
				self.last_seen_target = -1
			#debug_vis3.color = Color.ORANGE
			#debug_vis2.color = Color.CYAN
			#debug_vis2.b = self.target
		#elif self.last_seen_target == -1:
			#debug_vis3.color = Color.TRANSPARENT
			#debug_vis2.color = Color.TRANSPARENT
		#debug_vis2.a = self.global_position
		#debug_vis3.a = self.global_position
		
		
				
		var floor_trace = space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, self.position + Vector3.DOWN * 64.0))
		const target_height := 0.5
		if floor_trace:
			var dist: float = (self.position - (floor_trace.position as Vector3)).length()
			var error := target_height - dist
			var proportional := error
			height_pid_integral += error * delta
			var derivative := (error - height_pid_error) / delta
			var output := height_pid_p * proportional + height_pid_i * height_pid_integral + height_pid_d * derivative
			height_pid_error = error
			self.apply_central_force(Vector3.UP * output * 10.0)
			
		if self.health <= 0: return
		if currently_contacting and self.last_hit + self.hit_cooldown_ms <= now:
			self.last_hit = now
			audio_impact.pitch_scale = randfn(1.0, 0.05)
			audio_impact.play()
			for node in currently_contacting:
				var position_delta := self.global_position - node.global_position
				var thing_with_health: Player3D = node.get_parent()
				self.apply_impulse(Vector3(position_delta.x, 0.0, position_delta.z).normalized().rotated(Vector3.UP, randf_range(-0.1, 0.1)) * randf_range(1.5, 4.0) + -self.linear_velocity + thing_with_health.velocity, Vector3(randfn(0, 0.1), 0, randfn(0, 0.1)))
				thing_with_health.health -= self.contact_damage
	else:
		audio_loop.stop()
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.transform.basis = Basis(Vector3.UP, self.rotation.y)
	state.angular_velocity.x = 0
	state.angular_velocity.z = 0
	if time_manager.allow_time():
		if self.health <= 0 or self.last_seen_target == -1: return
		state.apply_central_force((self.target - self.position).normalized() * 3.0)

func _on_damagebox_area_entered(area: Area3D) -> void:
	if area.get_parent() is Player3D:
		currently_contacting[area] = true


func _on_damagebox_area_exited(area: Area3D) -> void:
	if area.get_parent() is Player3D:
		currently_contacting.erase(area)
