class_name TimeManager extends Node

enum {
	STATE_NORMAL,
	STATE_RESETTING,
	STATE_CHECKPOINTING,
	STATE_PLAYER_DEATH,
}

var data: Dictionary[Node, Dictionary] = {}
var initial_states: Dictionary[Node, Dictionary] = {}
var do_lerp: Dictionary[Node, Dictionary] = {}
var do_before_resets: Dictionary[Node, bool] = {}
var do_after_resets: Dictionary[Node, bool] = {}

# at most every X seconds, save the current position
# accumulator is reset every time, so it is inaccurate (on purpose kinda)
@export var capture_time := 0.1
var capture_accumulator: float

var num_samples := 0
var started_at: Dictionary[Node, int] = {}

var state := STATE_NORMAL

@export var max_time_ms := 30.0 * 1000.0
@export var base_reset_time_ms := 2.0 * 1000.0
# how long the current rewind of time should take
var reset_time_ms: float
# the value on the timer (in ms) when time was rewound
var reset_at: float

@onready var timer := Time.get_ticks_msec()
@export var timer_label: TimerDisplay

func allow_time() -> bool:
	return self.state != STATE_RESETTING

func register(node: Node, property_names: Array[StringName], property_types: Array[Variant.Type], property_class_names: Array[StringName], property_do_lerp: Array[bool], do_before_reset: bool = false, do_after_reset: bool = false) -> void:
	if node in data:
		var dict := data[node]
		var initial := do_lerp[node]
		var lerps := initial_states[node]
		for i in property_names.size():
			dict[property_names[i]] = Array([], property_types[i], property_class_names[i], null)
			initial[property_names[i]] = property_do_lerp[i]
			lerps[property_names[i]] = node.get(property_names[i])
	else:
		var dict: Dictionary[StringName, Array] = {}
		var initial: Dictionary[StringName, Variant] = {}
		var lerps: Dictionary[StringName, bool] = {}
		for i in property_names.size():
			dict[property_names[i]] = Array([], property_types[i], property_class_names[i], null)
			lerps[property_names[i]] = property_do_lerp[i]
			initial[property_names[i]] = node.get(property_names[i])
		data[node] = dict
		initial_states[node] = initial
		do_lerp[node] = lerps
		do_before_resets[node] = do_before_reset
		do_after_resets[node] = do_after_reset
	started_at[node] = num_samples

func unregister(node: Node) -> void:
	data.erase(node)
	initial_states.erase(node)
	do_lerp.erase(node)
	do_before_resets.erase(node)
	do_after_resets.erase(node)
	started_at.erase(node)

func check_nodes():
	for node in data:
		if node.is_queued_for_deletion():
			unregister(node)

func checkpoint() -> void:
	self.timer = Time.get_ticks_msec()
	self.state = STATE_NORMAL
	timer_label.value = max_time_ms / 1000.0
	self.clear()
	for node in data:
		set_new_initial(node)

func set_new_initial(node: Node) -> void:
	var initial: Dictionary[StringName, Variant] = initial_states[node]
	for property in data[node]:
		initial[property] = node.get(property)

func sample() -> void:
	num_samples += 1
	for node in data:
		var node_data: Dictionary[StringName, Array] = data[node]
		for property in node_data:
			node_data[property].append(node.get(property))

func playback(playback_position: float) -> void:
	var index_f := playback_position * self.num_samples
	var index := int(index_f)
	var lerp_amount := index_f - index
	for node in data:
		var this_index := index - started_at[node]
		if this_index < 0:
			 # the node didn't exist at this point in time, set it to its initial value
			var initial: Dictionary[StringName, Variant] = initial_states[node]
			for property in initial:
				node.set(property, initial[property])
			continue
		var node_data: Dictionary[StringName, Array] = data[node]
		var lerps: Dictionary[StringName, bool] = do_lerp[node]
		for property in node_data:
			if this_index != 0 and lerps[property]:
				var array := node_data[property]
				node.set(property, lerp(array[this_index - 1], array[this_index], lerp_amount))
			else:
				node.set(property, node_data[property][this_index])

func set_to_initial() -> void:
	for node in data:
		var node_data: Dictionary[StringName, Variant] = initial_states[node]
		for property in node_data:
			#print("setting ", property, " on ", node, " to ",  node_data[property])
			node.set(property, node_data[property])
		if do_after_resets[node]:
			node.after_reset()

func clear() -> void:
	num_samples = 0
	for node in data:
		started_at[node] = 0
		var node_data: Dictionary[StringName, Array] = data[node]
		for property in node_data:
			node_data[property].clear()
			
func _ready() -> void:
	timer_label.set_max_value(max_time_ms / 1000.0)
	
var queue_reset := false

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	match state:
		STATE_NORMAL, STATE_PLAYER_DEATH:
			self.capture_accumulator += delta
			if self.capture_accumulator > self.capture_time:
				self.capture_accumulator = 0
				self.sample()
				
			if ((self.timer + max_time_ms <= now or Input.is_action_just_pressed("reset")) and state != STATE_PLAYER_DEATH) or queue_reset:
				self.queue_reset = false
				self.reset_at = max(0, max_time_ms - (now - self.timer))
				self.timer = now
				self.reset_time_ms = self.base_reset_time_ms * (1.0 - self.reset_at / self.max_time_ms)
				self.state = STATE_RESETTING
				for node in do_before_resets:
					if do_before_resets[node]:
						node.before_reset()
				timer_label.value = 0.0
			else:
				timer_label.value = max(0.0, (max_time_ms - (now - self.timer)) / 1000.0)
				
		STATE_RESETTING:
			var time_passed := now - self.timer
			var reset_amount := time_passed / reset_time_ms
			if reset_amount >= 1.0:
				self.timer = now
				self.state = STATE_NORMAL
				timer_label.value = max_time_ms / 1000.0
				set_to_initial()
				clear()
			else:
				playback(1.0 - reset_amount)
				timer_label.value = ((time_passed / base_reset_time_ms) * max_time_ms + self.reset_at) / 1000.0
		STATE_CHECKPOINTING:
			pass
	timer_label.queue_redraw()
	self.check_nodes.call_deferred()
