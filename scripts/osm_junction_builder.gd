class_name OSMJunctionBuilder
extends RefCounted

const RoadProfileScript := preload("res://scripts/road_profile.gd")
const RoadJunctionSolverScript := preload("res://scripts/road_junction_solver.gd")


























const CAP_Y := RoadProfileScript.ROAD_Y + 0.004


const PAINT_Y := 0.006



const MARKING_COLOR := Color(0.85, 0.82, 0.62)


const STOP_BAR_DEPTH := 0.4







const STOP_BAR_TYPES := {
	"motorway": true,
	"trunk": true,
	"primary": true,
	"secondary": true,
	"tertiary": true,
	"residential": true,
	"unclassified": true,
}















const CLASS_RANK := {
	"motorway": 8,
	"trunk": 7,
	"primary": 6,
	"secondary": 5,
	"tertiary": 4,
	"unclassified": 3,
	"residential": 3,
	"living_street": 2,
	"service": 1,
}




const DEFAULT_CLASS_RANK := 1









const YIELD_RANK_MARGIN := 1



const SHARK_TOOTH_BASE := 0.5
const SHARK_TOOTH_GAP := 0.5



const STOP_BAR_INSET := 0.5



const KERB_RAMP_RUN := 1.2








const KERB_CORNER_SEGMENTS := 4



var height_provider: HeightProvider = null
var terrain_grid_step: float = 0.0





var region: RoadRegion = RoadRegion.new()








func build_junction(
		junction: RoadJunctionSolverScript.Junction,
		sidewalk_lookup: Dictionary = {}) -> MeshInstance3D:
	if junction == null or junction.cap.size() < 3:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Junction_%d" % junction.node_id

	var surface_st := SurfaceTool.new()
	surface_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_st.set_material(RoadMaterialFactory.create_junction_material(
		junction.dominant_type))

	var built := _emit_cap(surface_st, junction)
	if not built:
		return null

	var mesh := surface_st.commit()

	
	
	var paint_st := SurfaceTool.new()
	paint_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	paint_st.set_material(RoadMaterialFactory.create_marking_material())
	if _emit_stop_bars(paint_st, junction):
		mesh = paint_st.commit(mesh)

	
	if not sidewalk_lookup.is_empty():
		var kerb_st := SurfaceTool.new()
		kerb_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		kerb_st.set_material(RoadMaterialFactory.create_sidewalk_material())
		if _emit_kerb_corners(kerb_st, junction, sidewalk_lookup):
			mesh = kerb_st.commit(mesh)

	mesh_instance.mesh = mesh
	return mesh_instance




func _emit_cap(st: SurfaceTool, junction: RoadJunctionSolverScript.Junction) -> bool:
	var cap := junction.cap
	var indices := PolygonUtils.triangulate_xz(cap)
	if indices.size() < 3:
		return false

	var conform := height_provider != null and height_provider.is_ready() \
		and terrain_grid_step > 0.0

	for i: int in range(0, indices.size(), 3):
		var a: Vector3 = cap[indices[i]]
		var b: Vector3 = cap[indices[i + 1]]
		var c: Vector3 = cap[indices[i + 2]]
		if conform:
			
			
			
			
			
			
			
			
			
			
			
			
			var tri := _wound_downward(a, b, c)
			PolygonUtils.emit_terrain_conforming_quad(
				st, tri, height_provider, terrain_grid_step, CAP_Y)
		else:
			
			
			
			var up_tri := _wound_upward(a, b, c)
			_add_flat_tri(
				st,
				Vector3(up_tri[0].x, 0.0, up_tri[0].y),
				Vector3(up_tri[1].x, 0.0, up_tri[1].y),
				Vector3(up_tri[2].x, 0.0, up_tri[2].y),
				CAP_Y)
	return true








func _wound_upward(a: Vector3, b: Vector3, c: Vector3) -> PackedVector2Array:
	var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
	if area < 0.0:
		return PackedVector2Array([
			Vector2(a.x, a.z), Vector2(c.x, c.z), Vector2(b.x, b.z),
		])
	return PackedVector2Array([
		Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z),
	])





func _wound_downward(a: Vector3, b: Vector3, c: Vector3) -> PackedVector2Array:
	var up := _wound_upward(a, b, c)
	return PackedVector2Array([up[0], up[2], up[1]])



func _add_flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		y_offset: float) -> void:
	for v: Vector3 in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(v.x, _height_at(v.x, v.z) + y_offset, v.z))



func _height_at(x: float, z: float) -> float:
	if height_provider != null and height_provider.is_ready():
		return height_provider.sample_mesh_height(x, z)
	return 0.0







func _emit_stop_bars(
		st: SurfaceTool, junction: RoadJunctionSolverScript.Junction) -> bool:
	
	if junction.arms.size() < RoadJunctionSolverScript.MIN_ARMS:
		return false

	
	var yields := _yielding_arms(junction.arms)

	var emitted := false
	for i: int in range(junction.arms.size()):
		if not yields[i]:
			continue
		var arm: RoadJunctionSolverScript.Arm = junction.arms[i]
		
		
		
		
		if not STOP_BAR_TYPES.has(arm.highway_type):
			continue
		
		
		
		var d := arm.trim - STOP_BAR_INSET
		if d <= 0.1:
			continue
		var centre := arm.point_at(junction.center, d)
		
		
		
		var fwd := arm.dir_at(d)

		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		var lat := arm.lateral_at(d) * -region.lateral_sign()
		var inner := centre                              
		var outer := centre + lat * arm.half_width       
		var half_depth := STOP_BAR_DEPTH * 0.5
		var back := fwd * half_depth

		if region.give_way_style == RoadRegion.GiveWayStyle.SHARK_TEETH:
			_add_shark_teeth(st, inner, outer, fwd, half_depth)
		else:
			var p0 := inner - back
			var p1 := outer - back
			var p2 := outer + back
			var p3 := inner + back
			_add_flat_quad(st, p0, p1, p2, p3, CAP_Y + PAINT_Y)
		emitted = true
	return emitted













func _yielding_arms(arms: Array[RoadJunctionSolverScript.Arm]) -> Array[bool]:
	var out: Array[bool] = []
	var top := -1
	for arm: RoadJunctionSolverScript.Arm in arms:
		top = maxi(top, _class_rank(arm.highway_type))
	for arm: RoadJunctionSolverScript.Arm in arms:
		out.append(_class_rank(arm.highway_type) + YIELD_RANK_MARGIN <= top)
	return out



func _class_rank(highway_type: String) -> int:
	return int(CLASS_RANK.get(highway_type, DEFAULT_CLASS_RANK))











func _add_shark_teeth(
		st: SurfaceTool, inner: Vector3, outer: Vector3, fwd: Vector3,
		half_depth: float) -> void:
	var across := outer - inner
	var span := across.length()
	if span < 0.01:
		return
	var across_dir := across / span
	
	
	
	var pitch := SHARK_TOOTH_BASE + SHARK_TOOTH_GAP
	var count: int = maxi(1, int(floor(span / pitch)))
	var step := span / float(count)
	var base_w: float = minf(SHARK_TOOTH_BASE, step * 0.75)

	
	
	var base_off := fwd * -half_depth
	var apex_off := fwd * half_depth
	for i: int in range(count):
		var c := inner + across_dir * (step * (float(i) + 0.5))
		var half_base := across_dir * (base_w * 0.5)
		var b0 := c - half_base + base_off
		var b1 := c + half_base + base_off
		var apex := c + apex_off
		_add_flat_tri_up(st, b0, b1, apex, CAP_Y + PAINT_Y)



func _add_flat_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, y_offset: float) -> void:
	_add_flat_tri(st, a, c, b, y_offset)
	_add_flat_tri(st, a, d, c, y_offset)










func _add_flat_tri_up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		y_offset: float) -> void:
	var up := _wound_upward(a, b, c)
	_add_flat_tri(
		st,
		Vector3(up[0].x, 0.0, up[0].y),
		Vector3(up[1].x, 0.0, up[1].y),
		Vector3(up[2].x, 0.0, up[2].y),
		y_offset)










func _emit_kerb_corners(
		st: SurfaceTool, junction: RoadJunctionSolverScript.Junction,
		sidewalk_lookup: Dictionary) -> bool:
	var arms := junction.arms
	var count := arms.size()
	if count < RoadJunctionSolverScript.MIN_ARMS:
		return false

	var emitted := false
	for i: int in range(count):
		var a: RoadJunctionSolverScript.Arm = arms[i]
		var b: RoadJunctionSolverScript.Arm = arms[(i + 1) % count]
		
		
		
		
		
		
		
		
		
		
		if not _arm_side_has_kerb(a, sidewalk_lookup, true):
			continue
		if not _arm_side_has_kerb(b, sidewalk_lookup, false):
			continue
		if _emit_one_corner(st, junction, a, b):
			emitted = true
	return emitted








func _arm_side_has_kerb(
		arm: RoadJunctionSolverScript.Arm, sidewalk_lookup: Dictionary,
		want_right: bool) -> bool:
	var sides: Dictionary = sidewalk_lookup.get(arm.way_id, {})
	if sides.is_empty():
		return false
	
	
	var side_is_right := want_right if arm.at_way_start else not want_right
	return bool(sides.get("right" if side_is_right else "left", false))



func _emit_one_corner(
		st: SurfaceTool, junction: RoadJunctionSolverScript.Junction,
		a: RoadJunctionSolverScript.Arm, b: RoadJunctionSolverScript.Arm) -> bool:
	var centre := junction.center

	
	
	
	
	
	
	var a_mouth := a.point_at(centre, a.trim)
	var b_mouth := b.point_at(centre, b.trim)
	var a_dir := a.dir_at(a.trim)
	var b_dir := b.dir_at(b.trim)
	var a_inner := a_mouth + a.lateral_at(a.trim) * a.half_width   
	var b_inner := b_mouth - b.lateral_at(b.trim) * b.half_width   

	
	
	
	
	
	
	
	
	
	
	var corner := _kerb_lines_meet(a_inner, a_dir, b_inner, b_dir)
	var inner_pts := _bezier_arc(a_inner, corner, b_inner, KERB_CORNER_SEGMENTS)
	if inner_pts.size() < 2:
		return false

	
	
	
	
	var depth := RoadProfileScript.SIDEWALK_WIDTH
	var outer_pts := _offset_curve_outward(inner_pts, centre, depth)

	var kerb_h := RoadProfileScript.SIDEWALK_HEIGHT
	
	
	
	var n := inner_pts.size()
	for i: int in range(n - 1):
		var h0 := _ramp_height(i, n, kerb_h)
		var h1 := _ramp_height(i + 1, n, kerb_h)

		var i0 := inner_pts[i]
		var i1 := inner_pts[i + 1]
		var o0 := outer_pts[i]
		var o1 := outer_pts[i + 1]

		
		_add_raised_quad(st, i0, i1, o1, o0, h0, h1, h1, h0)
		
		_add_kerb_face(st, i0, i1, h0, h1)
	return true




func _ramp_height(i: int, n: int, full_height: float) -> float:
	if n <= 2:
		return full_height
	
	var ramp := maxi(1, int(round(float(n) * 0.34)))
	var from_start := i
	var from_end := (n - 1) - i
	var edge_dist := mini(from_start, from_end)
	if edge_dist >= ramp:
		return full_height
	return full_height * (float(edge_dist) / float(ramp))









func _kerb_lines_meet(
		a_point: Vector3, a_dir: Vector3,
		b_point: Vector3, b_dir: Vector3) -> Vector3:
	var denom := a_dir.x * b_dir.z - a_dir.z * b_dir.x
	if absf(denom) < 0.0001:
		return a_point.lerp(b_point, 0.5)
	var dx := b_point.x - a_point.x
	var dz := b_point.z - a_point.z
	var t := (dx * b_dir.z - dz * b_dir.x) / denom
	
	
	
	var span := Vector2(a_point.x - b_point.x, a_point.z - b_point.z).length()
	t = clampf(t, -span * 2.0, span * 2.0)
	return Vector3(a_point.x + a_dir.x * t, a_point.y, a_point.z + a_dir.z * t)





func _bezier_arc(
		from: Vector3, control: Vector3, to: Vector3,
		segments: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var steps: int = maxi(segments, 1)
	for s: int in range(steps + 1):
		var t := float(s) / float(steps)
		var inv := 1.0 - t
		
		var w0 := inv * inv
		var w1 := 2.0 * inv * t
		var w2 := t * t
		out.append(Vector3(
			from.x * w0 + control.x * w1 + to.x * w2,
			from.y,
			from.z * w0 + control.z * w1 + to.z * w2))
	return out








func _offset_curve_outward(
		curve: PackedVector3Array, centre: Vector3,
		depth: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := curve.size()
	for i: int in range(n):
		
		var prev: Vector3 = curve[maxi(i - 1, 0)]
		var next: Vector3 = curve[mini(i + 1, n - 1)]
		var tangent := Vector3(next.x - prev.x, 0.0, next.z - prev.z)
		if tangent.length_squared() < 0.000001:
			tangent = Vector3(1.0, 0.0, 0.0)
		tangent = tangent.normalized()
		var normal := Vector3(-tangent.z, 0.0, tangent.x)
		
		var p: Vector3 = curve[i]
		var to_centre := Vector3(centre.x - p.x, 0.0, centre.z - p.z)
		if normal.dot(to_centre) > 0.0:
			normal = -normal
		out.append(Vector3(
			p.x + normal.x * depth, p.y, p.z + normal.z * depth))
	return out





func _arc_between(
		from: Vector3, to: Vector3, centre: Vector3,
		segments: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var v0 := Vector3(from.x - centre.x, 0.0, from.z - centre.z)
	var v1 := Vector3(to.x - centre.x, 0.0, to.z - centre.z)
	var r0 := v0.length()
	var r1 := v1.length()
	if r0 < 0.001 or r1 < 0.001:
		out.append(from)
		out.append(to)
		return out

	var a0 := atan2(v0.z, v0.x)
	var a1 := atan2(v1.z, v1.x)
	var delta := fposmod(a1 - a0, TAU)
	if delta > PI:
		
		
		out.append(from)
		out.append(to)
		return out

	var steps: int = maxi(segments, 1)
	for s: int in range(steps + 1):
		var t := float(s) / float(steps)
		var ang := a0 + delta * t
		var rad: float = lerpf(r0, r1, t)
		out.append(Vector3(
			centre.x + cos(ang) * rad, centre.y, centre.z + sin(ang) * rad))
	return out



func _add_raised_quad(
		st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ha: float, hb: float, hc: float, hd: float) -> void:
	var va := Vector3(a.x, _height_at(a.x, a.z) + ha, a.z)
	var vb := Vector3(b.x, _height_at(b.x, b.z) + hb, b.z)
	var vc := Vector3(c.x, _height_at(c.x, c.z) + hc, c.z)
	var vd := Vector3(d.x, _height_at(d.x, d.z) + hd, d.z)
	PolygonUtils.add_quad_facing(st, va, vb, vc, vd, Vector3.UP)





func _add_kerb_face(
		st: SurfaceTool, p0: Vector3, p1: Vector3,
		h0: float, h1: float) -> void:
	if h0 <= 0.001 and h1 <= 0.001:
		return
	var base0 := Vector3(p0.x, _height_at(p0.x, p0.z), p0.z)
	var base1 := Vector3(p1.x, _height_at(p1.x, p1.z), p1.z)
	var top0 := Vector3(base0.x, base0.y + h0, base0.z)
	var top1 := Vector3(base1.x, base1.y + h1, base1.z)
	
	var outward := (p1 - p0).cross(Vector3.UP).normalized()
	PolygonUtils.add_quad_facing(st, base0, base1, top1, top0, outward)
