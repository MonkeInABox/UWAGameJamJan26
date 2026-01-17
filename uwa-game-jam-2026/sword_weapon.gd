extends Player3D.Weapon

@onready var time_manager: TimeManager = %"time manager"

@onready var mesh: ImmediateMesh = $MeshInstance3D.mesh
@onready var damage_area: Area3D = $Area3D
@onready var damage_shape: CollisionShape3D = $"Area3D/CollisionShape3D"
@export var material: Material
@export var damage := 3.0
@onready var player: Player3D = $"../../."
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

var swing_time := 0.10
var swing_offset_time := 0.025
var total_swing_time := swing_time + swing_offset_time + 0.4

func gen_mesh(size: float, angle_start: float, angle_end: float) -> void:
	mesh.clear_surfaces()
	const step_size := PI/16.0
	var angle_dif := angle_end - angle_start
	while angle_dif < 0: angle_dif += PI * 2
	var steps := ceili(angle_dif / step_size)
	if steps == 0: return
	var actual_step_size := angle_dif / steps
	var angle := angle_start
	var point := Vector3(cos(angle) * size, 0, sin(angle) * size)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for _i in steps:
		mesh.surface_add_vertex(Vector3())
		mesh.surface_add_vertex(point)
		angle += actual_step_size
		point = Vector3(cos(angle) * size, 0, sin(angle) * size)
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	mesh.surface_set_material(0, material)

var can_attack := true

func _ready() -> void:
	time_manager.register(self,
		["current_angle_a", "current_angle_b"],
		[TYPE_FLOAT, TYPE_FLOAT],
		["", ""],
		[true, true],
	)
	pass

var current_angle_a := 0.0
var current_angle_b := 0.0

var start_angle := -7*PI/16
var end_angle := 7*PI/16

var last_aim_dir: float

func _process(_delta: float) -> void:
	gen_mesh(1.0, current_angle_a, current_angle_b)
	if time_manager.allow_time():
		if self.active and Input.is_action_pressed("attack2") and not Input.is_action_pressed("attack") and self.can_attack:
			var aim_dir: float
			if use_controller:
				aim_dir = joystick_aim.angle() - PI/4
			else:
				var viewport := get_viewport()
				var camera := viewport.get_camera_3d()
				var mouse_pos_screen := viewport.get_mouse_position()
				var mouse_pos_world := camera.project_ray_origin(mouse_pos_screen)
				var mouse_normal := camera.project_ray_normal(mouse_pos_screen)
				var aim_origin := (get_parent().get_parent() as Player3D).global_position
				aim_origin.y = self.global_position.y
				var aim_point := mouse_pos_world + mouse_normal * ((aim_origin - mouse_pos_world).dot(Vector3.UP) / mouse_normal.dot(Vector3.UP))
				aim_dir = (aim_origin - aim_point).signed_angle_to(Vector3.FORWARD, Vector3.UP) + PI/2
			self.last_aim_dir = aim_dir
			self.can_attack = false
			self.current_angle_a = start_angle + aim_dir
			self.current_angle_b = start_angle + aim_dir
			damage_area.rotation.y = -(start_angle + aim_dir)
			damage_shape.disabled = false
			var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(self, "current_angle_a", end_angle + aim_dir, swing_time).set_delay(swing_offset_time)
			tween.tween_property(damage_area, "rotation", -Vector3(0,end_angle + aim_dir,0), swing_time)
			tween.tween_property(self, "current_angle_b", end_angle + aim_dir, swing_time)
			tween.tween_callback((func (): damage_shape.disabled = true)).set_delay(swing_time)
			tween.tween_callback((func (): self.can_attack = true)).set_delay(total_swing_time)
			audio.play()
	else:
		damage_shape.disabled = true

func _on_damage_area_entered(area: Area3D) -> void:
	var parent_node := area.get_parent()
	if parent_node.has_method("damage") and parent_node.get("health") as float > 0.0:
		parent_node.damage(self.damage)
	elif parent_node is PlasmaBall and parent_node.alive:
		parent_node.query.exclude = [player.get_rid()]
		parent_node.collide_with_enemies = true
		parent_node.velocity = parent_node.velocity.length() * Vector3(cos(last_aim_dir), 0, sin(last_aim_dir))
