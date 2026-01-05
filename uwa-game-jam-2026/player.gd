extends Node2D

@export var speed := 250.0
@export var max_time_ms := 30.0 * 1000.0
@export var base_reset_time_ms := 1.5 * 1000.0
# how long the current rewind of time should take
var reset_time_ms: float
# the value on the timer (in ms) when time was rewound
var reset_at: float
# at most every X seconds, save the current position
# accumulator is reset every time, so it is inaccurate (on purpose kinda)
@export var position_capture_time := 0.1
var position_capture_accumulator := 0.0

@onready var timer := Time.get_ticks_msec()
@onready var reset_pos := self.position
var old_positions: PackedVector2Array = []
var state := STATE_NORMAL

@export var timer_label: TimerDisplay

enum {
	STATE_NORMAL,
	STATE_RESETTING,
}

func _ready() -> void:
	timer_label.max_value = max_time_ms / 1000.0

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	match self.state:
		STATE_NORMAL:
			var input_dir := Input.get_vector("left", "right", "up", "down")
			# temporary
			self.position += input_dir * speed * delta
			
			self.position_capture_accumulator += delta
			if self.position_capture_accumulator > self.position_capture_time:
				self.position_capture_accumulator = 0
				self.old_positions.append(self.position)
			
			if self.timer + max_time_ms <= now or Input.is_action_just_pressed("reset"):
				self.reset_at = max(0, max_time_ms - (now - self.timer))
				self.timer = now
				self.reset_time_ms = self.base_reset_time_ms * (1.0 - self.reset_at / self.max_time_ms)
				self.state = STATE_RESETTING
				timer_label.value = 0.0
			else:
				timer_label.value = (max_time_ms - (now - self.timer)) / 1000.0
		STATE_RESETTING:
			var time_passed := now - self.timer
			var reset_amount := time_passed / reset_time_ms
			if reset_amount >= 1.0:
				self.timer = now
				self.state = STATE_NORMAL
				timer_label.value = max_time_ms / 1000.0
				self.position = reset_pos
				self.old_positions.clear()
			else:
				var index_f := (1.0 - reset_amount) * self.old_positions.size()
				var index := int(index_f)
				var lerp_amount := index_f - index
					
				self.position = self.old_positions[0] if index == 0 else self.old_positions[index-1].lerp(self.old_positions[index], lerp_amount)
				timer_label.value = ((time_passed / base_reset_time_ms) * max_time_ms + self.reset_at) / 1000.0
	timer_label.queue_redraw()
