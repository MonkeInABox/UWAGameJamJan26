extends BasicEnemy

enum {
	STATE_DEFAULT,
	STATE_WINDUP,
	STATE_FIRING,
	STATE_WINDDOWN,
}

enum {
	ATTACK_PLASMA_BALL,
}

@onready var plasma_ball_pool: PlasmaBallPool = %plasma_ball_pool

var state := STATE_DEFAULT
var state_timer := 0
var run_away_timer := -1
var random_pos: Vector3
var aim_pos: Vector3

const close_distance := 3.0
const far_distance := 5.0

const windup_time_ms := 400
const fire_time_ms := 1000
const winddown_time_ms := 300
const wander_time_ms := 750
const run_away_time := 2000
const plasma_ball_speed := 5.0

func _ready() -> void:
	time_manager.register(self, 
		["state", "position", "health", "anim_frame", "anim_anim"],
		[TYPE_INT, TYPE_VECTOR3, TYPE_FLOAT, TYPE_INT, TYPE_STRING_NAME], 
		["", "", "", "", ""], 
		[false, true, true, false, false],
	)

func _physics_process(delta: float) -> void:
	var is_alive := self.health > 0.0
	set_collision_layers(is_alive)

	if time_manager.allow_time():
		if not is_alive:
			if self.sprite.animation != &"death":
				self.sprite.play(&"death")
			#self.sprite.stop()
			return
		var now := Time.get_ticks_msec()
		var use_random_pos := self.state == STATE_DEFAULT and self.state_timer > now
		find_target(random_pos if use_random_pos else player.position + Vector3(0.0, 0.5, 0.0), not use_random_pos)
		var vector_to_player := self.player.global_position - self.global_position
		var dist_to_player := vector_to_player.length()
		#prints(state, max(0, state_timer - now))
		match self.state:
			STATE_DEFAULT:
				if !self.can_see_player or dist_to_player > far_distance:
					var to_target := self.target - self.global_position
					var move_dir := Vector2(to_target.x, to_target.z).normalized()
					do_move(move_dir, delta)
					set_anim(move_dir.rotated(PI/4))
				# can_see_player must be true from this point
				elif dist_to_player < close_distance and self.run_away_timer == -1 or self.run_away_timer > now:
					if self.run_away_timer == -1: self.run_away_timer = now + run_away_time
					var move_dir := Vector2(-vector_to_player.x, -vector_to_player.z).normalized()
					do_move(move_dir, delta)
					set_anim(move_dir.rotated(PI/4))
				else:
					if self.state_timer <= now:
						self.run_away_timer = -1
						self.state = STATE_WINDUP
						self.state_timer = now + windup_time_ms
						self.sprite.stop()
					else:
						var to_target := self.target - self.global_position
						var move_dir := Vector2(to_target.x, to_target.z).normalized()
						do_move(move_dir, delta)
						set_anim(move_dir.rotated(PI/4))
						
			STATE_WINDUP:
				if self.state_timer <= now:
					self.state = STATE_FIRING
					self.state_timer = now + fire_time_ms
					#var time_it_takes_ms := vector_to_player.length() / plasma_ball_speed + fire_time_ms / 2000.0
					#self.aim_dir = (vector_to_player + Vector3(0,0.5,0) + player.velocity * time_it_takes_ms).normalized()
					self.aim_pos = player.global_position + Vector3(0,0.5,0)
				match pick_diagonal_direction(Vector2(vector_to_player.x, vector_to_player.z).rotated(PI/4)):
					0: self.sprite.animation = &"running_up_right"
					1: self.sprite.animation = &"running_down_right"
					2: self.sprite.animation = &"running_down_left"
					3: self.sprite.animation = &"running_up_left"
			STATE_FIRING:
				if self.state_timer <= now:
					self.state = STATE_WINDDOWN
					self.state_timer = now + winddown_time_ms
					var ball := plasma_ball_pool.get_ball()
					ball.position = self.global_position
					var to_aim_pos := self.aim_pos - self.global_position
					var travel_time := to_aim_pos.length() / plasma_ball_speed
					ball.velocity = (to_aim_pos + player.velocity * (travel_time + fire_time_ms / 3000.0)).normalized() * plasma_ball_speed
					ball.alive = true
					ball.damage = 20.0
					ball.query.exclude = [self.get_rid()]
					ball.collide_with_enemies = false
			STATE_WINDDOWN:
				if self.state_timer <= now:
					self.state = STATE_DEFAULT
					self.state_timer = now + wander_time_ms
					self.random_pos = self.global_position + Vector3(randfn(0, 4.0),0,randfn(0, 4.0))
	else:
		self.state_timer = 0
		self.run_away_timer = -1
		self.velocity = Vector3()
