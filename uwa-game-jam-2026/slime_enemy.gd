extends BasicEnemy

var last_hit := Time.get_ticks_msec()
var hit_cooldown_ms := 200
@export var contact_damage := 1.0
var currently_contacting: Dictionary[Area3D, bool] = {}


func _on_damagebox_area_entered(area: Area3D) -> void:
	if area.get_parent() is Player3D:
		currently_contacting[area] = true


func _on_damagebox_area_exited(area: Area3D) -> void:
	if area.get_parent() is Player3D:
		currently_contacting.erase(area)
		
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if  self.health > 0 and self.time_manager.allow_time() and currently_contacting and self.last_hit + self.hit_cooldown_ms <= now:
		self.last_hit = now
		for node in currently_contacting:
			var thing_with_health: Player3D = node.get_parent()
			thing_with_health.health -= self.contact_damage
