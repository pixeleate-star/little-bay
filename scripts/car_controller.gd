class_name CarController
extends VehicleBody3D




signal speed_changed(speed_kmh: float)



signal gear_changed(gear: int)



signal kudos_changed(total: int, combo: float)




signal kudos_event(label: String, amount: int, is_penalty: bool)





signal gear_ratio_changed(ratio: float)




signal assists_changed(tcs: float, abs_level: float, stability: float)

@export var max_speed: float = 55.0
@export var reverse_max_speed: float = 18.0
@export var engine_force_value: float = 3200.0
@export var reverse_engine_force: float = 1600.0
@export var brake_force_value: float = 65.0
@export var idle_brake_force: float = 8.0
@export var max_steer_angle: float = 0.32
@export var min_steer_angle: float = 0.05





@export var steering_rate: float = 2.2


@export var steering_return_rate: float = 4.0

@export var countersteer_assist: float = 0.16




@export var traction_control_enabled: bool = true
@export var abs_enabled: bool = true
@export var stability_control_enabled: bool = true



@export var handbrake_force_value: float = 200.0


@export var handbrake_rear_friction: float = 0.6


@export var burnout_rear_friction: float = 0.22


@export var anti_roll_strength: float = 9000.0

@export var anti_roll_deadzone: float = 0.12





@export var paint_color: Color = CarPaint.DEFAULT_PAINT_COLOR


@export var apply_car_paint: bool = true



@export_file("*.blend", "*.glb", "*.gltf") var custom_model_path: String = "res://assets/vehicles/pickup-truck.blend"
@export var custom_model_scale: float = 0.85

@onready var front_left_wheel: VehicleWheel3D = $FrontLeftWheel
@onready var front_right_wheel: VehicleWheel3D = $FrontRightWheel
@onready var rear_left_wheel: VehicleWheel3D = $RearLeftWheel
@onready var rear_right_wheel: VehicleWheel3D = $RearRightWheel

@onready var camera_pivot: Node3D = $CameraPivot



@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var car_mesh: Node3D = $CarMesh
@onready var front_left_wheel_mesh: Node3D = $CarMesh/Wheel_Front_Right
@onready var front_right_wheel_mesh: Node3D = $CarMesh/Wheel_Front_Left
@onready var rear_left_wheel_mesh: Node3D = $CarMesh/Wheel_Rear_Right
@onready var rear_right_wheel_mesh: Node3D = $CarMesh/Wheel_Rear_Left

var _wheel_mesh_rotations: Dictionary[StringName, Basis] = {}



var _rear_grip_normal: float = 2.0

var _rear_grip_lowered: bool = false




var _steering := SteeringModel.new()



var _assists := DrivingAssists.new()




var _transmission := Transmission.new()

var _current_gear: int = Transmission.GEAR_NEUTRAL


var _engine_sound := EngineSound.new()
var _audio_muted: bool = false
var _burnout_active: bool = false
var _burnout_time: float = 0.0


var _surface_detector := SurfaceDetector.new()

var _wheel_particles: Array[WheelParticles] = []


var _wheel_surfaces: Array[SurfaceDetector.Surface] = []


var _surface_tick: int = 0
const _SURFACE_CHECK_INTERVAL := 3




var _camera_shake := CameraShake.new()



var _camera_rest_transform := Transform3D.IDENTITY


var _camera_rest_fov: float = 70.0



const _CRASH_TRAUMA_PER_KMH := 0.012


const _CRASH_TRAUMA_MIN := 0.25

const _LANDING_TRAUMA_PER_MS := 0.06

const _LANDING_SOFT_THRESHOLD := 4.0



const _FOV_KICK_FULL_SPEED_KMH := 120.0


const _FOV_KICK_MAX_DEGREES := 12.0


const _FOV_KICK_LERP := 4.0



var _was_airborne: bool = false





var _braking_this_frame: bool = false




var _audio_triggers := CarAudioTriggers.new()


var _screech_sound: AudioStreamPlayer = null


var _impact_sound: AudioStreamPlayer = null




const _SCREECH_SOUND_PATH := "res://sounds/tire_screech.wav"
const _IMPACT_SOUND_PATH := "res://sounds/impact.wav"



const _SCREECH_VOLUME_MIN_DB := -14.0
const _SCREECH_VOLUME_MAX_DB := -3.0


const _SCREECH_AUDIBLE_LEVEL := 0.02

const _SCREECH_SILENT_DB := -60.0

const _IMPACT_VOLUME_MIN_DB := -16.0
const _IMPACT_VOLUME_MAX_DB := 0.0


const _CRASH_EVENT_LABEL := "CRASH"



var _impact_particles: ImpactParticles = null





var _kudos := KudosTracker.new()


var _last_kudos_total: int = -1


const _NEAR_MISS_PROBE_BASE := 6.0




var input_locked: bool = false



const RecoveryTrackerScript := preload("res://scripts/recovery_tracker.gd")
var _recovery := RecoveryTrackerScript.new()



const _SAFE_UPRIGHTNESS := 0.9
const _SAFE_MIN_SPEED := 2.0


const _RECOVERY_LIFT := 0.6





func set_driving_assists_enabled(enabled: bool) -> void:
	_assists.set_all_enabled(enabled)
	_steering.countersteer_max = countersteer_assist if enabled else 0.0




func are_driving_assists_enabled() -> bool:
	return _assists.traction_control_enabled



func set_engine_muted(muted: bool) -> void:
	_audio_muted = muted
	_engine_sound.set_muted(muted)
	if muted and _screech_sound != null:
		_screech_sound.stop()
		
	if muted and _impact_sound != null:
		_impact_sound.stop()





func recover() -> void:
	var point := _recovery.take_recovery_point()
	if point == null:
		teleport(global_position + Vector3.UP * _RECOVERY_LIFT, global_transform.basis.z)
	else:
		teleport(point.position + Vector3.UP * _RECOVERY_LIFT, point.forward)




func remember_safe_point() -> void:
	_recovery.remember(global_position, global_transform.basis.z)






func teleport(at: Vector3, forward: Vector3) -> void:
	var flat := Vector3(forward.x, 0.0, forward.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.BACK
	
	var heading := Basis(Vector3.UP.cross(flat), Vector3.UP, flat)
	global_transform = Transform3D(heading, at)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_kudos.forget_motion()
	_steering.reset()
	_was_airborne = false
	_camera_shake.trauma = 0.0
	if camera_pivot != null:
		camera_pivot.global_basis = Basis.looking_at(flat, Vector3.UP)



func reset_kudos() -> void:
	_kudos.reset()
	_last_kudos_total = -1


func get_kudos() -> int:
	return _kudos.get_kudos()


func _ready() -> void:
	
	process_mode = Node.PROCESS_MODE_PAUSABLE
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	
	
	center_of_mass = Vector3(0.0, -0.1, 0.0)
	
	
	
	car_mesh.scale = Vector3(0.92, 0.92, 0.92)
	
	
	inertia = Vector3(2200.0, 1400.0, 900.0)
	_cache_wheel_mesh_rotations()
	_try_attach_custom_model()
	_apply_car_paint()
	_setup_wheels()
	_setup_steering_and_assists()
	
	
	_transmission.build_for_max_speed(max_speed * 3.6)
	_setup_wheel_particles()
	_setup_impact_sounds()
	_impact_particles = ImpactParticles.new()
	_impact_particles.name = "ImpactParticles"
	add_child(_impact_particles)
	add_child(_engine_sound)
	
	if camera != null:
		_camera_rest_transform = camera.transform
		_camera_rest_fov = camera.fov


func _cache_wheel_mesh_rotations() -> void:
	
	
	
	
	_wheel_mesh_rotations[front_left_wheel_mesh.name] = front_left_wheel_mesh.global_basis
	_wheel_mesh_rotations[front_right_wheel_mesh.name] = front_right_wheel_mesh.global_basis
	_wheel_mesh_rotations[rear_left_wheel_mesh.name] = rear_left_wheel_mesh.global_basis
	_wheel_mesh_rotations[rear_right_wheel_mesh.name] = rear_right_wheel_mesh.global_basis







func _apply_car_paint() -> void:
	if not apply_car_paint or car_mesh == null:
		return
	var painter := CarPaint.new()
	painter.apply_to(car_mesh, paint_color)


func _try_attach_custom_model() -> void:
	if car_mesh == null or custom_model_path.is_empty():
		return
	if not ResourceLoader.exists(custom_model_path, "PackedScene"):
		push_warning("CarController: custom vehicle is not imported yet: %s" % custom_model_path)
		return
	var packed := ResourceLoader.load(custom_model_path, "PackedScene") as PackedScene
	if packed == null:
		push_warning("CarController: could not load custom vehicle: %s" % custom_model_path)
		return
	var custom := packed.instantiate() as Node3D
	if custom == null:
		push_warning("CarController: custom vehicle has no Node3D root: %s" % custom_model_path)
		return
	custom.name = "PickupTruckImported"
	
	
	
	
	custom.rotation_degrees = Vector3.ZERO
	custom.scale = Vector3.ONE * custom_model_scale
	car_mesh.add_child(custom)
	
	
	for child in car_mesh.get_children():
		if child != custom and child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func _setup_wheels() -> void:
	for wheel in [front_left_wheel, front_right_wheel, rear_left_wheel, rear_right_wheel]:
		wheel.wheel_radius = 0.315
		wheel.wheel_rest_length = 0.2
		wheel.suspension_travel = 0.2
		wheel.suspension_stiffness = 30.0
		wheel.damping_compression = 2.5
		wheel.damping_relaxation = 3.5
		wheel.wheel_friction_slip = 2.0
		wheel.suspension_max_force = 12000.0
		
		
		wheel.wheel_roll_influence = 0.02

	front_left_wheel.use_as_steering = true
	front_right_wheel.use_as_steering = true
	front_left_wheel.use_as_traction = false
	front_right_wheel.use_as_traction = false

	rear_left_wheel.use_as_steering = false
	rear_right_wheel.use_as_steering = false
	rear_left_wheel.use_as_traction = true
	rear_right_wheel.use_as_traction = true

	
	_rear_grip_normal = rear_left_wheel.wheel_friction_slip





func _setup_steering_and_assists() -> void:
	_steering.max_steer_angle = max_steer_angle
	_steering.min_steer_angle = min_steer_angle
	_steering.steer_rate = steering_rate
	_steering.return_rate = steering_return_rate
	_steering.countersteer_max = countersteer_assist
	
	
	
	_steering.speed_sensitivity_full = max_speed * 0.85

	_assists.traction_control_enabled = traction_control_enabled
	_assists.abs_enabled = abs_enabled
	_assists.stability_control_enabled = stability_control_enabled


func _setup_wheel_particles() -> void:
	_surface_detector.init(get_tree())
	
	
	for wheel: VehicleWheel3D in [front_left_wheel, front_right_wheel,
			rear_left_wheel, rear_right_wheel]:
		var wp := WheelParticles.new()
		wp.name = "Particles_%s" % wheel.name
		add_child(wp)
		_wheel_particles.append(wp)
		_wheel_surfaces.append(SurfaceDetector.Surface.GRASS)






func _setup_impact_sounds() -> void:
	_screech_sound = AudioStreamPlayer.new()
	_screech_sound.name = "TireScreechSound"
	_screech_sound.bus = &"Master"
	_screech_sound.volume_db = _SCREECH_VOLUME_MIN_DB
	_screech_sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	var screech := load(_SCREECH_SOUND_PATH) if ResourceLoader.exists(_SCREECH_SOUND_PATH) else null
	if screech is AudioStreamWAV:
		screech.loop_mode = AudioStreamWAV.LOOP_FORWARD
		
		
		
		screech.loop_begin = 0
		var total_frames: int = _wav_frame_count(screech)
		var tail_trim: int = int(screech.mix_rate * 0.12)
		screech.loop_end = maxi(1, total_frames - tail_trim)
		_screech_sound.stream = screech
	elif screech is AudioStream:
		_screech_sound.stream = screech
	else:
		push_warning("CarController: tyre-screech sound absent at %s (silent)" % _SCREECH_SOUND_PATH)
	add_child(_screech_sound)

	_impact_sound = AudioStreamPlayer.new()
	_impact_sound.name = "ImpactSound"
	_impact_sound.bus = &"Master"
	_impact_sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	var impact := load(_IMPACT_SOUND_PATH) if ResourceLoader.exists(_IMPACT_SOUND_PATH) else null
	if impact is AudioStream:
		_impact_sound.stream = impact
	else:
		push_warning("CarController: impact sound absent at %s (silent)" % _IMPACT_SOUND_PATH)
	add_child(_impact_sound)





func _wav_frame_count(wav: AudioStreamWAV) -> int:
	var bytes := wav.data.size()
	
	var channels := 2 if wav.stereo else 1
	var bytes_per_frame := 2 * channels
	if wav.format != AudioStreamWAV.FORMAT_16_BITS or bytes_per_frame == 0:
		return 0
	
	@warning_ignore("integer_division")
	return bytes / bytes_per_frame





func _play_impact(severity: float) -> void:
	if _audio_muted:
		return
	var decision := _audio_triggers.register_impact(severity)
	if not decision["play"]:
		return
	if _impact_sound == null or _impact_sound.stream == null:
		return
	var vol: float = decision["volume"]
	_impact_sound.volume_db = lerpf(_IMPACT_VOLUME_MIN_DB, _IMPACT_VOLUME_MAX_DB, vol)
	_impact_sound.play()






func _burst_impact_particles(severity: float) -> void:
	if _impact_particles == null:
		return
	
	
	
	var nose := global_transform.basis.z.normalized()
	var origin := global_position + nose * 2.0 + Vector3(0.0, 0.4, 0.0)
	
	
	var dir := (Vector3.UP * 1.5 - nose).normalized()
	_impact_particles.burst(origin, severity, dir)











func _update_screech_sound() -> void:
	if _audio_muted:
		return
	if _screech_sound == null or _screech_sound.stream == null:
		return
	if _burnout_active:
		_screech_sound.volume_db = _SCREECH_VOLUME_MAX_DB
		_screech_sound.pitch_scale = 1.05
		if not _screech_sound.playing:
			_screech_sound.play()
		return
	var level := _audio_triggers.screech_level
	if level >= _SCREECH_AUDIBLE_LEVEL:
		_screech_sound.volume_db = lerpf(_SCREECH_VOLUME_MIN_DB, _SCREECH_VOLUME_MAX_DB, level)
		
		_screech_sound.pitch_scale = lerpf(0.9, 1.15, level)
		if not _screech_sound.playing:
			_screech_sound.play()
	elif _screech_sound.playing:
		
		
		
		
		_screech_sound.volume_db = _SCREECH_SILENT_DB
		if level <= 0.0:
			_screech_sound.stop()


func _set_rear_friction(lowered: bool) -> void:
	if lowered == _rear_grip_lowered:
		return
	_rear_grip_lowered = lowered
	var grip := handbrake_rear_friction if lowered else _rear_grip_normal
	rear_left_wheel.wheel_friction_slip = grip
	rear_right_wheel.wheel_friction_slip = grip

func _physics_process(_delta: float) -> void:
	var forward_input := Input.get_action_strength("move_forward")
	var reverse_input := Input.get_action_strength("move_backward")
	var steer_input := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	var handbrake_input := Input.get_action_strength("handbrake")
	if input_locked:
		forward_input = 0.0
		reverse_input = 0.0
		steer_input = 0.0
		handbrake_input = 0.0
	var handbrake_active := handbrake_input > 0.0
	var forward_speed := linear_velocity.dot(global_transform.basis.z)
	
	
	
	var burnout_active := handbrake_active and forward_input > 0.1 and forward_speed < 8.0
	_burnout_active = burnout_active
	_burnout_time = _burnout_time + _delta if burnout_active else 0.0

	var drive_force := 0.0
	var brake_force := idle_brake_force
	if forward_input > 0.0 and forward_speed < max_speed:
		drive_force = engine_force_value * forward_input
		brake_force = 0.0
	elif reverse_input > 0.0:
		if forward_speed > 1.0:
			brake_force = brake_force_value * reverse_input
		elif forward_speed > -reverse_max_speed:
			drive_force = -reverse_engine_force * reverse_input
			brake_force = 0.0

	if forward_speed > max_speed and drive_force > 0.0:
		drive_force = 0.0
	if input_locked:
		brake_force = brake_force_value

	
	
	
	
	var rear_brake := brake_force
	if handbrake_active:
		if burnout_active:
			
			
			drive_force = engine_force_value * forward_input * 1.8
			rear_brake = 0.0
		else:
			drive_force = 0.0
			rear_brake = handbrake_force_value * handbrake_input
	_set_rear_friction(handbrake_active)
	if burnout_active:
		rear_left_wheel.wheel_friction_slip = burnout_rear_friction
		rear_right_wheel.wheel_friction_slip = burnout_rear_friction
		
		
		var planted_velocity := linear_velocity
		planted_velocity.x = move_toward(planted_velocity.x, 0.0, 1.8)
		planted_velocity.z = move_toward(planted_velocity.z, 0.0, 1.8)
		linear_velocity = planted_velocity
	elif handbrake_active:
		rear_left_wheel.wheel_friction_slip = handbrake_rear_friction
		rear_right_wheel.wheel_friction_slip = handbrake_rear_friction

	
	
	
	_braking_this_frame = handbrake_active or brake_force > idle_brake_force

	
	
	var speed_now := linear_velocity.length()
	var slip := _compute_slip_angle()
	var steer_angle := _steering.update(
		steer_input, speed_now, slip, _slip_direction(), _delta
	)
	front_left_wheel.steering = steer_angle
	front_right_wheel.steering = steer_angle

	
	
	
	
	
	
	
	
	var rear_wheel_speed := _driven_wheel_surface_speed()
	var assisted_drive_force := _assists.filter_engine_force(
		drive_force, rear_wheel_speed, forward_speed, _delta
	)
	
	
	if not burnout_active:
		drive_force = assisted_drive_force
	var filtered_brake := _assists.filter_brake_force(
		rear_brake, rear_wheel_speed, forward_speed, _delta
	)
	
	
	
	var abs_rear_brake := rear_brake if handbrake_active else filtered_brake

	rear_left_wheel.engine_force = drive_force
	rear_right_wheel.engine_force = drive_force
	rear_left_wheel.brake = abs_rear_brake
	rear_right_wheel.brake = abs_rear_brake
	front_left_wheel.brake = brake_force * 0.35
	front_right_wheel.brake = brake_force * 0.35
	_apply_stability_control(steer_angle, speed_now, forward_speed, handbrake_active)
	_broadcast_assist_levels()
	_apply_anti_roll(_delta)
	_sync_wheel_meshes()
	_update_camera_pivot(_delta)

	_update_wheel_particles()
	_broadcast_speed()
	_update_gear(0.0 if _burnout_active else forward_speed)
	_update_kudos(_delta, forward_speed)
	
	
	_update_camera_effects(_delta)













func _slip_direction() -> float:
	var vel := linear_velocity
	vel.y = 0.0
	if vel.length() < 1.0:
		return 0.0
	var forward := global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0.0
	forward = forward.normalized()
	
	if vel.normalized().dot(forward) < 0.0:
		return 0.0
	
	
	var lateral := forward.cross(vel.normalized()).y
	if is_zero_approx(lateral):
		return 0.0
	return signf(lateral)









func _driven_wheel_surface_speed() -> float:
	var rpm := (rear_left_wheel.get_rpm() + rear_right_wheel.get_rpm()) * 0.5
	
	
	if not is_finite(rpm):
		return 0.0
	
	return rpm * (TAU / 60.0) * rear_left_wheel.wheel_radius








func _apply_stability_control(
	steer_angle: float,
	speed: float,
	forward_speed: float,
	handbrake_active: bool
) -> void:
	var yaw_rate := angular_velocity.dot(global_transform.basis.y)
	var desired := _desired_yaw_rate(steer_angle, forward_speed)
	var torque := _assists.stability_torque(yaw_rate, desired, speed, handbrake_active)
	if is_zero_approx(torque):
		return
	
	apply_torque(global_transform.basis.y * torque)








func _desired_yaw_rate(steer_angle: float, forward_speed: float) -> float:
	var wheelbase := _wheelbase()
	if wheelbase <= 0.0:
		return 0.0
	return forward_speed * tan(steer_angle) / wheelbase




func _wheelbase() -> float:
	return absf(front_left_wheel.position.z - rear_left_wheel.position.z)


func _apply_anti_roll(_delta: float) -> void:
	
	
	
	if anti_roll_strength <= 0.0:
		return
	
	
	var roll_amount := global_transform.basis.x.dot(Vector3.UP)
	if absf(roll_amount) <= anti_roll_deadzone:
		return
	var correction: float = (absf(roll_amount) - anti_roll_deadzone) * signf(roll_amount)
	
	var roll_rate := angular_velocity.dot(global_transform.basis.z)
	var torque := global_transform.basis.z * (-correction * anti_roll_strength - roll_rate * anti_roll_strength * 0.15)
	apply_torque(torque)


func _update_wheel_particles() -> void:
	var car_speed := linear_velocity.length()
	var wheels: Array[VehicleWheel3D] = [
		front_left_wheel, front_right_wheel,
		rear_left_wheel, rear_right_wheel,
	]
	
	
	
	var do_detect := _surface_tick % _SURFACE_CHECK_INTERVAL == 0
	_surface_tick += 1
	for i: int in range(wheels.size()):
		var wheel := wheels[i]
		
		var wheel_global := global_transform * wheel.transform
		var contact_pos := wheel_global.origin - Vector3(0, wheel.wheel_radius, 0)
		if do_detect:
			_wheel_surfaces[i] = _surface_detector.detect(contact_pos)
		_wheel_particles[i].update_particles(contact_pos, _wheel_surfaces[i], car_speed, _burnout_active and i >= 2)
func _sync_wheel_meshes() -> void:
	_sync_wheel_mesh(front_left_wheel, front_left_wheel_mesh)
	_sync_wheel_mesh(front_right_wheel, front_right_wheel_mesh)
	_sync_wheel_mesh(rear_left_wheel, rear_left_wheel_mesh)
	_sync_wheel_mesh(rear_right_wheel, rear_right_wheel_mesh)


func _sync_wheel_mesh(wheel: VehicleWheel3D, wheel_mesh: Node3D) -> void:
	
	
	
	
	var wheel_global := global_transform * wheel.transform
	
	
	var spin: Basis = _wheel_mesh_rotations.get(wheel_mesh.name, Basis.IDENTITY)
	wheel_mesh.global_position = wheel_global.origin
	wheel_mesh.global_basis = wheel_global.basis.orthonormalized() * spin


func _update_camera_pivot(delta: float) -> void:
	var flat_forward := Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z)
	if flat_forward.length_squared() < 0.001:
		return

	flat_forward = flat_forward.normalized()
	var target_basis := Basis.looking_at(flat_forward, Vector3.UP)
	camera_pivot.global_basis = camera_pivot.global_basis.slerp(target_basis, clamp(delta * 6.0, 0.0, 1.0))





func _update_camera_effects(delta: float) -> void:
	if camera == null:
		return
	
	
	_camera_shake.tick(delta)
	var shaken := _camera_rest_transform
	if _camera_shake.is_active():
		var off := _camera_shake.get_offset()
		var pos_off := off["position"] as Vector3
		var rot_off := off["rotation"] as Vector3
		shaken.origin += pos_off
		shaken.basis = shaken.basis * Basis.from_euler(rot_off)
	camera.transform = shaken

	
	
	
	var speed_kmh := linear_velocity.length() * 3.6
	var kick := clampf(speed_kmh / _FOV_KICK_FULL_SPEED_KMH, 0.0, 1.0) * _FOV_KICK_MAX_DEGREES
	var target_fov := _camera_rest_fov + kick
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * _FOV_KICK_LERP, 0.0, 1.0))


func _broadcast_speed() -> void:
	var speed_kmh: float = linear_velocity.length() * 3.6
	speed_changed.emit(speed_kmh)






func _broadcast_assist_levels() -> void:
	var stability := 0.0
	if _assists.stability_max_torque > 0.0:
		stability = clampf(
			_assists.stability_intervention / _assists.stability_max_torque, 0.0, 1.0
		)
	assists_changed.emit(_assists.tcs_cut, _assists.abs_release, stability)






func _update_gear(forward_speed: float) -> void:
	var speed_kmh := forward_speed * 3.6
	var max_kmh := max_speed * 3.6
	var gear := Transmission.GEAR_NEUTRAL if _burnout_active else _transmission.gear_for_speed(speed_kmh, max_kmh)
	if gear != _current_gear:
		_current_gear = gear
		gear_changed.emit(gear)
	var gear_ratio := 1.0 if _burnout_active else _transmission.gear_ratio_for_speed(speed_kmh, max_kmh)
	if _burnout_active:
		
		
		var rpm_ratio := clampf(_burnout_time / 0.8, 0.0, 1.0)
		_engine_sound.update_engine(180.0, 1, rpm_ratio)
	else:
		_engine_sound.update_engine(absf(speed_kmh), gear, gear_ratio)
	if _burnout_active:
		var needle_ratio := lerpf(0.12, 0.96, clampf(_burnout_time / 0.8, 0.0, 1.0))
		needle_ratio += sin(_burnout_time * 18.0) * 0.035
		gear_ratio = clampf(needle_ratio, 0.0, 1.0)
	
	
	gear_ratio_changed.emit(gear_ratio)





func _update_kudos(delta: float, forward_speed: float) -> void:
	var t := KudosTracker.Telemetry.new()
	t.forward_speed = forward_speed
	t.speed = linear_velocity.length()
	t.slip_angle = _compute_slip_angle()
	
	t.yaw_rate = angular_velocity.dot(global_transform.basis.y)
	
	t.uprightness = global_transform.basis.y.dot(Vector3.UP)
	t.wheels_on_ground = _count_wheels_on_ground()
	t.on_road = _majority_on_road()
	t.nearest_obstacle_dist = _nearest_obstacle_distance(t.speed)
	t.braking = _braking_this_frame

	
	
	
	var airborne_now := t.wheels_on_ground == 0
	if _was_airborne and not airborne_now:
		var down_speed := maxf(0.0, -linear_velocity.y)
		if down_speed > _LANDING_SOFT_THRESHOLD:
			_camera_shake.add_trauma((down_speed - _LANDING_SOFT_THRESHOLD) * _LANDING_TRAUMA_PER_MS)
	_was_airborne = airborne_now

	
	
	
	var gripping := not _rear_grip_lowered
	var screech_speed := 0.0 if airborne_now else t.speed
	_audio_triggers.update_screech(t.slip_angle, screech_speed, gripping, delta)
	_update_screech_sound()

	var safe := t.wheels_on_ground == 4 and t.on_road \
			and t.uprightness > _SAFE_UPRIGHTNESS and t.speed > _SAFE_MIN_SPEED
	_recovery.update(delta, global_position, global_transform.basis.z, safe)

	var events := _kudos.update(t, delta)
	for ev: KudosTracker.KudosEvent in events:
		kudos_event.emit(ev.label, ev.amount, ev.is_penalty)
		if not ev.is_penalty:
			continue
		var severity := float(absi(ev.amount))
		
		
		_camera_shake.add_trauma(maxf(_CRASH_TRAUMA_MIN, severity * _CRASH_TRAUMA_PER_KMH))
		
		
		
		
		if ev.label == _CRASH_EVENT_LABEL:
			_play_impact(severity)
			_burst_impact_particles(severity)

	var total := _kudos.get_kudos()
	if total != _last_kudos_total:
		_last_kudos_total = total
		kudos_changed.emit(total, _kudos.get_combo())





func _compute_slip_angle() -> float:
	var vel := linear_velocity
	vel.y = 0.0
	if vel.length() < 1.0:
		return 0.0
	
	
	var forward := global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0.0
	return absf(vel.normalized().angle_to(forward.normalized()))



func _count_wheels_on_ground() -> int:
	var count := 0
	for wheel: VehicleWheel3D in [front_left_wheel, front_right_wheel,
			rear_left_wheel, rear_right_wheel]:
		if wheel.is_in_contact():
			count += 1
	return count





func _majority_on_road() -> bool:
	if _wheel_surfaces.is_empty():
		return true
	var on_road := 0
	for s: SurfaceDetector.Surface in _wheel_surfaces:
		if s == SurfaceDetector.Surface.ROAD:
			on_road += 1
	return on_road >= 3






func _nearest_obstacle_distance(speed: float) -> float:
	const NO_HIT := 999.0
	if speed < 5.0:
		return NO_HIT
	var space := get_world_3d().direct_space_state
	
	
	var reach: float = _NEAR_MISS_PROBE_BASE + clampf(speed * 0.1, 0.0, 4.0)
	var origin := global_position + Vector3(0.0, 0.4, 0.0)
	var right := global_transform.basis.x.normalized()
	var nearest := NO_HIT
	for dir: Vector3 in [right, -right]:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
		query.exclude = [get_rid()]
		
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var d: float = origin.distance_to(hit.position)
			nearest = minf(nearest, d)
	return nearest
