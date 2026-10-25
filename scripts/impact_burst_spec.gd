class_name ImpactBurstSpec
extends RefCounted










var min_severity: float = 5.0

var full_severity: float = 150.0



var min_count: int = 6
var max_count: int = 40



var min_speed: float = 3.0
var max_speed: float = 12.0



func intensity(severity: float) -> float:
	return clampf(
		(severity - min_severity) / maxf(0.0001, full_severity - min_severity),
		0.0, 1.0)




func should_burst(severity: float) -> bool:
	return severity >= min_severity




func particle_count(severity: float) -> int:
	return int(round(lerpf(float(min_count), float(max_count), intensity(severity))))



func burst_speed(severity: float) -> float:
	return lerpf(min_speed, max_speed, intensity(severity))
