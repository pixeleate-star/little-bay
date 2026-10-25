class_name CarAudioTriggers
extends RefCounted

















var screech_slip_threshold: float = 0.20



var screech_slip_full: float = 0.6



var screech_min_speed: float = 3.0





var screech_full_speed: float = 10.0



var screech_attack: float = 12.0






var screech_release: float = 3.0




var screech_level: float = 0.0





var impact_min_severity: float = 5.0


var impact_full_severity: float = 120.0



var impact_cooldown: float = 0.15


var _time_since_impact: float = 999.0













func update_screech(slip_angle: float, speed: float, gripping: bool, delta: float) -> float:
	_time_since_impact += maxf(0.0, delta)
	var target := _screech_target(slip_angle, speed, gripping)
	
	
	
	var rate := screech_attack if target > screech_level else screech_release
	var w := clampf(delta * rate, 0.0, 1.0)
	screech_level = lerpf(screech_level, target, w)
	
	if screech_level < 0.001 and target <= 0.0:
		screech_level = 0.0
	return screech_level




func _screech_target(slip_angle: float, speed: float, gripping: bool) -> float:
	if speed < screech_min_speed:
		return 0.0
	var slip_factor := clampf(
		(absf(slip_angle) - screech_slip_threshold)
			/ maxf(0.0001, screech_slip_full - screech_slip_threshold),
		0.0, 1.0)
	if slip_factor <= 0.0:
		return 0.0
	var speed_factor := clampf(
		(speed - screech_min_speed) / maxf(0.0001, screech_full_speed - screech_min_speed),
		0.0, 1.0)
	var level := slip_factor * speed_factor
	
	
	
	if gripping:
		level *= 0.85
	return clampf(level, 0.0, 1.0)













func register_impact(severity: float) -> Dictionary:
	if severity < impact_min_severity:
		return {"play": false, "volume": 0.0}
	if _time_since_impact < impact_cooldown:
		return {"play": false, "volume": 0.0}
	_time_since_impact = 0.0
	var volume := clampf(
		(severity - impact_min_severity)
			/ maxf(0.0001, impact_full_severity - impact_min_severity),
		0.0, 1.0)
	
	volume = maxf(0.15, volume)
	return {"play": true, "volume": volume}
