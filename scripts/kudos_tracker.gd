class_name KudosTracker
extends RefCounted




















class KudosEvent:
	extends RefCounted
	var label: String
	var amount: int
	
	var is_penalty: bool

	func _init(p_label: String, p_amount: int, p_is_penalty: bool) -> void:
		label = p_label
		amount = p_amount
		is_penalty = p_is_penalty





class Telemetry:
	extends RefCounted
	
	var forward_speed: float = 0.0
	
	var speed: float = 0.0
	
	
	var slip_angle: float = 0.0
	
	var yaw_rate: float = 0.0
	
	
	var uprightness: float = 1.0
	
	var wheels_on_ground: int = 4
	
	var on_road: bool = true
	
	
	var nearest_obstacle_dist: float = 999.0
	
	
	
	
	var braking: bool = false






var min_scoring_speed: float = 5.0


var drift_slip_threshold: float = 0.25

var drift_rate: float = 60.0



var speed_rate: float = 8.0

var speed_bonus_fraction: float = 0.6


var airtime_rate: float = 90.0


var near_miss_distance: float = 3.0

var near_miss_reward: float = 50.0


var near_miss_cooldown: float = 0.8


var offroad_penalty_rate: float = 25.0



var spinout_yaw_threshold: float = 2.0



var spinout_penalty: float = 30.0


var flip_uprightness_threshold: float = 0.3

var flip_penalty: float = 150.0



var crash_decel_threshold: float = 6.0





var crash_decel_threshold_braking: float = 14.0

var crash_penalty_per_ms: float = 20.0



var combo_step: float = 0.25
var combo_max: float = 5.0

var combo_timeout: float = 4.0





var _kudos: float = 0.0

var _combo: float = 1.0

var _combo_idle: float = 0.0

var _near_miss_timer: float = 0.0

var _prev_speed: float = -1.0

var _was_flipped: bool = false
var _was_spinning: bool = false

var _was_drifting: bool = false



var _delta_for_bleed: float = 1.0 / 60.0



func get_kudos() -> int:
	return int(round(_kudos))



func get_combo() -> float:
	return _combo



func reset() -> void:
	_kudos = 0.0
	forget_motion()





func forget_motion() -> void:
	_prev_speed = -1.0
	_was_flipped = false
	_was_spinning = false
	_was_drifting = false
	_combo = 1.0
	_combo_idle = 0.0
	_near_miss_timer = 0.0






func update(t: Telemetry, delta: float) -> Array[KudosEvent]:
	var events: Array[KudosEvent] = []
	if delta <= 0.0:
		return events

	_delta_for_bleed = delta
	_tick_timers(delta)

	
	
	var penalised := _score_mistakes(t, events)

	
	var can_style := t.speed >= min_scoring_speed and t.uprightness > flip_uprightness_threshold
	if can_style and not penalised:
		_score_cool_moves(t, delta, events)
	else:
		
		
		_was_drifting = false

	_prev_speed = t.speed
	_kudos = maxf(0.0, _kudos)
	return events




func _tick_timers(delta: float) -> void:
	if _near_miss_timer > 0.0:
		_near_miss_timer = maxf(0.0, _near_miss_timer - delta)
	
	_combo_idle += delta
	if _combo_idle >= combo_timeout:
		_combo = 1.0





func _score_mistakes(t: Telemetry, events: Array[KudosEvent]) -> bool:
	var hard_mistake := false

	
	
	
	
	if _prev_speed >= 0.0:
		var decel := _prev_speed - t.speed
		var threshold := crash_decel_threshold_braking if t.braking else crash_decel_threshold
		if decel >= threshold:
			var penalty := decel * crash_penalty_per_ms
			_apply_penalty("CRASH", penalty, events)
			hard_mistake = true

	
	var flipped := t.uprightness < flip_uprightness_threshold
	if flipped and not _was_flipped:
		_apply_penalty("FLIPPED", flip_penalty, events)
		hard_mistake = true
	_was_flipped = flipped

	
	var spinning := absf(t.yaw_rate) > spinout_yaw_threshold and t.speed > min_scoring_speed
	if spinning and not _was_spinning:
		_apply_penalty("SPIN OUT", spinout_penalty, events)
		hard_mistake = true
	_was_spinning = spinning

	
	
	
	if not t.on_road and t.speed > min_scoring_speed:
		_kudos -= offroad_penalty_rate * _delta_for_bleed
		
		

	return hard_mistake



func _score_cool_moves(t: Telemetry, delta: float, events: Array[KudosEvent]) -> void:
	var earned_this_frame := false

	
	var drifting := t.slip_angle > drift_slip_threshold and t.wheels_on_ground >= 2
	if drifting:
		var slip_factor: float = clampf(t.slip_angle / (PI * 0.5), 0.0, 1.0)
		var gain := drift_rate * delta * (0.5 + slip_factor) * _speed_factor(t)
		_kudos += gain * _combo
		earned_this_frame = true
		if not _was_drifting:
			_bump_combo()
			events.append(KudosEvent.new("DRIFT", int(round(gain * _combo)), false))
	_was_drifting = drifting

	
	if t.wheels_on_ground == 0:
		var gain := airtime_rate * delta
		_kudos += gain * _combo
		earned_this_frame = true

	
	if _near_miss_timer <= 0.0 and t.nearest_obstacle_dist < near_miss_distance \
			and t.speed > min_scoring_speed:
		var reward := near_miss_reward * _speed_factor(t)
		_kudos += reward * _combo
		_near_miss_timer = near_miss_cooldown
		_bump_combo()
		events.append(KudosEvent.new("NEAR MISS", int(round(reward * _combo)), false))
		earned_this_frame = true

	
	if t.on_road and t.forward_speed > 0.0:
		var over := _speed_over_fraction(t)
		if over > 0.0:
			_kudos += speed_rate * delta * over * _combo
			earned_this_frame = true

	if earned_this_frame:
		_combo_idle = 0.0




func _speed_factor(t: Telemetry) -> float:
	
	return clampf(t.speed / 30.0, 0.2, 1.5)




func _speed_over_fraction(t: Telemetry) -> float:
	var ref := 30.0
	var threshold := ref * speed_bonus_fraction
	if t.speed <= threshold:
		return 0.0
	return clampf((t.speed - threshold) / (ref - threshold), 0.0, 1.0)


func _bump_combo() -> void:
	_combo = minf(combo_max, _combo + combo_step)
	_combo_idle = 0.0


func _apply_penalty(label: String, amount: float, events: Array[KudosEvent]) -> void:
	var before := _kudos
	_kudos = maxf(0.0, _kudos - amount)
	var lost := int(round(before - _kudos))
	
	_combo = 1.0
	_combo_idle = 0.0
	events.append(KudosEvent.new(label, -lost, true))
