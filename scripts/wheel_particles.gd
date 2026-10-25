class_name WheelParticles
extends Node3D




















const MIN_SPEED := 2.0


const MAX_PARTICLES := 24


const LIFETIME := 0.6


const AMOUNT_PER_SPEED := 3.0


const SPREAD_ANGLE := 35.0


const INITIAL_VELOCITY_MIN := 1.0
const INITIAL_VELOCITY_MAX := 3.0


const SCALE_MIN := 0.03
const SCALE_MAX := 0.08


const GRAVITY := Vector3(0.0, -6.0, 0.0)

var _particles: CPUParticles3D = null
var _smoke_particles: CPUParticles3D = null


func _ready() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "GrassParticles"
	_particles.amount = MAX_PARTICLES
	_particles.lifetime = LIFETIME
	_particles.emitting = false
	
	_particles.one_shot = false
	
	_particles.local_coords = false
	_particles.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_configure_emission()
	
	
	_particles.mesh = _create_particle_mesh()
	add_child(_particles)
	_smoke_particles = _create_smoke_particles()
	add_child(_smoke_particles)








func update_particles(wheel_global_pos: Vector3, surface: SurfaceDetector.Surface,
		car_speed: float, burnout: bool = false) -> void:
	
	global_position = wheel_global_pos + Vector3(0, 0.05, 0)

	
	
	var should_emit: bool = false
	_particles.emitting = should_emit
	_smoke_particles.global_position = global_position + Vector3(0.0, 0.18, 0.0)
	_smoke_particles.emitting = burnout

	if should_emit:
		
		var speed_factor := clampf((car_speed - MIN_SPEED) / 15.0, 0.0, 1.0)
		_particles.amount = clampi(int(speed_factor * MAX_PARTICLES), 1, MAX_PARTICLES)
		
		_particles.initial_velocity_min = INITIAL_VELOCITY_MIN + car_speed * 0.15
		_particles.initial_velocity_max = INITIAL_VELOCITY_MAX + car_speed * 0.25
	if burnout:
		_smoke_particles.amount = 12
		_smoke_particles.initial_velocity_min = 0.35
		_smoke_particles.initial_velocity_max = 1.1





func _configure_emission() -> void:
	
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 0.15
	
	_particles.direction = Vector3(0, 1, 0)
	_particles.spread = SPREAD_ANGLE
	_particles.initial_velocity_min = INITIAL_VELOCITY_MIN
	_particles.initial_velocity_max = INITIAL_VELOCITY_MAX
	
	_particles.gravity = GRAVITY
	
	_particles.scale_amount_min = SCALE_MIN
	_particles.scale_amount_max = SCALE_MAX
	
	_particles.color = Color(0.3, 0.6, 0.15, 0.9)  
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.35, 0.65, 0.18, 1.0))  
	gradient.add_point(0.5, Color(0.3, 0.55, 0.15, 0.8))
	gradient.set_color(1, Color(0.25, 0.45, 0.1, 0.0))  
	_particles.color_ramp = gradient
	
	_particles.angular_velocity_min = -180.0
	_particles.angular_velocity_max = 180.0
	
	_particles.damping_min = 2.0
	_particles.damping_max = 5.0


func _create_particle_mesh() -> Mesh:
	
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.04)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.3, 0.6, 0.15)
	leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	leaf_mat.vertex_color_use_as_albedo = true
	
	leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = leaf_mat
	return quad


func _create_smoke_particles() -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.name = "BurnoutSmoke"
	smoke.amount = 24
	smoke.lifetime = 1.1
	smoke.emitting = false
	smoke.one_shot = false
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.12
	smoke.direction = Vector3(0.0, 1.0, 0.0)
	smoke.spread = 45.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.5
	smoke.gravity = Vector3(0.0, -0.25, 0.0)
	smoke.scale_amount_min = 0.28
	smoke.scale_amount_max = 0.65
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.32, 0.33, 0.34, 0.62))
	ramp.add_point(0.45, Color(0.22, 0.23, 0.24, 0.42))
	ramp.set_color(1, Color(0.12, 0.13, 0.14, 0.0))
	smoke.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_color = Color(0.32, 0.33, 0.34, 0.65)
	quad.material = material
	smoke.mesh = quad
	return smoke
