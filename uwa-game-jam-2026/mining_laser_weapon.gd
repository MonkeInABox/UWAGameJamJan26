extends Player3D.Weapon

@onready var time_manager: TimeManager = %"time manager"

@onready var particles: GPUParticles3D = $sparks
@onready var line_mesh: MeshInstance3D = $laser_mesh

@export var damage := 1.0
@export var hit_time_ms := 200
@onready var last_hit := Time.get_ticks_msec()

var point: Vector3:
	set(value):
		point = value
		line_mesh.global_position = (self.global_position + point) / 2.0
		var difference := self.global_position - point
		var dir := difference.normalized()
		var x := Vector3.UP.cross(dir)
		var z := x.cross(dir)
		line_mesh.basis = Basis(x, difference, z)
	get():
		return point
		
var line_visible: bool:
	set(value):
		line_mesh.visible = value
		particles.emitting = value
	get():
		return line_mesh.visible
		
func _ready() -> void:
	time_manager.register(self,
		["point", "line_visible"],
		[TYPE_VECTOR3, TYPE_BOOL],
		["", ""],
		[true, false]
	)
# jank hack to make it so you cant use both weapons at once
@onready var other_weapon: Player3D.Weapon = self.get_parent().get_children().filter(func (child): return child != self)[0]
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if time_manager.allow_time():
		if self.active and Input.is_action_pressed("attack") and other_weapon.can_attack:
			var space := get_world_3d().direct_space_state
			var target: Vector3
			if use_controller:
				# todo?: aim assist on controller
				target = self.global_position + Vector3(joystick_aim.x, 0, joystick_aim.y) * 1024
			else:
				var viewport := get_viewport()
				var camera := viewport.get_camera_3d()
				var mouse_pos_screen := viewport.get_mouse_position()
				var mouse_pos_world := camera.project_ray_origin(mouse_pos_screen)
				var mouse_normal := camera.project_ray_normal(mouse_pos_screen)
				var mouse_trace_result = space.intersect_ray(PhysicsRayQueryParameters3D.create(mouse_pos_world, mouse_pos_world + mouse_normal * 1024.0))
				target = ((mouse_trace_result.collider as Node3D).global_position if (mouse_trace_result.collider as Node3D).has_method("damage") else (mouse_trace_result.position as Vector3)) if mouse_trace_result else mouse_pos_world + mouse_normal * 45
			var ray_query := PhysicsRayQueryParameters3D.create(self.global_position, target, 0b011000)
			ray_query.collide_with_areas = true
			var result := space.intersect_ray(ray_query)
			if result:
				var collider: Node = result.collider
				var can_damage := collider is CollisionObject3D and collider.has_method("damage") and collider.get("health") as float > 0.0
				if not can_damage and collider is Area3D and collider.get_parent().has_method("damage") and collider.get_parent().get("health") as float > 0.0:
						can_damage = true
						collider = collider.get_parent()
				if not can_damage:
					for offset in range(-10, 20):
						if offset == 0: continue
						var offset_f := offset / 20.0
						ray_query.to = target + Vector3(offset_f * sqrt(1.0/8.0), offset_f * sqrt(2.0)/2.0, offset_f * sqrt(1.0/8.0))
						var result2 := space.intersect_ray(ray_query)
						if not result2: continue
						var collider2: Node = result2.collider
						if collider2 is CollisionObject3D and collider2.has_method("damage") and collider2.get("health") as float > 0.0:
							can_damage = true
							result = result2
							collider = collider2
							break
						elif collider2 is Area3D and collider2.get_parent().has_method("damage") and collider2.get_parent().get("health") as float > 0.0:
							can_damage = true
							collider = collider2.get_parent()
							result = result2
							break
				self.point = result.position
				particles.global_position = result.position
				if last_hit + hit_time_ms < now:
					if can_damage:
						while last_hit + hit_time_ms < now:
							last_hit += hit_time_ms
							collider.damage(damage)
					else: last_hit = now - hit_time_ms
			else:
				if last_hit + hit_time_ms < now: last_hit = now - hit_time_ms
				self.point = target
				particles.global_position = target
			line_mesh.visible = true
			particles.emitting = true
		else:
			if last_hit + hit_time_ms < now: last_hit = now - hit_time_ms
			line_mesh.visible = false
			particles.emitting = false
