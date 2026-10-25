class_name RoofSpecial
extends RefCounted








static func flat(points: PackedVector3Array, base_y: float, color: Color) -> Array[Node3D]:
	var mi := PolygonUtils.build_flat_polygon_mesh(points, color, base_y, false, PolygonUtils.GROUND_NO_PRIORITY, true)
	if mi != null:
		mi.name = "Roof"
		return [mi]
	return []



static func skillion(points: PackedVector3Array, base_y: float, roof_h: float,
		roof_color: Color, wall_color: Color, orientation: String,
		roof_direction: float = -1.0) -> Array[Node3D]:
	var rg := RoofGeometry.compute_ridge_geometry(points, base_y, roof_h, orientation, roof_direction)
	var perp_dir: Vector3 = rg["perp_dir"]
	var centroid: Vector3 = rg["centroid"]
	var min_perp: float = rg["min_perp"]
	var perp_span := absf(float(rg["max_perp"]) - min_perp)

	
	var roof_points: PackedVector3Array = []
	for p: Vector3 in points:
		var perp := PolygonUtils.project_xz(p, centroid, perp_dir)
		var t := clampf((perp - min_perp) / maxf(perp_span, 0.001), 0.0, 1.0)
		roof_points.append(Vector3(p.x, base_y + roof_h * t, p.z))

	
	var st_roof := RoofGeometry.new_st(roof_color)
	var indices := PolygonUtils.triangulate_xz(roof_points)
	if indices.size() > 0:
		for idx: int in range(0, indices.size(), 3):
			RoofGeometry.add_tri(st_roof, roof_points[indices[idx]], roof_points[indices[idx + 1]], roof_points[indices[idx + 2]])

	
	
	var st_wall := RoofGeometry.new_st(wall_color)
	for i: int in range(points.size() - 1):
		var y0 := roof_points[i].y
		var y1 := roof_points[i + 1].y
		if y0 > base_y + 0.01 or y1 > base_y + 0.01:
			var wall_bl := Vector3(points[i].x, base_y, points[i].z)
			var wall_br := Vector3(points[i + 1].x, base_y, points[i + 1].z)
			var wall_tr := Vector3(points[i + 1].x, y1, points[i + 1].z)
			var wall_tl := Vector3(points[i].x, y0, points[i].z)

			if y0 <= base_y + 0.01:
				RoofGeometry.add_tri(st_wall, wall_bl, wall_tr, wall_br)
			elif y1 <= base_y + 0.01:
				RoofGeometry.add_tri(st_wall, wall_bl, wall_tl, wall_br)
			else:
				RoofGeometry.add_tri(st_wall, wall_bl, wall_tr, wall_br)
				RoofGeometry.add_tri(st_wall, wall_bl, wall_tl, wall_tr)

	var result: Array[Node3D] = []
	result.append(RoofGeometry.make_mesh(st_roof, "Roof"))
	result.append(RoofGeometry.make_mesh(st_wall, "SkillionWalls"))
	return result




static func sawtooth(points: PackedVector3Array, base_y: float, roof_h: float,
		roof_color: Color, wall_color: Color, orientation: String,
		roof_direction: float = -1.0) -> Array[Node3D]:
	var rg := RoofGeometry.compute_ridge_geometry(points, base_y, roof_h, orientation, roof_direction)
	var min_perp: float = rg["min_perp"]
	var perp_span := absf(float(rg["max_perp"]) - min_perp)

	var tooth_count := maxi(int(perp_span / 4.0), 2)  
	var tooth_width := perp_span / tooth_count

	var st_roof := RoofGeometry.new_st(roof_color)
	var st_wall := RoofGeometry.new_st(wall_color)

	
	
	_build_sawtooth_roof_surface(st_roof, st_wall, wall_color, points, base_y, roof_h, rg, min_perp, perp_span, tooth_count, tooth_width)

	
	_add_sawtooth_end_walls(st_wall, points, base_y, roof_h, rg, min_perp, perp_span, tooth_count, tooth_width)

	var result: Array[Node3D] = []
	result.append(RoofGeometry.make_mesh(st_roof, "Roof"))
	result.append(RoofGeometry.make_mesh(st_wall, "SawtoothWalls"))
	return result

static func _build_sawtooth_roof_surface(st_roof: SurfaceTool, st_wall: SurfaceTool,
		_wall_color: Color, _points: PackedVector3Array, base_y: float, roof_h: float,
		rg: Dictionary, min_perp: float, _perp_span: float,
		tooth_count: int, tooth_width: float) -> void:
	var ridge_dir: Vector3 = rg["ridge_dir"]
	var perp_dir: Vector3 = rg["perp_dir"]
	var centroid: Vector3 = rg["centroid"]
	var min_proj: float = rg["min_proj"]
	var max_proj: float = rg["max_proj"]

	
	
	
	for tooth: int in range(tooth_count):
		var ts_perp := min_perp + tooth * tooth_width
		var te_perp := min_perp + (tooth + 1) * tooth_width

		
		
		var near_start := centroid + ridge_dir * min_proj + perp_dir * ts_perp
		var near_end := centroid + ridge_dir * min_proj + perp_dir * te_perp
		var far_start := centroid + ridge_dir * max_proj + perp_dir * ts_perp
		var far_end := centroid + ridge_dir * max_proj + perp_dir * te_perp

		
		var ramp_ns := Vector3(near_start.x, base_y, near_start.z)
		var ramp_ne := Vector3(near_end.x, base_y + roof_h, near_end.z)
		var ramp_fs := Vector3(far_start.x, base_y, far_start.z)
		var ramp_fe := Vector3(far_end.x, base_y + roof_h, far_end.z)

		
		RoofGeometry.add_quad(st_roof, ramp_ns, ramp_fs, ramp_fe, ramp_ne)

		
		if tooth < tooth_count - 1:
			
			var drop_near_top := Vector3(near_end.x, base_y + roof_h, near_end.z)
			var drop_near_bot := Vector3(near_end.x, base_y, near_end.z)
			var drop_far_top := Vector3(far_end.x, base_y + roof_h, far_end.z)
			var drop_far_bot := Vector3(far_end.x, base_y, far_end.z)

			
			RoofGeometry.add_quad(st_wall, drop_near_top, drop_far_top, drop_far_bot, drop_near_bot)

static func _add_sawtooth_end_walls(st: SurfaceTool, points: PackedVector3Array,
		base_y: float, roof_h: float, rg: Dictionary, min_perp: float,
		_perp_span: float, tooth_count: int, tooth_width: float) -> void:
	var ridge_dir: Vector3 = rg["ridge_dir"]
	var perp_dir: Vector3 = rg["perp_dir"]
	var centroid: Vector3 = rg["centroid"]
	var min_proj: float = rg["min_proj"]
	var max_proj: float = rg["max_proj"]
	var proj_span := max_proj - min_proj
	var threshold := proj_span * 0.05

	for end_proj: float in [min_proj, max_proj]:
		
		var end_verts: Array[Vector3] = []
		for i: int in range(points.size() - 1):
			var proj := PolygonUtils.project_xz(points[i], centroid, ridge_dir)
			if absf(proj - end_proj) < threshold + 0.5:
				end_verts.append(points[i])

		if end_verts.size() < 2:
			continue

		
		var pd := perp_dir
		end_verts.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return PolygonUtils.project_xz(a, centroid, pd) < PolygonUtils.project_xz(b, centroid, pd))
		var left := end_verts[0]
		var right := end_verts[end_verts.size() - 1]

		
		
		var left_perp := PolygonUtils.project_xz(left, centroid, perp_dir)
		var right_perp := PolygonUtils.project_xz(right, centroid, perp_dir)
		var edge_start := Vector3(left.x, 0, left.z)
		var edge_end := Vector3(right.x, 0, right.z)
		var edge_len := right_perp - left_perp
		if absf(edge_len) < 0.001:
			continue

		
		for tooth: int in range(tooth_count):
			
			var tooth_start_perp := min_perp + tooth * tooth_width
			var tooth_end_perp := min_perp + (tooth + 1) * tooth_width

			
			var ts_perp := clampf(tooth_start_perp, left_perp, right_perp)
			var te_perp := clampf(tooth_end_perp, left_perp, right_perp)
			if te_perp - ts_perp < 0.001:
				continue

			
			var ts_frac := (ts_perp - left_perp) / edge_len
			var te_frac := (te_perp - left_perp) / edge_len
			var ts_xz := edge_start.lerp(edge_end, ts_frac)
			var te_xz := edge_start.lerp(edge_end, te_frac)

			
			var bl := Vector3(ts_xz.x, base_y, ts_xz.z)
			var br := Vector3(te_xz.x, base_y, te_xz.z)

			
			var tr_v := Vector3(te_xz.x, base_y + roof_h, te_xz.z)

			
			
			if end_proj == min_proj:
				RoofGeometry.add_tri(st, br, bl, tr_v)
			else:
				RoofGeometry.add_tri(st, bl, br, tr_v)
