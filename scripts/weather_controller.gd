class_name WeatherController
extends Node






















const GLOBAL_UNIFORM := &"wetness"



const TRANSITION_TIME := 3.0



const WET_LEVEL := 0.9
const DRY_LEVEL := 0.0


@export var start_wet: bool = false



var _wet: bool = false

var _level: float = 0.0
var _tween: Tween
var _rain_particles: GPUParticles3D
var _rain_material: StandardMaterial3D
var _rain_mesh: QuadMesh
var _world_environment: WorldEnvironment
var _rain_target: Node3D
var _rain_overlay: Control
var _base_ambient_energy: float = 0.5
var _base_fog_density: float = 0.002
var _base_fog_color := Color(0.7, 0.75, 0.8)
var _base_light_energy: float = 1.0
var _sky_material: ShaderMaterial
var _base_sky_zenith := Color(0.18, 0.4, 0.72)
var _base_sky_horizon := Color(0.66, 0.78, 0.9)
var _base_sky_ground := Color(0.34, 0.36, 0.38)


func _ready() -> void:
	_world_environment = get_node_or_null("../WorldEnvironment") as WorldEnvironment
	_rain_target = get_node_or_null("../Car") as Node3D
	_rain_overlay = get_node_or_null("../RainOverlayLayer/RainOverlay") as Control
	if _world_environment != null and _world_environment.environment != null:
		_base_ambient_energy = _world_environment.environment.ambient_light_energy
		_base_fog_density = _world_environment.environment.fog_density
		_base_fog_color = _world_environment.environment.fog_light_color
		if _world_environment.environment.sky != null:
			_sky_material = _world_environment.environment.sky.sky_material as ShaderMaterial
			if _sky_material != null:
				var zenith: Variant = _sky_material.get_shader_parameter("zenith_color")
				var horizon: Variant = _sky_material.get_shader_parameter("horizon_color")
				var ground: Variant = _sky_material.get_shader_parameter("ground_color")
				if zenith is Color:
					_base_sky_zenith = zenith
				if horizon is Color:
					_base_sky_horizon = horizon
				if ground is Color:
					_base_sky_ground = ground
	var sun := get_node_or_null("../DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		_base_light_energy = sun.light_energy
	_build_rain_emitter()
	_wet = start_wet
	_level = WET_LEVEL if _wet else DRY_LEVEL
	_apply_level(_level)
	_set_rain_visible(_wet)


func _process(_delta: float) -> void:
	if _rain_particles != null and _rain_target != null:
		
		
		_rain_particles.global_position = _rain_target.global_position + Vector3(0.0, 14.0, 0.0)


func _build_rain_emitter() -> void:
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.amount = 900
	_rain_particles.lifetime = 1.15
	_rain_particles.randomness = 0.35
	_rain_particles.local_coords = false
	_rain_particles.visibility_aabb = AABB(Vector3(-24.0, -16.0, -24.0), Vector3(48.0, 32.0, 48.0))

	_rain_material = StandardMaterial3D.new()
	_rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_rain_material.albedo_color = Color(0.68, 0.82, 1.0, 0.48)

	_rain_mesh = QuadMesh.new()
	_rain_mesh.size = Vector2(0.035, 1.45)
	_rain_mesh.material = _rain_material
	_rain_particles.draw_pass_1 = _rain_mesh

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.04, -1.0, 0.02)
	process_material.spread = 7.0
	process_material.gravity = Vector3(0.0, -3.0, 0.0)
	process_material.initial_velocity_min = 18.0
	process_material.initial_velocity_max = 27.0
	process_material.scale_min = 0.75
	process_material.scale_max = 1.15
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(22.0, 2.0, 22.0)
	_rain_particles.process_material = process_material
	add_child(_rain_particles)


func _set_rain_visible(enabled: bool) -> void:
	if _rain_particles == null:
		return
	_rain_particles.emitting = enabled
	_rain_particles.visible = enabled
	if _rain_overlay != null and _rain_overlay.has_method("set_raining"):
		_rain_overlay.call("set_raining", enabled)


func _apply_rain_atmosphere(level: float) -> void:
	var rain_factor := clampf(level / WET_LEVEL, 0.0, 1.0)
	if _world_environment != null and _world_environment.environment != null:
		var env := _world_environment.environment
		
		env.ambient_light_energy = lerpf(_base_ambient_energy, _base_ambient_energy * 0.50, rain_factor)
		env.fog_density = lerpf(_base_fog_density, maxf(_base_fog_density * 4.6, 0.008), rain_factor)
		env.fog_light_color = _base_fog_color.lerp(Color(0.24, 0.28, 0.32), rain_factor * 0.9)
	if _sky_material != null:
		_sky_material.set_shader_parameter("zenith_color", _base_sky_zenith.lerp(Color(0.20, 0.22, 0.24), rain_factor))
		_sky_material.set_shader_parameter("horizon_color", _base_sky_horizon.lerp(Color(0.48, 0.50, 0.51), rain_factor))
		_sky_material.set_shader_parameter("ground_color", _base_sky_ground.lerp(Color(0.22, 0.24, 0.25), rain_factor))
	var sun := get_node_or_null("../DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.light_energy = lerpf(_base_light_energy, _base_light_energy * 0.45, rain_factor)
	_set_rain_visible(rain_factor > 0.02)




func toggle() -> bool:
	set_wet(not _wet)
	return _wet




func set_wet(wet: bool) -> void:
	if wet == _wet and _tween == null:
		return
	_wet = wet
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target := WET_LEVEL if wet else DRY_LEVEL
	_tween.tween_method(_apply_level, _level, target, TRANSITION_TIME)



func is_wet() -> bool:
	return _wet



func get_level() -> float:
	return _level








func _apply_level(level: float) -> void:
	_level = clampf(level, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set(GLOBAL_UNIFORM, _level)
	_apply_rain_atmosphere(_level)
