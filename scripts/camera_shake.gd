class_name CameraShake
extends RefCounted






















var max_offset: float = 0.25



var max_roll: float = 0.06



var decay_rate: float = 1.6



var trauma_power: float = 2.0



var frequency: float = 18.0



var trauma: float = 0.0



var _time: float = 0.0




var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.seed = 1337
	
	
	_noise.frequency = 1.0





func add_trauma(amount: float) -> void:
	if amount <= 0.0:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)




func tick(delta: float) -> float:
	if delta <= 0.0:
		return trauma
	_time += delta
	trauma = maxf(0.0, trauma - decay_rate * delta)
	return trauma




func is_active() -> bool:
	return trauma > 0.0





func amplitude() -> float:
	return pow(trauma, trauma_power)








func get_offset() -> Dictionary:
	var amp := amplitude()
	if amp <= 0.0:
		return {"position": Vector3.ZERO, "rotation": Vector3.ZERO}
	var t := _time * frequency
	
	var nx := _sample(t, 0.0)
	var ny := _sample(t, 100.0)
	var nz := _sample(t, 200.0)
	var npitch := _sample(t, 300.0)
	var nyaw := _sample(t, 400.0)
	var pos := Vector3(nx, ny, nz) * (max_offset * amp)
	
	var rot := Vector3(
		npitch * (max_roll * 0.5 * amp),
		nyaw * (max_roll * 0.5 * amp),
		nx * (max_roll * amp),
	)
	return {"position": pos, "rotation": rot}



func _sample(t: float, axis_offset: float) -> float:
	return _noise.get_noise_2d(t + axis_offset, axis_offset)
