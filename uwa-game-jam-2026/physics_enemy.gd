extends RigidBody3D


@export var player: Node3D
@onready var time_manager: TimeManager = %"time manager"
@onready var nav: NavigationAgent3D = $"NavigationAgent3D"

var target: Vector3
var last_seen_target: int = -1

const visualize_ai = false

@export var max_health := 20.0:
	set(value):
		max_health = value
		healthbar.max_value = value
	get():
		return max_health
var health := max_health:
	set(value):
		health = clampf(value, 0.0, max_health)
		healthbar.value = health
	get():
		return health
@onready var healthbar: EnemyHealthbar3D = $"CanvasLayer/healthbar"

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
var height_pid_p := 1.0
var height_pid_i := 1.0
var height_pid_d := 1.0

func _physics_process(delta: float) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		var is_alive := self.health > 0.0
		if not is_alive:
			return
		var space := get_world_3d().direct_space_state
		var result := space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, player.position, 0b0011))
		
		if result and result.collider == player:
			self.sleeping = false
			nav.target_position = player.position
			self.target = player.position
			self.last_seen_target = Time.get_ticks_msec()
		elif self.last_seen_target != -1:
			var result2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, self.nav.target_position))
			if result2:
				self.target = nav.get_next_path_position()
			else:
				self.target = self.nav.target_position
				
			var now := Time.get_ticks_msec()
			if (self.nav.target_position - self.position).length_squared() < 10 * 10 or now - self.last_seen_target >= 10 * 1000:
				self.last_seen_target = -1
				
		var floor_trace = space.intersect_ray(PhysicsRayQueryParameters3D.create(self.position, self.position + Vector3.DOWN * 64.0))
		const target_height := 0.
		if floor_trace:
			var dist: float = (self.position - (floor_trace.position as Vector3)).length()
			var error := target_height - dist
			var proportional := error
			height_pid_integral += error * delta
			var derivative := (error - height_pid_error) / delta
			var output := height_pid_p * proportional + height_pid_i * height_pid_integral + height_pid_d + derivative
			height_pid_error = error
			self.apply_central_force(Vector3.UP * output * 10.0)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		if self.health <= 0 or self.last_seen_target == -1: return
		state.apply_central_force((self.target - self.position).normalized() * 3.0)

func _on_hitbox_area_entered(area: Area3D) -> void:
	if self.health <= 0 or self.time_manager.state != TimeManager.STATE_NORMAL: return
	var parent := area.get_parent()
	if parent is Player3D:
		self.apply_impulse((self.global_position - area.global_position).normalized().rotated(Vector3.UP, randf_range(-0.1, 0.1)) * randf_range(2.25, 4.375), Vector3(randfn(0, 2), 0, randfn(0, 2)))
		(parent as Player3D).health -= contact_damage
