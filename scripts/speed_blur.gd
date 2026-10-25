class_name SpeedBlur
extends ColorRect


























@export var start_speed_kmh: float = 90.0



@export var full_speed_kmh: float = 200.0




@export var max_strength: float = 0.55




@export var curve_exponent: float = 1.6




@export var response: float = 3.0



@export var enabled: bool = true



var _strength: float = 0.0



const STRENGTH_UNIFORM := &"strength"


func _ready() -> void:
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	
	_apply_strength(0.0)




func update_speed(speed_kmh: float, delta: float) -> void:
	
	
	
	if delta <= 0.0:
		return

	var target := 0.0 if not enabled else strength_for_speed(speed_kmh)
	
	
	if response <= 0.0:
		_strength = target
	else:
		_strength = lerpf(_strength, target, clampf(response * delta, 0.0, 1.0))
	_apply_strength(_strength)







func strength_for_speed(speed_kmh: float) -> float:
	var speed := absf(speed_kmh)
	if speed <= start_speed_kmh:
		return 0.0
	if full_speed_kmh <= start_speed_kmh:
		return max_strength
	var t := clampf((speed - start_speed_kmh) / (full_speed_kmh - start_speed_kmh), 0.0, 1.0)
	return pow(t, curve_exponent) * max_strength



func get_strength() -> float:
	return _strength




func reset() -> void:
	_strength = 0.0
	_apply_strength(0.0)





func _apply_strength(value: float) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(STRENGTH_UNIFORM, value)
