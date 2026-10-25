class_name RecoveryTracker
extends RefCounted















class SafePoint:
	extends RefCounted
	var position: Vector3
	var forward: Vector3
	var time: float

	func _init(p_position: Vector3, p_forward: Vector3, p_time: float) -> void:
		position = p_position
		forward = p_forward
		time = p_time




var sample_interval: float = 0.5

var max_points: int = 20


var min_age: float = 2.0


var min_spacing: float = 3.0

var _points: Array[SafePoint] = []
var _time: float = 0.0
var _since_sample: float = INF



func update(delta: float, position: Vector3, forward: Vector3, is_safe: bool) -> void:
	_time += delta
	_since_sample += delta
	if not is_safe or _since_sample < sample_interval:
		return
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0001:
		return
	if not _points.is_empty() and _points.back().position.distance_to(position) < min_spacing:
		return
	_record(position, flat.normalized())




func remember(position: Vector3, forward: Vector3) -> void:
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	_record(position, flat.normalized())




func take_recovery_point() -> SafePoint:
	if _points.is_empty():
		return null
	var chosen: SafePoint = _points[0]
	for i: int in range(_points.size() - 1, -1, -1):
		if _time - _points[i].time >= min_age:
			chosen = _points[i]
			break
	_points.resize(_points.find(chosen) + 1)
	
	
	_since_sample = 0.0
	return chosen


func point_count() -> int:
	return _points.size()


func clear() -> void:
	_points.clear()
	_since_sample = INF


func _record(position: Vector3, forward: Vector3) -> void:
	_points.append(SafePoint.new(position, forward, _time))
	if _points.size() > max_points:
		_points.pop_front()
	_since_sample = 0.0
