class_name BuildingMaterialFactory
extends RefCounted




const WALL_SHADER: Shader = preload("res://scripts/shaders/building_wall.gdshader")
const ROOF_SHADER: Shader = preload("res://scripts/shaders/roof.gdshader")


enum WallKind { SMOOTH = 0, MASONRY = 1, PANEL = 2 }

enum RoofKind { TILES = 0, FLAT = 1, METAL = 2 }



const WALL_KIND_BY_MATERIAL := {
	"brick": WallKind.MASONRY,
	"stone": WallKind.MASONRY,
	"sandstone": WallKind.MASONRY,
	"limestone": WallKind.MASONRY,
	"granite": WallKind.MASONRY,
	"marble": WallKind.MASONRY,
	"cement_block": WallKind.MASONRY,
	"concrete": WallKind.PANEL,
	"metal": WallKind.PANEL,
	"steel": WallKind.PANEL,
	"glass": WallKind.PANEL,
	"plaster": WallKind.SMOOTH,
	"render": WallKind.SMOOTH,
	"stucco": WallKind.SMOOTH,
	"wood": WallKind.SMOOTH,
}



const ROOF_KIND_BY_MATERIAL := {
	"roof_tiles": RoofKind.TILES,
	"tile": RoofKind.TILES,
	"tiles": RoofKind.TILES,
	"thatch": RoofKind.TILES,
	"slate": RoofKind.TILES,
	"metal": RoofKind.METAL,
	"zinc": RoofKind.METAL,
	"tin": RoofKind.METAL,
	"copper": RoofKind.METAL,
	"eternit": RoofKind.FLAT,
	"tar_paper": RoofKind.FLAT,
	"gravel": RoofKind.FLAT,
	"grass": RoofKind.FLAT,
	"concrete": RoofKind.FLAT,
	"glass": RoofKind.FLAT,
}




static func wall_kind_for(material: String) -> WallKind:
	var key := material.strip_edges().to_lower()
	return WALL_KIND_BY_MATERIAL.get(key, WallKind.SMOOTH)



static func roof_kind_for(material: String) -> RoofKind:
	var key := material.strip_edges().to_lower()
	return ROOF_KIND_BY_MATERIAL.get(key, RoofKind.TILES)




const WALL_WEATHERING_BY_KIND := {
	WallKind.SMOOTH: 0.32,
	WallKind.MASONRY: 0.42,
	WallKind.PANEL: 0.18,
}



const ROOF_WEATHERING_BY_KIND := {
	RoofKind.TILES: 0.5,
	RoofKind.FLAT: 0.35,
	RoofKind.METAL: 0.2,
}







static var _wall_materials: Dictionary = {}
static var _roof_materials: Dictionary = {}





static func create_wall_material(color: Color, kind: WallKind = WallKind.SMOOTH) -> ShaderMaterial:
	var key := [color, kind]
	if _wall_materials.has(key):
		return _wall_materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("surface_kind", float(kind))
	mat.set_shader_parameter("weathering", float(WALL_WEATHERING_BY_KIND.get(kind, 0.32)))
	_wall_materials[key] = mat
	return mat




static func create_roof_material(color: Color, kind: RoofKind = RoofKind.TILES) -> ShaderMaterial:
	var key := [color, kind]
	if _roof_materials.has(key):
		return _roof_materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = ROOF_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("surface_kind", float(kind))
	mat.set_shader_parameter("weathering", float(ROOF_WEATHERING_BY_KIND.get(kind, 0.4)))
	_roof_materials[key] = mat
	return mat
















static func apply_to_building(root: Node, wall_kind: WallKind, roof_kind: RoofKind) -> int:
	var count := 0
	for mi: MeshInstance3D in _mesh_instances(root):
		var color := _existing_color(mi)
		if mi.name == "Roof":
			mi.material_override = create_roof_material(color, roof_kind)
		else:
			mi.material_override = create_wall_material(color, wall_kind)
		count += 1
	return count






static func _existing_color(mi: MeshInstance3D) -> Color:
	var mat := mi.get_active_material(0)
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	if mat is ShaderMaterial:
		var p = (mat as ShaderMaterial).get_shader_parameter("base_color")
		if p is Color:
			return p
	return Color.WHITE


static func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root == null:
		return out
	if root is MeshInstance3D:
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_mesh_instances(child))
	return out
