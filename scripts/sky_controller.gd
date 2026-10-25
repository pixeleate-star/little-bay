class_name SkyController
extends Node

















signal day_night_changed(is_day: bool)



class SkyPreset:
	var zenith_color: Color
	var horizon_color: Color
	var ground_color: Color
	var sun_color: Color
	var sun_energy: float          
	var cloud_color: Color
	var cloud_shadow_color: Color
	var cloud_coverage: float
	var cloud_opacity: float
	var light_color: Color         
	var light_energy: float        
	var sun_angle_deg: float       
	var ambient_color: Color
	var ambient_energy: float
	var fog_color: Color
	var fog_density: float


const DAY := {
	"zenith_color": Color(0.18, 0.40, 0.72),
	"horizon_color": Color(0.66, 0.78, 0.90),
	"ground_color": Color(0.34, 0.36, 0.38),
	"sun_color": Color(1.0, 0.95, 0.85),
	"sun_energy": 1.0,
	"cloud_color": Color(1.0, 1.0, 1.0),
	"cloud_shadow_color": Color(0.62, 0.66, 0.72),
	"cloud_coverage": 0.5,
	"cloud_opacity": 1.0,
	"light_color": Color(1.0, 0.96, 0.88),
	"light_energy": 1.3,
	"sun_angle_deg": 55.0,
	"ambient_color": Color(0.6, 0.65, 0.7),
	"ambient_energy": 0.5,
	"fog_color": Color(0.7, 0.75, 0.8),
	"fog_density": 0.002,
}



const NIGHT := {
	"zenith_color": Color(0.02, 0.03, 0.08),
	"horizon_color": Color(0.06, 0.08, 0.16),
	"ground_color": Color(0.02, 0.02, 0.04),
	"sun_color": Color(0.55, 0.62, 0.85),
	"sun_energy": 0.25,
	"cloud_color": Color(0.20, 0.23, 0.30),
	"cloud_shadow_color": Color(0.05, 0.06, 0.10),
	"cloud_coverage": 0.45,
	"cloud_opacity": 0.8,
	"light_color": Color(0.55, 0.62, 0.85),
	"light_energy": 0.18,
	"sun_angle_deg": 18.0,
	"ambient_color": Color(0.10, 0.13, 0.22),
	"ambient_energy": 0.35,
	"fog_color": Color(0.05, 0.07, 0.13),
	"fog_density": 0.0035,
}



const SUN_AZIMUTH_DEG := 135.0


const TRANSITION_TIME := 1.5




@export var world_environment_path: NodePath

@export var sun_light_path: NodePath

@export var start_in_day: bool = true


var environment: Environment

var sun_light: DirectionalLight3D



var _is_day: bool = true
var _tween: Tween


var _current := SkyPreset.new()
var _sky_material: ShaderMaterial


func _ready() -> void:
	
	
	var we := get_node_or_null(world_environment_path) as WorldEnvironment
	if we != null:
		environment = we.environment
	sun_light = get_node_or_null(sun_light_path) as DirectionalLight3D

	
	
	if environment != null and environment.sky != null:
		var mat := environment.sky.sky_material
		if mat is ShaderMaterial:
			_sky_material = mat

	
	_is_day = start_in_day
	_copy_preset_into(_preset_dict(_is_day), _current)
	_apply_current()




func toggle_day_night() -> bool:
	set_day(not _is_day)
	return _is_day



func set_day(target_is_day: bool) -> void:
	if target_is_day == _is_day and _tween == null:
		return
	_is_day = target_is_day
	day_night_changed.emit(_is_day)
	_start_transition(_preset_dict(_is_day))



func is_day() -> bool:
	return _is_day




func _preset_dict(target_is_day: bool) -> Dictionary:
	return DAY if target_is_day else NIGHT





func _start_transition(target: Dictionary) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var goal := SkyPreset.new()
	_copy_preset_into(target, goal)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	
	var from := SkyPreset.new()
	_copy_struct(_current, from)
	_tween.tween_method(
		_blend_step.bind(from, goal), 0.0, 1.0, TRANSITION_TIME
	)


func _blend_step(weight: float, from: SkyPreset, to: SkyPreset) -> void:
	_current.zenith_color = from.zenith_color.lerp(to.zenith_color, weight)
	_current.horizon_color = from.horizon_color.lerp(to.horizon_color, weight)
	_current.ground_color = from.ground_color.lerp(to.ground_color, weight)
	_current.sun_color = from.sun_color.lerp(to.sun_color, weight)
	_current.sun_energy = lerpf(from.sun_energy, to.sun_energy, weight)
	_current.cloud_color = from.cloud_color.lerp(to.cloud_color, weight)
	_current.cloud_shadow_color = from.cloud_shadow_color.lerp(to.cloud_shadow_color, weight)
	_current.cloud_coverage = lerpf(from.cloud_coverage, to.cloud_coverage, weight)
	_current.cloud_opacity = lerpf(from.cloud_opacity, to.cloud_opacity, weight)
	_current.light_color = from.light_color.lerp(to.light_color, weight)
	_current.light_energy = lerpf(from.light_energy, to.light_energy, weight)
	_current.sun_angle_deg = lerpf(from.sun_angle_deg, to.sun_angle_deg, weight)
	_current.ambient_color = from.ambient_color.lerp(to.ambient_color, weight)
	_current.ambient_energy = lerpf(from.ambient_energy, to.ambient_energy, weight)
	_current.fog_color = from.fog_color.lerp(to.fog_color, weight)
	_current.fog_density = lerpf(from.fog_density, to.fog_density, weight)
	_apply_current()



func _apply_current() -> void:
	var night := inverse_lerp(float(DAY["light_energy"]), float(NIGHT["light_energy"]), _current.light_energy)
	RenderingServer.global_shader_parameter_set("building_night", clampf(night, 0.0, 1.0))
	
	
	
	var elev := deg_to_rad(_current.sun_angle_deg)
	var azim := deg_to_rad(SUN_AZIMUTH_DEG)
	var to_sun := Vector3(
		cos(elev) * sin(azim),
		sin(elev),
		cos(elev) * cos(azim)
	).normalized()

	if sun_light != null:
		sun_light.light_color = _current.light_color
		sun_light.light_energy = _current.light_energy
		
		sun_light.look_at_from_position(
			sun_light.global_position,
			sun_light.global_position - to_sun,
			Vector3.UP
		)
		
		sun_light.shadow_enabled = _current.light_energy > 0.05

	if _sky_material != null:
		_sky_material.set_shader_parameter("zenith_color", _current.zenith_color)
		_sky_material.set_shader_parameter("horizon_color", _current.horizon_color)
		_sky_material.set_shader_parameter("ground_color", _current.ground_color)
		_sky_material.set_shader_parameter("sun_direction", -to_sun)
		_sky_material.set_shader_parameter("sun_color", _current.sun_color)
		_sky_material.set_shader_parameter("sun_energy", _current.sun_energy)
		_sky_material.set_shader_parameter("cloud_color", _current.cloud_color)
		_sky_material.set_shader_parameter("cloud_shadow_color", _current.cloud_shadow_color)
		_sky_material.set_shader_parameter("cloud_coverage", _current.cloud_coverage)
		_sky_material.set_shader_parameter("cloud_opacity", _current.cloud_opacity)

	if environment != null:
		environment.ambient_light_color = _current.ambient_color
		environment.ambient_light_energy = _current.ambient_energy
		environment.fog_light_color = _current.fog_color
		environment.fog_density = _current.fog_density



func _copy_preset_into(d: Dictionary, out: SkyPreset) -> void:
	out.zenith_color = d.zenith_color
	out.horizon_color = d.horizon_color
	out.ground_color = d.ground_color
	out.sun_color = d.sun_color
	out.sun_energy = d.sun_energy
	out.cloud_color = d.cloud_color
	out.cloud_shadow_color = d.cloud_shadow_color
	out.cloud_coverage = d.cloud_coverage
	out.cloud_opacity = d.cloud_opacity
	out.light_color = d.light_color
	out.light_energy = d.light_energy
	out.sun_angle_deg = d.sun_angle_deg
	out.ambient_color = d.ambient_color
	out.ambient_energy = d.ambient_energy
	out.fog_color = d.fog_color
	out.fog_density = d.fog_density



func _copy_struct(src: SkyPreset, dst: SkyPreset) -> void:
	dst.zenith_color = src.zenith_color
	dst.horizon_color = src.horizon_color
	dst.ground_color = src.ground_color
	dst.sun_color = src.sun_color
	dst.sun_energy = src.sun_energy
	dst.cloud_color = src.cloud_color
	dst.cloud_shadow_color = src.cloud_shadow_color
	dst.cloud_coverage = src.cloud_coverage
	dst.cloud_opacity = src.cloud_opacity
	dst.light_color = src.light_color
	dst.light_energy = src.light_energy
	dst.sun_angle_deg = src.sun_angle_deg
	dst.ambient_color = src.ambient_color
	dst.ambient_energy = src.ambient_energy
	dst.fog_color = src.fog_color
	dst.fog_density = src.fog_density
