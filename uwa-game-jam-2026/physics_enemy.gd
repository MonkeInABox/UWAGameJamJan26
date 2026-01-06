extends RigidBody2D


@export var player: Node2D
@onready var time_manager: TimeManager = %"time manager"
@onready var nav: NavigationAgent2D = $"NavigationAgent2D"

var target: Vector2
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
var healthbar: EnemyHealthBar

func _ready() -> void:
	healthbar = EnemyHealthBar.new(self, $"healthbar_marker".position, max_health, 32.0)
	$"healthbar_marker".queue_free()
	self.get_parent().add_child.call_deferred(healthbar)
	time_manager.register(self, 
		["position", "rotation", "health"], 
		[Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], 
		["", "", ""], 
		[true, true, true], 
	true, true)

var last_result: Dictionary

func after_reset() -> void:
	PhysicsServer2D.body_set_state(
		get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D.IDENTITY.translated(self.position),
	)
	self.freeze = false
func before_reset() -> void:
	self.freeze = true
	self.linear_velocity = Vector2()
	self.angular_velocity = 0
	self.last_seen_target = -1

func _physics_process(_delta: float) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		var is_alive := self.health > 0.0
		if not is_alive:
			return
		var space := get_world_2d().direct_space_state
		var result := space.intersect_ray(PhysicsRayQueryParameters2D.create(self.position, player.position, 0b0011))
		
		# debug draw
		if visualize_ai and result: 
			self.last_result = result
			self.queue_redraw()
		
		if result and result.collider == player:
			self.sleeping = false
			nav.target_position = player.position
			self.target = player.position
			self.last_seen_target = Time.get_ticks_msec()
		elif self.last_seen_target != -1:
			var result2 := space.intersect_ray(PhysicsRayQueryParameters2D.create(self.position, self.nav.target_position))
			if result2:
				self.target = nav.get_next_path_position()
			else:
				self.target = self.nav.target_position
				
			var now := Time.get_ticks_msec()
			if (self.nav.target_position - self.position).length_squared() < 10 * 10 or now - self.last_seen_target >= 10 * 1000:
				self.last_seen_target = -1
	

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		if self.health <= 0 or self.last_seen_target == -1: return
		state.apply_central_force((self.target - self.position).normalized() * 100)

func _draw() -> void:
	if visualize_ai and self.last_result and self.health > 0:
		draw_line(Vector2(), self.to_local(self.last_result.position), Color.GREEN)
		draw_line(self.to_local(self.last_result.position), self.to_local(self.player.position), Color.RED)
		if self.last_seen_target != -1:
			draw_line(Vector2(), self.to_local(self.target), Color.CYAN)
			draw_line(Vector2(), self.to_local(self.nav.target_position), Color.BLUE)
