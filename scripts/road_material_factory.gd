class_name RoadMaterialFactory
extends RefCounted












const ASPHALT_SHADER: Shader = preload("res://scripts/shaders/asphalt.gdshader")


const ASPHALT_JUNCTION_SHADER: Shader = preload("res://scripts/shaders/asphalt_junction.gdshader")
const RoadProfileScript := preload("res://scripts/road_profile.gd")


const UNPAVED_TYPES := {
	"footway": true,
	"path": true,
	"cycleway": true,
	"track": true,
	"pedestrian": true,
}










const ROAD_RENDER_PRIORITY := {
	"path": 1,
	"footway": 1,
	"cycleway": 2,
	"track": 2,
	"pedestrian": 3,
	"service": 5,
	"living_street": 6,
	"unclassified": 7,
	"residential": 8,
	"tertiary_link": 9,
	"tertiary": 10,
	"secondary_link": 11,
	"secondary": 12,
	"primary_link": 13,
	"primary": 14,
	"trunk_link": 15,
	"trunk": 16,
	"motorway_link": 17,
	"motorway": 18,
}

const DEFAULT_RENDER_PRIORITY := 7





static func render_priority_for(highway_type: String) -> int:
	return ROAD_RENDER_PRIORITY.get(highway_type, DEFAULT_RENDER_PRIORITY)









static func create_road_material(
		highway_type: String,
		color: Color,
		lane_spec: RoadLaneSpec = null,
		road_width: float = 0.0,
		road_length: float = 0.0,
		marking_spec: RoadMarkingSpec = null,
) -> Material:
	var priority := render_priority_for(highway_type)

	if UNPAVED_TYPES.has(highway_type):
		var plain := StandardMaterial3D.new()
		plain.albedo_color = color
		plain.roughness = 1.0
		
		
		
		plain.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		plain.render_priority = priority
		return plain

	var mat := ShaderMaterial.new()
	mat.shader = ASPHALT_SHADER
	mat.set_shader_parameter("base_color", color)
	
	
	
	mat.render_priority = priority
	_apply_lane_markings(mat, lane_spec, road_width, road_length)
	_apply_transverse_markings(mat, marking_spec, road_width)
	return mat



















const JUNCTION_PRIORITY := 30




static var _junction_materials: Dictionary = {}
static var _marking_material: Material = null
static var _sidewalk_material: Material = null


static func create_junction_material(highway_type: String) -> Material:
	if _junction_materials.has(highway_type):
		return _junction_materials[highway_type]
	var mat := _make_junction_material(highway_type)
	_junction_materials[highway_type] = mat
	return mat


static func _make_junction_material(highway_type: String) -> Material:
	var color: Color = RoadProfileScript.color_for(highway_type)
	if not RoadProfileScript.is_paved(highway_type):
		var plain := StandardMaterial3D.new()
		plain.albedo_color = color
		plain.roughness = 1.0
		
		
		plain.render_priority = JUNCTION_PRIORITY
		return plain

	var mat := ShaderMaterial.new()
	mat.shader = ASPHALT_JUNCTION_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.render_priority = JUNCTION_PRIORITY
	return mat





static func create_marking_material() -> Material:
	if _marking_material != null:
		return _marking_material
	var mat := StandardMaterial3D.new()
	_marking_material = mat
	mat.albedo_color = Color(0.85, 0.82, 0.62)
	mat.roughness = 0.55
	
	mat.render_priority = 40
	return mat





static func create_sidewalk_material() -> Material:
	if _sidewalk_material != null:
		return _sidewalk_material
	var mat := StandardMaterial3D.new()
	_sidewalk_material = mat
	mat.albedo_color = RoadProfileScript.SIDEWALK_COLOR
	mat.roughness = 0.95
	return mat




static func _apply_lane_markings(
		mat: ShaderMaterial,
		lane_spec: RoadLaneSpec,
		road_width: float,
		road_length: float,
) -> void:
	if lane_spec == null or not lane_spec.marked or road_width <= 0.0:
		mat.set_shader_parameter("markings_enabled", 0.0)
		return
	mat.set_shader_parameter("markings_enabled", 1.0)
	mat.set_shader_parameter("road_width", road_width)
	mat.set_shader_parameter("road_length", road_length)
	mat.set_shader_parameter("lane_count", float(lane_spec.lane_count))
	mat.set_shader_parameter("forward_lanes", float(lane_spec.forward_lanes))
	mat.set_shader_parameter("one_way", 1.0 if lane_spec.one_way else 0.0)







static func _apply_transverse_markings(
		mat: ShaderMaterial,
		marking_spec: RoadMarkingSpec,
		road_width: float,
) -> void:
	if marking_spec == null or marking_spec.is_empty() or road_width <= 0.0:
		mat.set_shader_parameter("transverse_count", 0)
		return
	var along := marking_spec.along_positions()
	var kinds := marking_spec.kinds()
	var facings := marking_spec.facings()
	mat.set_shader_parameter("transverse_count", along.size())
	
	
	
	mat.set_shader_parameter("transverse_along", along)
	mat.set_shader_parameter("transverse_kind", kinds)
	mat.set_shader_parameter("transverse_facing", facings)
	
	
	
	mat.set_shader_parameter("road_width", road_width)
