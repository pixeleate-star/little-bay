class_name CarPaint
extends RefCounted


























const NAME_PAINT := "paintjob"
const NAME_GLASS := "glas"        
const NAME_GLASS_ALT := "glass"   
const NAME_LIGHTS := "rear lights"
const NAME_CHROME := "chrome"
const NAME_TIRE := "tire"


const DEFAULT_PAINT_COLOR := Color(0.0, 0.393, 0.674, 1.0)



const PAINT_METALLIC := 0.9
const PAINT_ROUGHNESS := 0.28
const PAINT_CLEARCOAT := 1.0
const PAINT_CLEARCOAT_ROUGHNESS := 0.06




const GLASS_COLOR := Color(0.05, 0.06, 0.08, 0.55)
const GLASS_ROUGHNESS := 0.02
const GLASS_METALLIC := 0.5


const CHROME_COLOR := Color(0.9, 0.9, 0.92)
const CHROME_METALLIC := 1.0
const CHROME_ROUGHNESS := 0.08



const LIGHTS_COLOR := Color(0.6, 0.03, 0.03)
const LIGHTS_EMISSION := Color(0.8, 0.02, 0.02)
const LIGHTS_EMISSION_ENERGY := 1.6


const TIRE_COLOR := Color(0.05, 0.05, 0.06)
const TIRE_ROUGHNESS := 0.9










func apply_to(root: Node, paint_color: Color = DEFAULT_PAINT_COLOR) -> int:
	var count := 0
	for mi: MeshInstance3D in _mesh_instances(root):
		count += _apply_to_mesh(mi, paint_color)
	return count





func material_for(surface_name: String, paint_color: Color = DEFAULT_PAINT_COLOR) -> Material:
	var key := surface_name.strip_edges().to_lower()
	match key:
		NAME_PAINT:
			return build_paint_material(paint_color)
		NAME_GLASS, NAME_GLASS_ALT:
			return build_glass_material()
		NAME_CHROME:
			return build_chrome_material()
		NAME_LIGHTS:
			return build_lights_material()
		NAME_TIRE:
			return build_tire_material()
		_:
			return null





func build_paint_material(color: Color = DEFAULT_PAINT_COLOR) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "CarPaint_Body"
	m.albedo_color = color
	m.metallic = PAINT_METALLIC
	m.metallic_specular = 0.5
	m.roughness = PAINT_ROUGHNESS
	
	
	m.clearcoat_enabled = true
	m.clearcoat = PAINT_CLEARCOAT
	m.clearcoat_roughness = PAINT_CLEARCOAT_ROUGHNESS
	return m



func build_glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "CarPaint_Glass"
	m.albedo_color = GLASS_COLOR
	m.metallic = GLASS_METALLIC
	m.metallic_specular = 0.9
	m.roughness = GLASS_ROUGHNESS
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m



func build_chrome_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "CarPaint_Chrome"
	m.albedo_color = CHROME_COLOR
	m.metallic = CHROME_METALLIC
	m.metallic_specular = 1.0
	m.roughness = CHROME_ROUGHNESS
	return m



func build_lights_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "CarPaint_RearLights"
	m.albedo_color = LIGHTS_COLOR
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = LIGHTS_EMISSION
	m.emission_energy_multiplier = LIGHTS_EMISSION_ENERGY
	return m



func build_tire_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "CarPaint_Tire"
	m.albedo_color = TIRE_COLOR
	m.metallic = 0.0
	m.roughness = TIRE_ROUGHNESS
	return m







func _apply_to_mesh(mi: MeshInstance3D, paint_color: Color) -> int:
	var mesh := mi.mesh
	if mesh == null:
		return 0
	var count := 0
	for s: int in range(mesh.get_surface_count()):
		var existing := mi.get_active_material(s)
		var name := ""
		if existing != null:
			name = existing.resource_name
		var replacement := material_for(name, paint_color)
		if replacement != null:
			mi.set_surface_override_material(s, replacement)
			count += 1
	return count



func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root == null:
		return out
	if root is MeshInstance3D:
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_mesh_instances(child))
	return out
