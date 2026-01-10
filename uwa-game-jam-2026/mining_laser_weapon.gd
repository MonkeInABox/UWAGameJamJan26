extends Player.Weapon

@onready var line: Line2D = $laser
@onready var time_manager: TimeManager = %"time manager"

@export var damage := 1.0
@export var hit_time_ms := 200
@onready var last_hit := Time.get_ticks_msec()

var point: Vector2:
	set(value):
		line.points[1] = value
	get():
		return line.points[1]
		
var line_visible: bool:
	set(value):
		line.visible = value
	get():
		return line.visible
		
func _ready() -> void:
	time_manager.register(self,
		["point", "line_visible"],
		[TYPE_VECTOR2, TYPE_BOOL],
		["", ""],
		[true, false]
	)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if time_manager.state == TimeManager.STATE_NORMAL:
		if self.active and Input.is_action_pressed("attack"):
			var target := get_global_mouse_position()
			var space := get_world_2d().direct_space_state
			var ray_query := PhysicsRayQueryParameters2D.create(self.global_position, target, 0b110000)
			ray_query.collide_with_areas = true
			var result := space.intersect_ray(ray_query)
			if result:
				line.points[1] = to_local(result.position)
				if last_hit + hit_time_ms < now:
					var collider: Object = result.collider
					var can_damage := (collider is CollisionObject2D and collider.has_method("damage"))
					if not can_damage and collider is Area2D and (collider as Area2D).get_parent().has_method("damage"):
						can_damage = true
						collider = (collider as Area2D).get_parent()
					if can_damage:
						while last_hit + hit_time_ms < now:
							last_hit += hit_time_ms
							collider.damage(damage)
					else: last_hit = now - hit_time_ms
			else:
				if last_hit + hit_time_ms < now: last_hit = now - hit_time_ms
				line.points[1] = to_local(target)
			line.visible = true
		else:
			if last_hit + hit_time_ms < now: last_hit = now - hit_time_ms
			line.visible = false
