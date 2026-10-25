class_name ImpactParticles
extends Node3D

















const LIFETIME := 0.5



const CAPACITY := 48


const SPARK_SIZE := Vector2(0.06, 0.06)


const GRAVITY := Vector3(0.0, -14.0, 0.0)



const SPREAD_DEGREES := 80.0

var _spec := ImpactBurstSpec.new()
var _particles: CPUParticles3D = null


func _ready() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "ImpactSparks"
	_particles.amount = CAPACITY
	_particles.lifetime = LIFETIME
	_particles.one_shot = true
	_particles.emitting = false
	
	_particles.local_coords = false
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 0.1
	
	_particles.direction = Vector3(0, 1, 0)
	_particles.spread = SPREAD_DEGREES
	_particles.initial_velocity_min = 3.0
	_particles.initial_velocity_max = 8.0
	_particles.gravity = GRAVITY
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.4
	
	_particles.angular_velocity_min = -720.0
	_particles.angular_velocity_max = 720.0
	_particles.damping_min = 1.0
	_particles.damping_max = 4.0
	
	_particles.color = Color(1.0, 0.75, 0.25, 1.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))    
	ramp.add_point(0.4, Color(1.0, 0.55, 0.15, 1.0)) 
	ramp.set_color(1, Color(0.4, 0.15, 0.05, 0.0))   
	_particles.color_ramp = ramp

	_particles.mesh = _create_particle_mesh()

	
	if _spec.max_count > CAPACITY:
		_spec.max_count = CAPACITY
	add_child(_particles)





func burst(world_pos: Vector3, severity: float, direction: Vector3 = Vector3.UP) -> void:
	if _particles == null:
		return
	if not _spec.should_burst(severity):
		return
	global_position = world_pos
	var count := _spec.particle_count(severity)
	var speed := _spec.burst_speed(severity)
	_particles.amount = clampi(count, 1, CAPACITY)
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	_particles.direction = dir
	_particles.initial_velocity_min = speed * 0.4
	_particles.initial_velocity_max = speed
	
	_particles.emitting = false
	_particles.restart()
	_particles.emitting = true


func _create_particle_mesh() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = SPARK_SIZE
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = Color(1.0, 0.75, 0.25)
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.7, 0.3)
	spark_mat.emission_energy_multiplier = 2.0
	quad.material = spark_mat
	return quad
