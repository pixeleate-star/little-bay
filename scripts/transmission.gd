class_name Transmission
extends RefCounted















const FORWARD_GEAR_COUNT := 6


const GEAR_REVERSE := -1
const GEAR_NEUTRAL := 0







var gear_spacing: float = 1.15



var neutral_speed_threshold: float = 1.0



var _upshift_points: PackedFloat32Array = PackedFloat32Array()



var _built_for_max_speed: float = -1.0








func build_for_max_speed(max_speed_kmh: float) -> void:
	_built_for_max_speed = max_speed_kmh
	_upshift_points.resize(FORWARD_GEAR_COUNT)

	
	var weights := PackedFloat32Array()
	weights.resize(FORWARD_GEAR_COUNT)
	var total_weight := 0.0
	for i in FORWARD_GEAR_COUNT:
		var w: float = pow(gear_spacing, float(i))
		weights[i] = w
		total_weight += w

	
	var cumulative := 0.0
	for i in FORWARD_GEAR_COUNT:
		cumulative += weights[i]
		_upshift_points[i] = max_speed_kmh * (cumulative / total_weight)









func gear_for_speed(forward_speed_kmh: float, max_speed_kmh: float) -> int:
	if not is_equal_approx(max_speed_kmh, _built_for_max_speed):
		build_for_max_speed(max_speed_kmh)

	if forward_speed_kmh <= -neutral_speed_threshold:
		return GEAR_REVERSE
	if forward_speed_kmh < neutral_speed_threshold:
		return GEAR_NEUTRAL

	
	for i in FORWARD_GEAR_COUNT:
		if forward_speed_kmh <= _upshift_points[i]:
			return i + 1
	return FORWARD_GEAR_COUNT






func gear_ratio_for_speed(forward_speed_kmh: float, max_speed_kmh: float) -> float:
	var gear := gear_for_speed(forward_speed_kmh, max_speed_kmh)
	if gear <= GEAR_NEUTRAL:
		return 0.0
	
	var lower := 0.0
	if gear >= 2:
		lower = _upshift_points[gear - 2]
	var upper := _upshift_points[gear - 1]
	if upper <= lower:
		return 0.0
	return clampf((forward_speed_kmh - lower) / (upper - lower), 0.0, 1.0)



static func gear_label(gear: int) -> String:
	if gear == GEAR_REVERSE:
		return "R"
	if gear == GEAR_NEUTRAL:
		return "N"
	return str(gear)
