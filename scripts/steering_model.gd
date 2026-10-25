class_name SteeringModel
extends RefCounted





































var max_steer_angle: float = 0.32




var min_steer_angle: float = 0.06



var speed_sensitivity_full: float = 45.0





var speed_sensitivity_curve: float = 1.7




var steer_rate: float = 2.2




var return_rate: float = 4.0




var countersteer_max: float = 0.16



var countersteer_threshold: float = 0.12



var countersteer_full: float = 0.7






var countersteer_player_yield: float = 0.8



var countersteer_min_speed: float = 4.0






var steer_angle: float = 0.0



var assist_angle: float = 0.0













func update(
	input: float,
	speed: float,
	slip_angle: float,
	slip_sign: float,
	delta: float
) -> float:
	var limit := angle_limit_for_speed(speed)

	
	var target := clampf(input, -1.0, 1.0) * limit

	
	
	
	assist_angle = countersteer_for(slip_angle, slip_sign, speed, input, limit)
	target = clampf(target + assist_angle, -limit, limit)

	
	
	var returning := absf(target) < absf(steer_angle) and signf(target) == signf(steer_angle) \
		or is_zero_approx(target)
	var rate := return_rate if returning else steer_rate
	steer_angle = move_toward(steer_angle, target, rate * maxf(delta, 0.0))
	return steer_angle






func angle_limit_for_speed(speed: float) -> float:
	if speed_sensitivity_full <= 0.0:
		return max_steer_angle
	var t := clampf(absf(speed) / speed_sensitivity_full, 0.0, 1.0)
	
	var shaped := pow(t, speed_sensitivity_curve)
	return lerpf(max_steer_angle, min_steer_angle, shaped)








func countersteer_for(
	slip_angle: float,
	slip_sign: float,
	speed: float,
	input: float,
	limit: float
) -> float:
	if speed < countersteer_min_speed or is_zero_approx(slip_sign):
		return 0.0
	if slip_angle <= countersteer_threshold:
		return 0.0
	if countersteer_full <= countersteer_threshold:
		return 0.0

	
	
	var t := clampf(
		(slip_angle - countersteer_threshold) / (countersteer_full - countersteer_threshold),
		0.0,
		1.0
	)

	
	var direction := signf(slip_sign)
	var amount := t * countersteer_max * direction

	
	
	
	
	var player_correction := clampf(input * direction, 0.0, 1.0)
	amount *= 1.0 - player_correction * countersteer_player_yield

	
	return clampf(amount, -limit, limit)




func reset() -> void:
	steer_angle = 0.0
	assist_angle = 0.0
