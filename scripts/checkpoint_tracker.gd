class_name CheckpointTracker
extends RefCounted






var radius: float = 12.0


var max_sweep: float = 40.0
var next_index: int = 0

var _gates := PackedVector3Array()
var _last_pos: Vector3
var _has_last: bool = false


func _init(gates: PackedVector3Array = PackedVector3Array(), p_radius: float = 12.0) -> void:
	_gates = gates
	radius = p_radius


func reset() -> void:
	next_index = 0
	_has_last = false



func update(pos: Vector3) -> bool:
	if is_complete():
		return false
	var from := _last_pos if _has_last else pos
	if from.distance_to(pos) > max_sweep:
		from = pos
	_last_pos = pos
	_has_last = true
	var gate := _gates[next_index]
	var closest := Geometry2D.get_closest_point_to_segment(
		Vector2(gate.x, gate.z), Vector2(from.x, from.z), Vector2(pos.x, pos.z))
	if closest.distance_to(Vector2(gate.x, gate.z)) > radius:
		return false
	next_index += 1
	return true


func is_complete() -> bool:
	return next_index >= _gates.size()


func gate_count() -> int:
	return _gates.size()


func next_gate() -> Vector3:
	return _gates[mini(next_index, _gates.size() - 1)]


func distance_to_next(pos: Vector3) -> float:
	var gate := next_gate()
	return Vector2(gate.x, gate.z).distance_to(Vector2(pos.x, pos.z))
