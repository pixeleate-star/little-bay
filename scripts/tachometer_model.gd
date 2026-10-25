class_name TachometerModel
extends RefCounted



























var idle_rpm: float = 800.0



var max_rpm: float = 7500.0




var redline_rpm: float = 6500.0




var needle_response: float = 12.0



var dial_sweep: float = deg_to_rad(240.0)





var dial_start: float = deg_to_rad(60.0)





var display_rpm: float = 0.0



var target_rpm: float = 0.0












func update(gear: int, gear_ratio: float, speed_kmh: float, delta: float) -> float:
	target_rpm = rpm_for(gear, gear_ratio, speed_kmh)
	
	
	
	if delta <= 0.0:
		return display_rpm

	
	
	if needle_response <= 0.0:
		display_rpm = target_rpm
		return display_rpm

	
	
	
	var weight := clampf(needle_response * delta, 0.0, 1.0)
	display_rpm = lerpf(display_rpm, target_rpm, weight)
	return display_rpm






func rpm_for(gear: int, gear_ratio: float, speed_kmh: float) -> float:
	
	
	if gear == Transmission.GEAR_NEUTRAL:
		return idle_rpm

	
	
	if gear == Transmission.GEAR_REVERSE:
		var reverse_fraction := clampf(absf(speed_kmh) / _REVERSE_FULL_REV_KMH, 0.0, 1.0)
		return lerpf(idle_rpm, max_rpm, reverse_fraction)

	
	
	var t := clampf(gear_ratio, 0.0, 1.0)
	return lerpf(_shift_down_rpm(), max_rpm, t)





func needle_fraction() -> float:
	if max_rpm <= 0.0:
		return 0.0
	return clampf(display_rpm / max_rpm, 0.0, 1.0)





func needle_angle() -> float:
	return angle_for_fraction(needle_fraction())




func angle_for_fraction(fraction: float) -> float:
	return dial_start + clampf(fraction, 0.0, 1.0) * dial_sweep



func redline_fraction() -> float:
	if max_rpm <= 0.0:
		return 1.0
	return clampf(redline_rpm / max_rpm, 0.0, 1.0)





func is_redlining() -> bool:
	return display_rpm >= redline_rpm





func redline_intensity() -> float:
	if max_rpm <= redline_rpm:
		return 1.0 if is_redlining() else 0.0
	return clampf((display_rpm - redline_rpm) / (max_rpm - redline_rpm), 0.0, 1.0)




func reset() -> void:
	display_rpm = 0.0
	target_rpm = 0.0





func _shift_down_rpm() -> float:
	return lerpf(idle_rpm, max_rpm, _SHIFT_DOWN_FRACTION)




const _SHIFT_DOWN_FRACTION := 0.35



const _REVERSE_FULL_REV_KMH := 30.0
