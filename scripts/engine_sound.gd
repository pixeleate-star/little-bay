class_name EngineSound
extends Node
















const SOUND_PATH := "res://sounds/car_engine.mp3"




const SWEEP_START := 5.45
const SWEEP_END := 8.20




const SHIFT_START := 8.20
const SHIFT_END := 8.90


const VOLUME_IDLE_DB := -14.0
const VOLUME_MAX_DB := -4.0





const DRIFT_TOLERANCE := 0.15

var _player: AudioStreamPlayer = null



var _muted: bool = false



enum State { SWEEP, SHIFT }
var _state: State = State.SWEEP


var _prev_gear: int = Transmission.GEAR_NEUTRAL


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "EngineSoundPlayer"
	_player.bus = &"Master"
	_player.volume_db = VOLUME_IDLE_DB
	
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	var stream := load(SOUND_PATH)
	if stream is AudioStream:
		_player.stream = stream
	else:
		push_warning("EngineSound: could not load %s" % SOUND_PATH)
	add_child(_player)







func update_engine(speed_kmh: float, gear: int, gear_ratio: float) -> void:
	if _player == null or _player.stream == null:
		return
	if _muted:
		return

	var moving := gear != Transmission.GEAR_NEUTRAL and speed_kmh > 1.0

	
	var speed_factor := clampf(speed_kmh / 180.0, 0.0, 1.0)
	_player.volume_db = lerpf(VOLUME_IDLE_DB, VOLUME_MAX_DB, speed_factor)

	
	if gear > 0 and _prev_gear > 0 and gear > _prev_gear:
		_state = State.SHIFT
		if _player.playing:
			_player.seek(SHIFT_START)
	_prev_gear = gear

	
	if not _player.playing:
		_player.play(SWEEP_START)
		_state = State.SWEEP

	var pos := _player.get_playback_position()

	match _state:
		State.SHIFT:
			
			if pos >= SHIFT_END or pos < SHIFT_START:
				
				_state = State.SWEEP
				var target := _sweep_position_for_ratio(
					clampf(gear_ratio, 0.0, 1.0) if moving else 0.0)
				_player.seek(target)

		State.SWEEP:
			var ratio := clampf(gear_ratio, 0.0, 1.0) if moving else 0.0
			var target := _sweep_position_for_ratio(ratio)

			
			
			if pos < SWEEP_START or pos >= SWEEP_END:
				_player.seek(target)
			elif absf(pos - target) > DRIFT_TOLERANCE:
				_player.seek(target)
			
			






func set_muted(muted: bool) -> void:
	_muted = muted
	if _player == null:
		return
	if muted:
		_player.stop()
	
	



func _sweep_position_for_ratio(ratio: float) -> float:
	return lerpf(SWEEP_START, SWEEP_END, ratio)
