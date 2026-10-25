class_name RunSession
extends RefCounted










enum Mode { FREE_DRIVE, KUDOS_ATTACK, SPRINT }
enum State { IDLE, COUNTDOWN, RUNNING, FINISHED }

enum Cue { NONE, GO, FINISHED }


var duration: float = 180.0

var countdown_time: float = 3.0

var state: State = State.IDLE


var score: int = 0
var distance_m: float = 0.0
var top_speed_ms: float = 0.0
var drifts: int = 0
var near_misses: int = 0

var mistakes: int = 0

var best_move_label: String = ""
var best_move_amount: int = 0


var elapsed: float = 0.0

var _countdown_left: float = 0.0
var _time_left: float = 0.0



func start() -> void:
	state = State.COUNTDOWN
	_countdown_left = countdown_time
	_time_left = duration
	elapsed = 0.0
	score = 0
	distance_m = 0.0
	top_speed_ms = 0.0
	drifts = 0
	near_misses = 0
	mistakes = 0
	best_move_label = ""
	best_move_amount = 0




func tick(delta: float, speed_ms: float, kudos: int) -> Cue:
	match state:
		State.COUNTDOWN:
			_countdown_left -= delta
			if _countdown_left <= 0.0:
				_countdown_left = 0.0
				state = State.RUNNING
				return Cue.GO
		State.RUNNING:
			
			var step := minf(delta, _time_left) if has_time_limit() else delta
			_time_left -= step
			elapsed += step
			distance_m += speed_ms * step
			top_speed_ms = maxf(top_speed_ms, speed_ms)
			score = kudos
			if has_time_limit() and _time_left <= 0.0:
				_time_left = 0.0
				state = State.FINISHED
				return Cue.FINISHED
	return Cue.NONE



func finish(kudos: int) -> void:
	if state != State.RUNNING:
		return
	score = kudos
	state = State.FINISHED


func has_time_limit() -> bool:
	return duration > 0.0



func record_event(label: String, amount: int, is_penalty: bool) -> void:
	if state != State.RUNNING:
		return
	if is_penalty:
		mistakes += 1
		return
	match label:
		"DRIFT":
			drifts += 1
		"NEAR MISS":
			near_misses += 1
	if amount > best_move_amount:
		best_move_amount = amount
		best_move_label = label



func countdown_number() -> int:
	return ceili(_countdown_left) if state == State.COUNTDOWN else 0


func time_left() -> float:
	return _time_left


func is_running() -> bool:
	return state == State.RUNNING



static func format_time(seconds: float) -> String:
	var whole := ceili(maxf(seconds, 0.0))
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]



static func format_race_time(seconds: float) -> String:
	var tenths := floori(maxf(seconds, 0.0) * 10.0)
	@warning_ignore("integer_division")
	return "%d:%02d.%d" % [tenths / 600, (tenths % 600) / 10, tenths % 10]



static func format_score(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped





static func record_key(mode: Mode, course: String = "") -> String:
	match mode:
		Mode.KUDOS_ATTACK:
			return "kudos_attack"
		Mode.SPRINT:
			return "sprint_" + course
	return "free_drive"


static func mode_name(mode: Mode) -> String:
	match mode:
		Mode.KUDOS_ATTACK:
			return "KUDOS ATTACK"
		Mode.SPRINT:
			return "CHECKPOINT SPRINT"
	return "FREE DRIVE"
