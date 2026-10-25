class_name Headlights
extends Node3D














const FADE_TIME := 0.8



@export var beam_energy: float = 6.0


@export var lamp_glow_energy: float = 4.0


var _beams: Array[SpotLight3D] = []

var _lamp_meshes: Array[MeshInstance3D] = []


var _lamp_materials: Array[StandardMaterial3D] = []

var _on: bool = false
var _tween: Tween


func _ready() -> void:
	
	
	
	for child in _all_descendants(self):
		if child is SpotLight3D:
			_beams.append(child as SpotLight3D)
		elif child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			
			
			
			var mat := mesh.get_active_material(0)
			if mat is StandardMaterial3D:
				var unique := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(0, unique)
				_lamp_meshes.append(mesh)
				_lamp_materials.append(unique)

	
	_apply_level(0.0)




func set_on(on: bool) -> void:
	if on == _on:
		return
	_on = on
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target := 1.0 if on else 0.0
	_tween.tween_method(_apply_level, _current_level(), target, FADE_TIME)



func is_on() -> bool:
	return _on






func _current_level() -> float:
	if _beams.is_empty() or beam_energy <= 0.0:
		return 1.0 if _on else 0.0
	return clampf(_beams[0].light_energy / beam_energy, 0.0, 1.0)




func _apply_level(level: float) -> void:
	var lit := level > 0.001
	for beam in _beams:
		beam.light_energy = beam_energy * level
		beam.visible = lit
	for i in _lamp_meshes.size():
		
		
		_lamp_meshes[i].visible = lit
	for mat in _lamp_materials:
		mat.emission_enabled = lit
		mat.emission_energy_multiplier = lamp_glow_energy * level


func _all_descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out
