extends RigidBody2D


@export var player: Node2D
@onready var time_manager: TimeManager = %"time manager"
@onready var nav: NavigationAgent2D = $"NavigationAgent2D"

var target: Vector2
var last_seen_target: int = -1

const visualize_ai = true

func _ready() -> void:
	time_manager.register(self, ["position", "rotation"], [Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_FLOAT], ["", ""], [true, true], true, true)

var last_result := {}

func after_reset() -> void:
	PhysicsServer2D.body_set_state(
		get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D.IDENTITY.translated(self.position)
	)
	self.freeze = false
func before_reset() -> void:
	self.freeze = true
	self.linear_velocity = Vector2()
	self.angular_velocity = 0
	self.last_seen_target = -1

func _physics_process(_delta: float) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		var space := get_world_2d().direct_space_state
		var result := space.intersect_ray(PhysicsRayQueryParameters2D.create(self.position, player.position))
		
		# debug draw
		if visualize_ai and result: 
			self.last_result = result
			self.queue_redraw()
		
		if result and result.collider == player:
			nav.target_position = player.position
			self.target = player.position
			self.last_seen_target = Time.get_ticks_msec()
		elif self.last_seen_target != -1:
			
			var result2 := space.intersect_ray(PhysicsRayQueryParameters2D.create(self.position, self.nav.target_position))
			if result2:
				self.target = nav.get_next_path_position()
			else:
				self.target = self.nav.target_position
			
	

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if time_manager.state == TimeManager.STATE_NORMAL:
		if self.last_seen_target == -1: return
		var now := Time.get_ticks_msec()
		var diff := self.target - self.position
		if diff.length_squared() < 10 * 10 or now - self.last_seen_target >= 10 * 1000:
			self.last_seen_target = -1
		else:
			state.apply_central_force(diff.normalized() * 100)

func _draw() -> void:
	if visualize_ai:
		draw_line(Vector2(), self.to_local(self.last_result.position), Color.GREEN)
		draw_line(self.to_local(self.last_result.position), self.to_local(self.player.position), Color.RED)
		if self.last_seen_target != -1:
			draw_line(Vector2(), self.to_local(self.target), Color.CYAN)
			draw_line(Vector2(), self.to_local(self.nav.target_position), Color.BLUE)
