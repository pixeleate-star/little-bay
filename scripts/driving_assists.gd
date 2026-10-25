class_name DrivingAssists
extends RefCounted





































var traction_control_enabled: bool = true

var abs_enabled: bool = true

var stability_control_enabled: bool = true









var tcs_slip_threshold: float = 0.15



var tcs_slip_full: float = 0.6




var tcs_max_cut: float = 0.8




var tcs_response: float = 12.0




var tcs_min_speed: float = 2.0







var abs_lock_threshold: float = 0.25


var abs_lock_full: float = 0.7



var abs_max_release: float = 0.75



var abs_response: float = 20.0




var abs_min_speed: float = 2.5







var stability_yaw_deadzone: float = 0.35




var stability_strength: float = 3000.0



var stability_max_torque: float = 9000.0



var stability_min_speed: float = 5.0




var stability_handbrake_factor: float = 0.15






var tcs_cut: float = 0.0


var abs_release: float = 0.0


var stability_intervention: float = 0.0












func filter_engine_force(
	engine_force: float,
	wheel_speed: float,
	car_speed: float,
	delta: float
) -> float:
	var target_cut := 0.0
	if traction_control_enabled and absf(car_speed) >= tcs_min_speed:
		var slip := slip_ratio(wheel_speed, car_speed)
		
		
		if slip > tcs_slip_threshold and tcs_slip_full > tcs_slip_threshold:
			target_cut = clampf(
				(slip - tcs_slip_threshold) / (tcs_slip_full - tcs_slip_threshold),
				0.0,
				1.0
			)
	tcs_cut = _approach(tcs_cut, target_cut, tcs_response, delta)
	return engine_force * (1.0 - tcs_cut * tcs_max_cut)










func filter_brake_force(
	brake_force: float,
	wheel_speed: float,
	car_speed: float,
	delta: float
) -> float:
	var target_release := 0.0
	if abs_enabled and absf(car_speed) >= abs_min_speed:
		
		
		var lock := -slip_ratio(wheel_speed, car_speed)
		if lock > abs_lock_threshold and abs_lock_full > abs_lock_threshold:
			target_release = clampf(
				(lock - abs_lock_threshold) / (abs_lock_full - abs_lock_threshold),
				0.0,
				1.0
			)
	abs_release = _approach(abs_release, target_release, abs_response, delta)
	return brake_force * (1.0 - abs_release * abs_max_release)













func stability_torque(
	yaw_rate: float,
	desired_yaw_rate: float,
	speed: float,
	handbrake: bool
) -> float:
	stability_intervention = 0.0
	if not stability_control_enabled or speed < stability_min_speed:
		return 0.0

	
	var error := yaw_rate - desired_yaw_rate
	if absf(error) <= stability_yaw_deadzone:
		return 0.0

	
	
	var excess := (absf(error) - stability_yaw_deadzone) * signf(error)
	var torque := -excess * stability_strength
	if handbrake:
		torque *= stability_handbrake_factor
	torque = clampf(torque, -stability_max_torque, stability_max_torque)
	stability_intervention = absf(torque)
	return torque








static func slip_ratio(wheel_speed: float, car_speed: float) -> float:
	var reference := maxf(absf(car_speed), 0.001)
	return (wheel_speed - car_speed) / reference




static func _approach(current: float, target: float, response: float, delta: float) -> float:
	if response <= 0.0 or delta <= 0.0:
		return target
	var weight := clampf(response * delta, 0.0, 1.0)
	return lerpf(current, target, weight)




func set_all_enabled(enabled: bool) -> void:
	traction_control_enabled = enabled
	abs_enabled = enabled
	stability_control_enabled = enabled




func reset() -> void:
	tcs_cut = 0.0
	abs_release = 0.0
	stability_intervention = 0.0
