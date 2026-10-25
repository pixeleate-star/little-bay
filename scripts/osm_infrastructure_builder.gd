class_name OSMInfrastructureBuilder
extends RefCounted









const POWERLINE_COLORS := {
	"line": Color(0.1, 0.1, 0.12),         
	"minor_line": Color(0.15, 0.15, 0.17), 
	"cable": Color(0.12, 0.12, 0.14),
}
const POWERLINE_DEFAULT_COLOR := Color(0.12, 0.12, 0.14)

const POWERLINE_HEIGHTS := {
	"line": 18.0,        
	"minor_line": 8.0,   
	"cable": 8.0,
}
const POWERLINE_DEFAULT_HEIGHT := 10.0
const POWERLINE_SAG := 0.08          
const POWERLINE_RADIUS := 0.12       
const POWERLINE_SUBDIVS := 6         





func build_power_line(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData) -> MeshInstance3D:
	var points := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
	if points.size() < 2:
		return null

	var power_type: String = way.tags.get("power", "minor_line")
	var color: Color = POWERLINE_COLORS.get(power_type, POWERLINE_DEFAULT_COLOR)
	var height: float = POWERLINE_HEIGHTS.get(power_type, POWERLINE_DEFAULT_HEIGHT)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PowerLine_%d" % way.id

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	st.set_material(mat)

	for i: int in range(points.size() - 1):
		_emit_catenary_span(st, points[i], points[i + 1], height)

	mesh_instance.mesh = st.commit()
	return mesh_instance




func _emit_catenary_span(st: SurfaceTool, a: Vector3, b: Vector3, height: float) -> void:
	var span := Vector3(b.x - a.x, 0.0, b.z - a.z).length()
	var sag := span * POWERLINE_SAG
	var samples: Array[Vector3] = []
	for s: int in range(POWERLINE_SUBDIVS + 1):
		var t := float(s) / float(POWERLINE_SUBDIVS)
		var x := lerpf(a.x, b.x, t)
		var z := lerpf(a.z, b.z, t)
		var ground := lerpf(a.y, b.y, t)
		
		var droop := -sag * (4.0 * t * (1.0 - t))
		samples.append(Vector3(x, ground + height + droop, z))
	for s: int in range(samples.size() - 1):
		PolygonUtils.add_tube_segment(st, samples[s], samples[s + 1], POWERLINE_RADIUS)



const GANTRY_COLOR := Color(0.45, 0.45, 0.48)  
const GANTRY_CLEARANCE := 5.5                   
const GANTRY_BEAM := 0.5                        
const GANTRY_LEG := 0.4                         





func build_gantry(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData) -> MeshInstance3D:
	var points := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
	if points.size() < 2:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Gantry_%d" % way.id

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GANTRY_COLOR
	mat.metallic = 0.5
	st.set_material(mat)

	
	for i: int in range(points.size() - 1):
		var a := points[i] + Vector3(0.0, GANTRY_CLEARANCE, 0.0)
		var b := points[i + 1] + Vector3(0.0, GANTRY_CLEARANCE, 0.0)
		PolygonUtils.add_tube_segment(st, a, b, GANTRY_BEAM * 0.5)

	
	var p0 := points[0]
	var p1 := points[points.size() - 1]
	PolygonUtils.add_tube_segment(st,
		Vector3(p0.x, p0.y, p0.z),
		Vector3(p0.x, p0.y + GANTRY_CLEARANCE, p0.z), GANTRY_LEG * 0.5)
	PolygonUtils.add_tube_segment(st,
		Vector3(p1.x, p1.y, p1.z),
		Vector3(p1.x, p1.y + GANTRY_CLEARANCE, p1.z), GANTRY_LEG * 0.5)

	mesh_instance.mesh = st.commit()
	return mesh_instance
