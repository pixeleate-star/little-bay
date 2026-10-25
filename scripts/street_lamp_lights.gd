class_name StreetLampLights
extends Node























const FADE_TIME := 1.2




class LampGroup:
	
	var lights: Array[OmniLight3D] = []
	
	var materials: Array[StandardMaterial3D] = []
	
	
	var light_energy: float = 0.0
	
	var glow_energy: float = 0.0
	
	
	
	var color: Color = Color.WHITE




var _groups: Dictionary = {}  



var _on: bool = false

var _level: float = 0.0
var _tween: Tween




func set_on(on: bool) -> void:
	if on == _on:
		return
	_on = on
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target := 1.0 if on else 0.0
	_tween.tween_method(_set_level, _level, target, FADE_TIME)



func is_on() -> bool:
	return _on






func register_tile(tile_root: Node, group: LampGroup) -> void:
	if tile_root == null or group == null:
		return
	_groups[tile_root] = group
	_apply_to_group(group, _level)





func unregister_tile(tile_root: Node) -> void:
	_groups.erase(tile_root)







func _set_level(level: float) -> void:
	_level = level
	_prune_freed()
	for tile_root: Node in _groups:
		_apply_to_group(_groups[tile_root], level)




func _apply_to_group(group: LampGroup, level: float) -> void:
	var lit := level > 0.001
	for light in group.lights:
		if is_instance_valid(light):
			light.light_color = group.color
			light.light_energy = group.light_energy * level
			light.visible = lit
	for mat in group.materials:
		mat.emission = group.color
		mat.emission_enabled = lit
		mat.emission_energy_multiplier = group.glow_energy * level





func _prune_freed() -> void:
	var dead: Array[Node] = []
	for tile_root: Node in _groups:
		if not is_instance_valid(tile_root):
			dead.append(tile_root)
	for tile_root: Node in dead:
		_groups.erase(tile_root)
