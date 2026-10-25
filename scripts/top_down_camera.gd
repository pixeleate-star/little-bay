class_name TopDownCamera
extends Camera3D




























@export var target_path: NodePath







@export var yaw_degrees: float = 45.0





@export_range(0.0, 90.0, 0.001) var pitch_degrees: float = 35.264











@export var follow_heading: bool = false






@export var heading_lerp: float = 4.0





@export var view_distance: float = 120.0




@export var ortho_size: float = 40.0




@export var follow_lerp: float = 8.0

var _target: Node3D = null





var _yaw_deg: float = 0.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = ortho_size
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	
	
	
	_yaw_deg = yaw_degrees
	
	
	
	if _target != null:
		_snap_to_target()


func _process(delta: float) -> void:
	
	
	
	
	if _target == null or not current:
		return
	
	
	
	
	
	var yaw_t := 1.0 if heading_lerp <= 0.0 else clampf(delta * heading_lerp, 0.0, 1.0)
	
	
	
	_yaw_deg = rad_to_deg(lerp_angle(
		deg_to_rad(_yaw_deg), deg_to_rad(_resolve_target_yaw()), yaw_t))
	var desired := desired_position(
		_target.global_position, _yaw_deg, pitch_degrees, view_distance)
	var t := 1.0 if follow_lerp <= 0.0 else clampf(delta * follow_lerp, 0.0, 1.0)
	global_position = global_position.lerp(desired, t)
	_apply_orientation()




func snap_to_target() -> void:
	if _target == null and not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		_snap_to_target()


func _snap_to_target() -> void:
	_yaw_deg = _resolve_target_yaw()
	global_position = desired_position(
		_target.global_position, _yaw_deg, pitch_degrees, view_distance)
	_apply_orientation()








func _resolve_target_yaw() -> float:
	if not follow_heading or _target == null:
		return yaw_degrees
	
	
	
	return heading_yaw_degrees(_target.global_basis.z, _yaw_deg - yaw_degrees) + yaw_degrees













static func heading_yaw_degrees(forward: Vector3, fallback_deg: float) -> float:
	var flat := Vector2(forward.x, forward.z)
	if flat.length_squared() < 0.000001:
		return fallback_deg
	
	
	
	return rad_to_deg(atan2(-flat.x, -flat.y))

















static func desired_basis(yaw_deg: float, pitch_deg: float) -> Basis:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var sy := sin(yaw)
	var cy := cos(yaw)
	var sp := sin(pitch)
	var cp := cos(pitch)
	var z_axis := Vector3(sy * cp, sp, cy * cp)
	var x_axis := Vector3(cy, 0.0, -sy)
	
	
	
	var y_axis := z_axis.cross(x_axis)
	return Basis(x_axis, y_axis, z_axis)












func _apply_orientation() -> void:
	global_basis = desired_basis(_yaw_deg, pitch_degrees)












static func desired_position(
		target: Vector3, yaw_deg: float, pitch_deg: float,
		distance: float) -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var horizontal := cos(pitch)
	var offset := Vector3(
		sin(yaw) * horizontal,
		sin(pitch),
		cos(yaw) * horizontal) * distance
	return target + offset
