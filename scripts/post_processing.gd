class_name PostProcessing
extends Node





























class PPSettings:
	var glow_intensity: float
	var glow_bloom: float
	var glow_hdr_threshold: float
	var exposure: float
	var brightness: float
	var contrast: float
	var saturation: float
	
	
	
	
	var dof_far_distance: float
	var dof_far_transition: float
	var dof_far_amount: float




const DAY := {
	"glow_intensity": 0.8,
	"glow_bloom": 0.05,
	"glow_hdr_threshold": 1.0,
	"exposure": 1.0,
	"brightness": 1.0,
	"contrast": 1.05,
	"saturation": 1.12,
	
	
	"dof_far_distance": 180.0,
	"dof_far_transition": 220.0,
	"dof_far_amount": 0.10,
}





const NIGHT := {
	"glow_intensity": 1.3,
	"glow_bloom": 0.25,
	"glow_hdr_threshold": 0.65,
	"exposure": 1.15,
	"brightness": 1.0,
	"contrast": 1.1,
	"saturation": 1.02,
	
	
	"dof_far_distance": 150.0,
	"dof_far_transition": 200.0,
	"dof_far_amount": 0.14,
}



const TRANSITION_TIME := 1.5







@export var enabled: bool = true:
	set(v):
		enabled = v
		_reapply()


@export var glow_enabled: bool = true:
	set(v):
		glow_enabled = v
		_reapply()



@export var ssao_enabled: bool = true:
	set(v):
		ssao_enabled = v
		_reapply()



@export var ssil_enabled: bool = true:
	set(v):
		ssil_enabled = v
		_reapply()



@export var ssr_enabled: bool = true:
	set(v):
		ssr_enabled = v
		_reapply()



@export var adjustments_enabled: bool = true:
	set(v):
		adjustments_enabled = v
		_reapply()



@export var dof_enabled: bool = true:
	set(v):
		dof_enabled = v
		_reapply()




@export var world_environment_path: NodePath


@export var sky_controller_path: NodePath



@export var camera_path: NodePath


@export var start_in_day: bool = true

var environment: Environment


var _camera_attrs: CameraAttributesPractical
var _sky: SkyController
var _is_day: bool = true
var _tween: Tween

var _current := PPSettings.new()


func _ready() -> void:
	var we := get_node_or_null(world_environment_path) as WorldEnvironment
	if we != null:
		environment = we.environment

	
	
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam != null:
		if cam.attributes is CameraAttributesPractical:
			_camera_attrs = cam.attributes
		else:
			_camera_attrs = CameraAttributesPractical.new()
			cam.attributes = _camera_attrs

	_sky = get_node_or_null(sky_controller_path) as SkyController
	if _sky != null:
		
		
		_is_day = _sky.is_day()
		_sky.day_night_changed.connect(_on_day_night_changed)
	else:
		_is_day = start_in_day

	
	_copy_preset_into(_preset_dict(_is_day), _current)
	_reapply()





func _on_day_night_changed(is_day: bool) -> void:
	_is_day = is_day
	_start_transition(_preset_dict(is_day))


func _start_transition(target: Dictionary) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var goal := PPSettings.new()
	_copy_preset_into(target, goal)

	var from := PPSettings.new()
	_copy_struct(_current, from)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(
		_blend_step.bind(from, goal), 0.0, 1.0, TRANSITION_TIME
	)


func _blend_step(weight: float, from: PPSettings, to: PPSettings) -> void:
	_current.glow_intensity = lerpf(from.glow_intensity, to.glow_intensity, weight)
	_current.glow_bloom = lerpf(from.glow_bloom, to.glow_bloom, weight)
	_current.glow_hdr_threshold = lerpf(from.glow_hdr_threshold, to.glow_hdr_threshold, weight)
	_current.exposure = lerpf(from.exposure, to.exposure, weight)
	_current.brightness = lerpf(from.brightness, to.brightness, weight)
	_current.contrast = lerpf(from.contrast, to.contrast, weight)
	_current.saturation = lerpf(from.saturation, to.saturation, weight)
	_current.dof_far_distance = lerpf(from.dof_far_distance, to.dof_far_distance, weight)
	_current.dof_far_transition = lerpf(from.dof_far_transition, to.dof_far_transition, weight)
	_current.dof_far_amount = lerpf(from.dof_far_amount, to.dof_far_amount, weight)
	_reapply()






func _reapply() -> void:
	if environment != null:
		apply_to(environment, _current)
	if _camera_attrs != null:
		apply_dof_to(_camera_attrs, _current)








func apply_to(env: Environment, s: PPSettings) -> void:
	if not enabled:
		env.glow_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.ssr_enabled = false
		env.adjustment_enabled = false
		return

	
	env.glow_enabled = glow_enabled
	if glow_enabled:
		env.glow_intensity = s.glow_intensity
		env.glow_bloom = s.glow_bloom
		env.glow_hdr_threshold = s.glow_hdr_threshold
		
		
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	
	env.ssao_enabled = ssao_enabled

	
	env.ssil_enabled = ssil_enabled

	
	
	env.ssr_enabled = ssr_enabled

	
	
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = s.exposure
	env.adjustment_enabled = adjustments_enabled
	if adjustments_enabled:
		env.adjustment_brightness = s.brightness
		env.adjustment_contrast = s.contrast
		env.adjustment_saturation = s.saturation








func apply_dof_to(attrs: CameraAttributesPractical, s: PPSettings) -> void:
	if not enabled or not dof_enabled:
		attrs.dof_blur_far_enabled = false
		return
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = s.dof_far_distance
	attrs.dof_blur_far_transition = s.dof_far_transition
	attrs.dof_blur_amount = s.dof_far_amount
	
	attrs.dof_blur_near_enabled = false




func _preset_dict(target_is_day: bool) -> Dictionary:
	return DAY if target_is_day else NIGHT


func _copy_preset_into(d: Dictionary, out: PPSettings) -> void:
	out.glow_intensity = d.glow_intensity
	out.glow_bloom = d.glow_bloom
	out.glow_hdr_threshold = d.glow_hdr_threshold
	out.exposure = d.exposure
	out.brightness = d.brightness
	out.contrast = d.contrast
	out.saturation = d.saturation
	out.dof_far_distance = d.dof_far_distance
	out.dof_far_transition = d.dof_far_transition
	out.dof_far_amount = d.dof_far_amount


func _copy_struct(src: PPSettings, dst: PPSettings) -> void:
	dst.glow_intensity = src.glow_intensity
	dst.glow_bloom = src.glow_bloom
	dst.glow_hdr_threshold = src.glow_hdr_threshold
	dst.exposure = src.exposure
	dst.brightness = src.brightness
	dst.contrast = src.contrast
	dst.saturation = src.saturation
	dst.dof_far_distance = src.dof_far_distance
	dst.dof_far_transition = src.dof_far_transition
	dst.dof_far_amount = src.dof_far_amount
