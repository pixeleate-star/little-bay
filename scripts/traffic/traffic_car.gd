class_name TrafficCar
extends RigidBody3D























var cruise_speed: float = 8.0









var _lane_offset: float = 0.0



var _path: PackedVector3Array = PackedVector3Array()

var _distance: float = 0.0

var _path_length: float = 0.0






var _way_id: int = -1
var _reversed: bool = false



var _overshoot: float = 0.0


var _detailed: bool = false


const _RIDE_HEIGHT := 0.5



const _MAX_GRADE := 0.84




const _STEER_LERP := 6.0
const _SPEED_LERP := 4.0



const _LOOK_AHEAD := 6.0



const _END_TOLERANCE := 1.5


func _ready() -> void:
	
	
	
	
	
	axis_lock_angular_z = true
	
	freeze = true
	
	
	
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_randomize_car_look()







func _randomize_car_look() -> void:
	var visual := get_node_or_null("CarVisual")
	if visual == null:
		return
	var mat := StandardMaterial3D.new()
	var paints := [Color("d93b45"), Color("2c78c9"), Color("f0b429"), Color("e7e9ed"), Color("222831"), Color("38a169"), Color("a855f7")]
	mat.albedo_color = paints[randi() % paints.size()]
	mat.metallic = 0.1
	mat.roughness = 0.6
	for mesh: Node in visual.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = mat
	visual.scale *= randf_range(0.86, 1.02)






func set_route(path: PackedVector3Array, start_distance: float, way_id: int = -1, reversed: bool = false, lane_offset: float = 0.0) -> void:
	_path = path
	_path_length = _polyline_length(path)
	_distance = clampf(start_distance, 0.0, _path_length)
	_way_id = way_id
	_reversed = reversed
	_lane_offset = lane_offset
	_overshoot = 0.0
	_snap_to_path()















func continue_route(path: PackedVector3Array, start_distance: float, way_id: int, reversed: bool, lane_offset: float = 0.0) -> void:
	_path = path
	_path_length = _polyline_length(path)
	_distance = clampf(start_distance, 0.0, _path_length)
	_way_id = way_id
	_reversed = reversed
	_lane_offset = lane_offset
	_overshoot = 0.0
	_snap_to_path()
	
	
	if _detailed:
		var speed := linear_velocity.length()
		if speed > 0.01:
			var ahead := _point_at_distance(minf(_distance + 1.0, _path_length))
			var here := global_position
			var dir := ahead - here
			dir.y = 0.0
			if dir.length_squared() > 0.0001:
				var v := dir.normalized() * speed
				v.y = linear_velocity.y
				linear_velocity = v



func path_length() -> float:
	return _path_length



func distance_along() -> float:
	return _distance





func current_way_id() -> int:
	return _way_id



func is_reversed() -> bool:
	return _reversed




func overshoot() -> float:
	return _overshoot







func is_finished() -> bool:
	return _path_length <= 0.0 or _distance >= _path_length - _END_TOLERANCE




func set_detailed(detailed: bool) -> void:
	if detailed == _detailed:
		return
	_detailed = detailed
	freeze = not detailed
	
	
	
	
	can_sleep = not detailed
	if detailed:
		sleeping = false


func is_detailed() -> bool:
	return _detailed


func _physics_process(delta: float) -> void:
	if _path_length <= 0.0:
		return
	if _detailed:
		_drive_detailed(delta)
	else:
		_drive_cheap(delta)









func _drive_detailed(delta: float) -> void:
	
	
	
	
	_distance = _closest_distance(global_position)
	if _distance >= _path_length - _END_TOLERANCE:
		
		
		
		
		_overshoot = 0.0
		return

	
	
	
	
	var look := minf(_distance + _LOOK_AHEAD, _path_length - _END_TOLERANCE * 0.5)
	
	
	
	
	var target := _lane_point_at_distance(look)
	var here := global_position
	var to_target := target - here
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return
	var steer := to_target.normalized()

	
	
	
	var desired_vel := steer * cruise_speed
	desired_vel.y = linear_velocity.y  
	linear_velocity = linear_velocity.lerp(desired_vel, clampf(delta * _SPEED_LERP, 0.0, 1.0))
	_face_direction(steer, delta)





func _drive_cheap(delta: float) -> void:
	_advance(cruise_speed * delta)
	_snap_to_path()






func _advance(step: float) -> void:
	if _path_length <= 0.0:
		return
	var new_dist := _distance + step
	if new_dist >= _path_length:
		_overshoot = new_dist - _path_length
		_distance = _path_length
	else:
		_distance = new_dist




func _snap_to_path() -> void:
	if _path_length <= 0.0:
		return
	var pos := _lane_point_at_distance(_distance)
	
	
	
	
	var ahead := _lane_point_at_distance(minf(_distance + 1.0, _path_length))
	var dir := ahead - pos
	pos.y += _RIDE_HEIGHT
	global_position = pos
	var target: Variant = _slope_basis(dir)
	if target != null:
		global_transform.basis = target




func _face_direction(dir: Vector3, delta: float) -> void:
	var target_basis: Variant = _slope_basis(dir)
	if target_basis == null:
		return
	
	
	
	var b := global_transform.basis.orthonormalized().slerp(
		target_basis as Basis, clampf(delta * _STEER_LERP, 0.0, 1.0))
	global_transform.basis = b













func _slope_basis(dir: Vector3) -> Variant:
	
	
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return null
	flat = flat.normalized()
	
	
	var run := Vector2(dir.x, dir.z).length()
	var slope := 0.0
	if run > 0.0001:
		slope = clampf(dir.y / run, -_MAX_GRADE, _MAX_GRADE)
	
	var forward := (flat + Vector3.UP * slope).normalized()
	
	
	
	
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	
	
	
	return Basis(right, up, -forward).orthonormalized()








func _closest_distance(world_pos: Vector3) -> float:
	if _path.size() < 2:
		return 0.0
	var p := Vector2(world_pos.x, world_pos.z)
	var best_dist := 0.0
	var best_d2 := INF
	var travelled := 0.0
	for i: int in range(_path.size() - 1):
		var a := Vector2(_path[i].x, _path[i].z)
		var b := Vector2(_path[i + 1].x, _path[i + 1].z)
		var ab := b - a
		var seg_len := ab.length()
		if seg_len > 0.0001:
			
			var t := clampf((p - a).dot(ab) / (seg_len * seg_len), 0.0, 1.0)
			var proj := a + ab * t
			var d2 := p.distance_squared_to(proj)
			if d2 < best_d2:
				best_d2 = d2
				best_dist = travelled + t * seg_len
		travelled += seg_len
	return best_dist










func _point_at_distance(dist: float) -> Vector3:
	if _path.size() == 0:
		return global_position
	if _path.size() == 1 or dist <= 0.0:
		return _path[0]
	var remaining := dist
	for i: int in range(_path.size() - 1):
		var seg := _xz_distance(_path[i], _path[i + 1])
		if remaining <= seg or i == _path.size() - 2:
			if seg <= 0.0001:
				return _path[i + 1]
			var t := clampf(remaining / seg, 0.0, 1.0)
			return _path[i].lerp(_path[i + 1], t)
		remaining -= seg
	return _path[_path.size() - 1]








func _lane_point_at_distance(dist: float) -> Vector3:
	var pos := _point_at_distance(dist)
	if absf(_lane_offset) < 0.0001 or _path_length <= 0.0:
		return pos
	
	
	
	
	var ahead := _point_at_distance(minf(dist + 1.0, _path_length))
	var tangent := Vector2(ahead.x - pos.x, ahead.z - pos.z)
	if tangent.length_squared() < 0.0001:
		var behind := _point_at_distance(maxf(dist - 1.0, 0.0))
		tangent = Vector2(pos.x - behind.x, pos.z - behind.z)
	if tangent.length_squared() < 0.0001:
		return pos
	
	
	
	var forward := Vector3(tangent.x, 0.0, tangent.y)
	var right := forward.cross(Vector3.UP).normalized()
	return pos + right * _lane_offset





static func _xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


static func _polyline_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i: int in range(points.size() - 1):
		total += _xz_distance(points[i], points[i + 1])
	return total
