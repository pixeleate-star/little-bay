class_name RoofGeometry
extends RefCounted













const BUILDING_Y := 0.0




static func new_st(color: Color) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	st.set_material(mat)
	return st


static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	PolygonUtils.add_tri(st, a, b, c)


static func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	add_tri(st, a, b, c)
	add_tri(st, a, c, d)


static func make_mesh(st: SurfaceTool, name_str: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_str
	mi.mesh = BuildingSurfaceUV.commit(st, mi)
	return mi







static func get_ridge_dir(points: PackedVector3Array, orientation: String, roof_direction: float = -1.0) -> Vector3:
	if roof_direction >= 0.0:
		var d_rad := deg_to_rad(roof_direction)
		
		
		
		return Vector3(cos(d_rad), 0.0, sin(d_rad)).normalized()
	var longest := PolygonUtils.polygon_longest_edge_dir(points)
	if orientation == "across":
		return Vector3(-longest.z, 0.0, longest.x)
	return longest


static func get_perp_dir(ridge_dir: Vector3) -> Vector3:
	return Vector3(-ridge_dir.z, 0.0, ridge_dir.x)




static func compute_ridge_geometry(points: PackedVector3Array, base_y: float, roof_h: float,
		orientation: String, roof_direction: float = -1.0) -> Dictionary:
	var ridge_dir := get_ridge_dir(points, orientation, roof_direction)
	var perp_dir := get_perp_dir(ridge_dir)
	var centroid := PolygonUtils.polygon_centroid(points)

	var min_proj := INF
	var max_proj := -INF
	var min_perp := INF
	var max_perp := -INF

	for p: Vector3 in points:
		var proj := PolygonUtils.project_xz(p, centroid, ridge_dir)
		var perp := PolygonUtils.project_xz(p, centroid, perp_dir)
		min_proj = min(min_proj, proj)
		max_proj = max(max_proj, proj)
		min_perp = min(min_perp, perp)
		max_perp = max(max_perp, perp)

	var ridge_y := base_y + roof_h
	var ridge_start := centroid + ridge_dir * min_proj
	ridge_start.y = ridge_y
	var ridge_end := centroid + ridge_dir * max_proj
	ridge_end.y = ridge_y

	return {
		"ridge_dir": ridge_dir,
		"perp_dir": perp_dir,
		"centroid": centroid,
		"min_proj": min_proj,
		"max_proj": max_proj,
		"min_perp": min_perp,
		"max_perp": max_perp,
		"ridge_start": ridge_start,
		"ridge_end": ridge_end,
		"ridge_y": ridge_y,
		"base_y": base_y,
	}





static func sample_profile(profile: Array[Vector2], x: float) -> float:
	if profile.is_empty():
		return 0.0
	if x <= profile[0].x:
		return profile[0].y
	for i: int in range(profile.size() - 1):
		if x <= profile[i + 1].x:
			var t := (x - profile[i].x) / maxf(profile[i + 1].x - profile[i].x, 0.001)
			return lerpf(profile[i].y, profile[i + 1].y, t)
	return profile[profile.size() - 1].y





static func subdivide_at_profile_breaks(points: PackedVector3Array, centroid: Vector3,
		perp_dir: Vector3, min_perp: float, perp_span: float,
		break_xs: Array[float]) -> PackedVector3Array:
	if break_xs.is_empty() or perp_span < 0.001:
		return points

	
	var break_perps: Array[float] = []
	for bx: float in break_xs:
		break_perps.append(min_perp + bx * perp_span)

	var result: PackedVector3Array = []
	var n := points.size()
	for i: int in range(n - 1):
		var p0 := points[i]
		var p1 := points[i + 1]
		result.append(p0)

		var perp0 := PolygonUtils.project_xz(p0, centroid, perp_dir)
		var perp1 := PolygonUtils.project_xz(p1, centroid, perp_dir)

		
		var crossings: Array[float] = []
		for bp: float in break_perps:
			if (perp0 < bp - 0.001 and bp + 0.001 < perp1) or (perp1 < bp - 0.001 and bp + 0.001 < perp0):
				crossings.append(bp)

		
		if crossings.size() > 1:
			if perp0 > perp1:
				crossings.sort()
				crossings.reverse()
			else:
				crossings.sort()

		
		for bp: float in crossings:
			var t := (bp - perp0) / (perp1 - perp0)
			var px := p0.x + (p1.x - p0.x) * t
			var pz := p0.z + (p1.z - p0.z) * t
			result.append(Vector3(px, 0.0, pz))

	
	if n > 0:
		result.append(points[n - 1])
	return result
