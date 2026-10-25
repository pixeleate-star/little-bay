class_name StreetNameTracker
extends RefCounted








var settle_time: float = 0.6

var _announced: String = ""
var _candidate: String = ""
var _candidate_time: float = 0.0




func update(street: String, delta: float) -> String:
	if street == "" or street == _announced:
		_candidate = ""
		_candidate_time = 0.0
		return ""
	if street != _candidate:
		_candidate = street
		_candidate_time = 0.0
	_candidate_time += delta
	if _candidate_time < settle_time:
		return ""
	_announced = street
	_candidate = ""
	_candidate_time = 0.0
	return street




func reset() -> void:
	_announced = ""
	_candidate = ""
	_candidate_time = 0.0
