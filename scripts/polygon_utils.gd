class_name PolygonUtils
extends RefCounted

const TERRAIN_SHADER: Shader = preload("res://scripts/shaders/terrain.gdshader")
const JAM_DARK := Color("2d272f")
const JAM_GREEN := Color("6ea16e")
const JAM_TEAL := Color("009b88")
const JAM_MAUVE := Color("8f5676")
const JAM_BLUE := Color("415d99")



const AREA_COLORS := {
	"landuse": {
		"residential": JAM_GREEN,
		"industrial": JAM_TEAL,
		"commercial": JAM_MAUVE,
		"farmland": JAM_GREEN,
		"forest": JAM_GREEN,
		"grass": JAM_GREEN,
	},
	"natural": {
		"water": JAM_BLUE,
		"wood": JAM_TEAL,
		"scrub": JAM_GREEN,
	},
	"leisure": {
		"park": JAM_GREEN,
		"pitch": JAM_TEAL,
		"playground": JAM_MAUVE,
	},
	"tourism": {
		"camp_site": Color(0.45, 0.65, 0.35),         
		"caravan_site": Color(0.5, 0.62, 0.4),
		"chalet": Color(0.6, 0.55, 0.45),             
	},
	"playground": {
		
		
		
		"climbingframe": Color(0.7, 0.6, 0.35),
		"structure": Color(0.7, 0.6, 0.35),
		"sandpit": Color(0.85, 0.78, 0.55),
	},
	"amenity": {
		"parking": JAM_DARK,
		"bicycle_parking": Color(0.5, 0.5, 0.55),
		"motorcycle_parking": Color(0.5, 0.5, 0.55),
		"school": Color(0.85, 0.78, 0.6),             
		"university": Color(0.82, 0.75, 0.6),
		"kindergarten": Color(0.9, 0.82, 0.6),
		"fire_station": Color(0.7, 0.4, 0.35),        
		"hospital": Color(0.85, 0.7, 0.7),
		"college": Color(0.82, 0.75, 0.6),
	},
	"shop": {
		"supermarket": Color(0.7, 0.6, 0.7),
	},
	"power": {
		"generator": Color(0.45, 0.45, 0.5),
	},
	"man_made": {
		"wastewater_plant": Color(0.5, 0.52, 0.55),   
		"water_works": Color(0.5, 0.52, 0.55),
		"works": Color(0.55, 0.5, 0.48),              
		"reservoir_covered": Color(0.45, 0.5, 0.55),
		"storage_tank": Color(0.55, 0.55, 0.58),
		"wastewater": Color(0.5, 0.52, 0.55),
		"reinforced_slope": Color(0.52, 0.50, 0.46),  
		"pier": Color(0.62, 0.58, 0.5),               
		"bunker_silo": Color(0.55, 0.55, 0.55),       
	},
	"historic": {
		"fort": Color(0.45, 0.55, 0.35),              
		"citadel": Color(0.45, 0.55, 0.35),
		"castle": Color(0.55, 0.52, 0.48),            
		"archaeological_site": Color(0.55, 0.50, 0.42),
	},
	"area:highway": {
		"traffic_island": Color(0.6, 0.6, 0.58),
	},
}

const DEFAULT_AREA_COLOR := Color(0.3, 0.6, 0.3)



const LOW_GRASS_DENSITY := 0.16
const LOW_GRASS_MAX_INSTANCES := 220
const LOW_GRASS_COLORS: Array[Color] = [
	Color(0.16, 0.34, 0.10), Color(0.22, 0.45, 0.13), Color(0.30, 0.52, 0.16)
]
static var _low_grass_mesh: CylinderMesh = null


static func get_area_color(tags: Dictionary) -> Color:
	for category: String in AREA_COLORS:
		if tags.has(category):
			var value: String = tags[category]
			var sub: Dictionary = AREA_COLORS[category]
			if sub.has(value):
				return sub[value]
			return DEFAULT_AREA_COLOR
	return DEFAULT_AREA_COLOR


static func build_low_grass_area(
		points: PackedVector3Array,
		hp: HeightProvider,
		clip_rect: Variant = null,
) -> Node3D:
	if points.size() < 3:
		return null
	var samples := _scatter_points_in_polygon(points, hp, LOW_GRASS_DENSITY, clip_rect)
	if samples.is_empty():
		return null
	if samples.size() > LOW_GRASS_MAX_INSTANCES:
		samples = samples.slice(0, LOW_GRASS_MAX_INSTANCES)
	if _low_grass_mesh == null:
		_low_grass_mesh = CylinderMesh.new()
		_low_grass_mesh.top_radius = 0.025
		_low_grass_mesh.bottom_radius = 0.09
		_low_grass_mesh.height = 0.28
		_low_grass_mesh.radial_segments = 4
		_low_grass_mesh.rings = 1
		var grass_mat := StandardMaterial3D.new()
		grass_mat.vertex_color_use_as_albedo = true
		grass_mat.roughness = 1.0
		_low_grass_mesh.material = grass_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = samples.size()
	mm.mesh = _low_grass_mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2(points[0].x, points[0].z)) + 707
	for i: int in range(samples.size()):
		var p: Vector3 = samples[i]
		var scale := rng.randf_range(0.65, 1.25)
		var transform := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)))
		transform = transform.scaled(Vector3(scale, scale, scale))
		transform.origin = p + Vector3(0.0, 0.14 * scale, 0.0)
		mm.set_instance_transform(i, transform)
		mm.set_instance_color(i, LOW_GRASS_COLORS[rng.randi() % LOW_GRASS_COLORS.size()])
	var node := MultiMeshInstance3D.new()
	node.name = "LowGrass"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node




















const GROUND_LAYER_PRIORITY := {
	
	"landuse=forest": -40,
	"natural=wood": -40,
	"landuse=farmland": -39,
	"landuse=meadow": -38,
	"landuse=grass": -37,
	"natural=scrub": -37,
	"landuse=residential": -36,
	"landuse=commercial": -36,
	"landuse=industrial": -36,
	
	"leisure=park": -34,
	"leisure=garden": -34,
	"leisure=nature_reserve": -35,
	
	"natural=water": -30,
	"natural=wetland": -31,
	"natural=beach": -29,
	
	"leisure=pitch": -20,
	"leisure=playground": -19,
	"playground=*": -19,
	"amenity=school": -22,
	"amenity=university": -22,
	"amenity=college": -22,
	"amenity=hospital": -22,
	"amenity=parking": -12,
	"amenity=bicycle_parking": -12,
	"amenity=motorcycle_parking": -12,
	"area:highway=*": -10,
}

const DEFAULT_GROUND_PRIORITY := -33




const SURFACE_GROUND_PRIORITY := -14



const PLATFORM_GROUND_PRIORITY := -6




const GROUND_NO_PRIORITY := 127

static var _flat_materials: Dictionary = {}





static func _flat_material(color: Color, render_priority: int) -> Material:
	var key := [color, render_priority]
	if not _flat_materials.has(key):
		var mat: Material
		
		
		if color.g > color.r * 1.2 and color.g > color.b * 1.1:
			var grass_mat := ShaderMaterial.new()
			grass_mat.shader = TERRAIN_SHADER
			grass_mat.set_shader_parameter("base_color", JAM_GREEN)
			grass_mat.set_shader_parameter("patch_color", JAM_TEAL)
			mat = grass_mat
		else:
			var flat_mat := StandardMaterial3D.new()
			flat_mat.albedo_color = color
			mat = flat_mat
		_apply_ground_layering(mat, render_priority)
		_flat_materials[key] = mat
	return _flat_materials[key]






static func _apply_ground_layering(mat: Material, render_priority: int) -> void:
	if render_priority == GROUND_NO_PRIORITY:
		return
	if mat is BaseMaterial3D:
		var base_mat := mat as BaseMaterial3D
		base_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		base_mat.render_priority = clampi(render_priority, -128, 127)






const _GROUND_TIEBREAK_SPAN := 0.9


const _GROUND_TIEBREAK_REF_AREA := 40000.0  




static func ground_base_priority(tags: Dictionary) -> int:
	for category: String in AREA_COLORS:
		if tags.has(category):
			var value: String = tags[category]
			var exact := "%s=%s" % [category, value]
			if GROUND_LAYER_PRIORITY.has(exact):
				return GROUND_LAYER_PRIORITY[exact]
			var wild := "%s=*" % category
			if GROUND_LAYER_PRIORITY.has(wild):
				return GROUND_LAYER_PRIORITY[wild]
			return DEFAULT_GROUND_PRIORITY
	return DEFAULT_GROUND_PRIORITY





static func ground_tiebreak_bonus(area_xz: float) -> float:
	if area_xz <= 0.0:
		return _GROUND_TIEBREAK_SPAN
	
	var t := clampf(area_xz / _GROUND_TIEBREAK_REF_AREA, 0.0, 1.0)
	return (1.0 - t) * _GROUND_TIEBREAK_SPAN







static func ground_render_priority(tags: Dictionary, area_xz: float) -> float:
	return float(ground_base_priority(tags)) + ground_tiebreak_bonus(area_xz)


static func way_to_points(way_node_ids: Array[int], osm_data_nodes: Dictionary) -> PackedVector3Array:
	var points: PackedVector3Array = []
	for nid: int in way_node_ids:
		if osm_data_nodes.has(nid):
			points.append(osm_data_nodes[nid].local_pos)
	return points



static func triangulate_xz(points: PackedVector3Array) -> PackedInt32Array:
	var pts_2d: PackedVector2Array = []
	for p: Vector3 in points:
		pts_2d.append(Vector2(p.x, p.z))
	return Geometry2D.triangulate_polygon(pts_2d)















static func build_flat_polygon_mesh(
		points: PackedVector3Array,
		color: Color,
		y: float = 0.01,
		drape_terrain: bool = false,
		render_priority: int = GROUND_NO_PRIORITY,
		keep_cpu_copy: bool = false,
) -> MeshInstance3D:
	if points.size() < 3:
		return null

	var indices := triangulate_xz(points)
	if indices.size() == 0:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	st.set_material(_flat_material(color, render_priority))

	for i: int in range(indices.size()):
		var idx: int = indices[i]
		var vy: float = (points[idx].y + y) if drape_terrain else y
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(points[idx].x, vy, points[idx].z))

	var mesh_instance := MeshInstance3D.new()
	if keep_cpu_copy:
		mesh_instance.mesh = BuildingSurfaceUV.commit(st, mesh_instance)
	else:
		mesh_instance.mesh = st.commit()
	return mesh_instance


static func is_polygon_ccw(points: PackedVector3Array) -> bool:
	var signed_area := 0.0
	for i: int in range(points.size() - 1):
		signed_area += points[i].x * points[i + 1].z - points[i + 1].x * points[i].z
	return signed_area < 0.0



static func reverse_polygon(points: PackedVector3Array) -> PackedVector3Array:
	var count := points.size()
	var closed := count > 1 and points[0].distance_to(points[count - 1]) < 0.01
	var inner_count := count - 1 if closed else count
	var result: PackedVector3Array = []
	for i: int in range(inner_count - 1, -1, -1):
		result.append(points[i])
	if closed and result.size() > 0:
		result.append(result[0])
	return result




static func normalize_to_ccw(points: PackedVector3Array) -> PackedVector3Array:
	if is_polygon_ccw(points):
		return points
	return reverse_polygon(points)





static func tri_shading_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (b - a).cross(c - a)



static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := tri_shading_normal(a, b, c)
	if normal.length_squared() < 0.000001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)






static func add_quad_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, desired_normal: Vector3) -> void:
	
	
	var front_normal := -tri_shading_normal(a, b, c)
	if front_normal.dot(desired_normal) >= 0.0:
		_add_tri_with_normal(st, a, b, c, desired_normal)
		_add_tri_with_normal(st, a, c, d, desired_normal)
	else:
		_add_tri_with_normal(st, a, c, b, desired_normal)
		_add_tri_with_normal(st, a, d, c, desired_normal)



static func _add_tri_with_normal(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)






static func add_tube_segment(st: SurfaceTool, p0: Vector3, p1: Vector3, radius: float) -> void:
	var dir := (p1 - p0)
	if dir.length_squared() < 0.000001:
		return
	dir = dir.normalized()
	
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var side := dir.cross(up).normalized() * radius
	var vert := dir.cross(side).normalized() * radius
	var ring0: Array[Vector3] = [p0 + side, p0 + vert, p0 - side, p0 - vert]
	var ring1: Array[Vector3] = [p1 + side, p1 + vert, p1 - side, p1 - vert]
	for k: int in range(4):
		var n := (k + 1) % 4
		var outward: Vector3 = ((ring0[k] - p0) + (ring1[k] - p1)).normalized()
		add_quad_facing(st, ring0[k], ring0[n], ring1[n], ring1[k], outward)


static func polygon_centroid(points: PackedVector3Array) -> Vector3:
	var cx := 0.0
	var cz := 0.0
	var count := points.size()
	
	if count > 1 and points[0].distance_to(points[count - 1]) < 0.01:
		count -= 1
	if count == 0:
		return Vector3.ZERO
	for i: int in range(count):
		cx += points[i].x
		cz += points[i].z
	return Vector3(cx / count, 0.0, cz / count)




static func polygon_area_xz(points: PackedVector3Array) -> float:
	var count := points.size()
	
	if count > 1 and points[0].distance_to(points[count - 1]) < 0.01:
		count -= 1
	if count < 3:
		return 0.0
	var signed_area := 0.0
	for i: int in range(count):
		var a := points[i]
		var b := points[(i + 1) % count]
		signed_area += a.x * b.z - b.x * a.z
	return absf(signed_area) * 0.5


static func polygon_bounds_xz(points: PackedVector3Array) -> Array[float]:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p: Vector3 in points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_z = min(min_z, p.z)
		max_z = max(max_z, p.z)
	return [min_x, max_x, min_z, max_z]


static func polygon_longest_edge_dir(points: PackedVector3Array) -> Vector3:
	var best_len := 0.0
	var best_dir := Vector3(1, 0, 0)
	for i: int in range(points.size() - 1):
		var d := points[i + 1] - points[i]
		d.y = 0.0
		var l := d.length()
		if l > best_len:
			best_len = l
			best_dir = d / l
	return best_dir



static func shrink_polygon_xz(points: PackedVector3Array, amount: float) -> PackedVector3Array:
	var pts2d: PackedVector2Array = []
	var count := points.size()
	if count > 1 and points[0].distance_to(points[count - 1]) < 0.01:
		count -= 1
	for i: int in range(count):
		pts2d.append(Vector2(points[i].x, points[i].z))
	var result := Geometry2D.offset_polygon(pts2d, -amount)
	if result.size() == 0:
		return PackedVector3Array()
	var out: PackedVector3Array = []
	for p2: Vector2 in result[0]:
		out.append(Vector3(p2.x, 0.0, p2.y))
	
	if out.size() > 0:
		out.append(out[0])
	return out


static func project_xz(point: Vector3, origin: Vector3, direction: Vector3) -> float:
	return (point.x - origin.x) * direction.x + (point.z - origin.z) * direction.z























static func clip_polyline_to_rect(
		points: PackedVector3Array, rect: Array, margin: float = 0.0) -> Array:
	var out: Array = []
	if points.size() < 2:
		return out
	var min_x: float = rect[0] - margin
	var max_x: float = rect[1] + margin
	var min_z: float = rect[2] - margin
	var max_z: float = rect[3] + margin

	var current := PackedVector3Array()
	for i: int in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		
		
		var seg := _clip_segment_xz(a, b, min_x, max_x, min_z, max_z)
		if seg.is_empty():
			
			if current.size() >= 2:
				out.append(current)
			current = PackedVector3Array()
			continue
		var ca: Vector3 = seg[0]
		var cb: Vector3 = seg[1]
		
		if current.is_empty() or current[current.size() - 1].distance_to(ca) > 0.001:
			if current.size() >= 2:
				out.append(current)
			current = PackedVector3Array()
			current.append(ca)
		current.append(cb)
	if current.size() >= 2:
		out.append(current)
	return out




static func _clip_segment_xz(
		a: Vector3, b: Vector3, min_x: float, max_x: float,
		min_z: float, max_z: float) -> Array:
	var t0 := 0.0
	var t1 := 1.0
	var dx := b.x - a.x
	var dz := b.z - a.z
	
	var p := [-dx, dx, -dz, dz]
	var q := [a.x - min_x, max_x - a.x, a.z - min_z, max_z - a.z]
	for k: int in range(4):
		if absf(p[k]) < 0.000001:
			if q[k] < 0.0:
				return []  
			continue
		var r: float = q[k] / p[k]
		if p[k] < 0.0:
			t0 = maxf(t0, r)
		else:
			t1 = minf(t1, r)
		if t0 > t1:
			return []
	var ca := a.lerp(b, t0)
	var cb := a.lerp(b, t1)
	return [ca, cb]


static func subdivide_polyline_to_terrain(
		points: PackedVector3Array,
		hp: HeightProvider,
		max_step: float,
) -> PackedVector3Array:
	if points.size() < 2:
		return points
	if hp == null or not hp.is_ready():
		return points

	var result: PackedVector3Array = []
	
	
	
	
	result.append(Vector3(points[0].x, hp.sample_mesh_height(points[0].x, points[0].z), points[0].z))

	for i: int in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		
		var dx := b.x - a.x
		var dz := b.z - a.z
		var seg_len := sqrt(dx * dx + dz * dz)

		if seg_len <= max_step:
			
			result.append(Vector3(b.x, hp.sample_mesh_height(b.x, b.z), b.z))
		else:
			
			
			var n_sub := int(ceil(seg_len / max_step))
			for s: int in range(1, n_sub + 1):
				var t := float(s) / float(n_sub)
				var px := a.x + dx * t
				var pz := a.z + dz * t
				var py := hp.sample_mesh_height(px, pz)
				result.append(Vector3(px, py, pz))

	return result





























static func emit_terrain_conforming_quad(
		st: SurfaceTool,
		quad: PackedVector2Array,
		hp: HeightProvider,
		grid_step: float,
		y_offset: float,
		uv_fn: Callable = Callable(),
) -> void:
	if quad.size() < 3 or hp == null or not hp.is_ready() or grid_step <= 0.0:
		return
	var has_uv := uv_fn.is_valid()

	
	var minx := INF
	var maxx := -INF
	var minz := INF
	var maxz := -INF
	for p: Vector2 in quad:
		minx = minf(minx, p.x)
		maxx = maxf(maxx, p.x)
		minz = minf(minz, p.y)
		maxz = maxf(maxz, p.y)
	var cx0 := floori(minx / grid_step)
	var cx1 := floori(maxx / grid_step)
	var cz0 := floori(minz / grid_step)
	var cz1 := floori(maxz / grid_step)

	var quad_arr: Array[Vector2] = []
	for p: Vector2 in quad:
		quad_arr.append(p)

	for cx: int in range(cx0, cx1 + 1):
		for cz: int in range(cz0, cz1 + 1):
			var x0 := float(cx) * grid_step
			var z0 := float(cz) * grid_step
			var x1 := x0 + grid_step
			var z1 := z0 + grid_step
			
			
			
			var tri_a: Array[Vector2] = [
				Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1)
			]
			var tri_b: Array[Vector2] = [
				Vector2(x0, z0), Vector2(x1, z1), Vector2(x0, z1)
			]
			for tri: Array in [tri_a, tri_b]:
				var piece := _clip_poly_to_triangle(quad_arr, tri)
				if piece.size() < 3:
					continue
				
				var o := piece[0]
				var o3 := Vector3(o.x, hp.sample_mesh_height(o.x, o.y) + y_offset, o.y)
				var o_uv := (uv_fn.call(Vector2(o.x, o.y)) as Vector2) if has_uv else Vector2.ZERO
				for k: int in range(1, piece.size() - 1):
					var p1: Vector2 = piece[k]
					var p2: Vector2 = piece[k + 1]
					var v1 := Vector3(p1.x, hp.sample_mesh_height(p1.x, p1.y) + y_offset, p1.y)
					var v2 := Vector3(p2.x, hp.sample_mesh_height(p2.x, p2.y) + y_offset, p2.y)
					
					
					if has_uv:
						st.set_uv(o_uv)
					st.set_normal(Vector3.UP); st.add_vertex(o3)
					if has_uv:
						st.set_uv(uv_fn.call(Vector2(p2.x, p2.y)) as Vector2)
					st.set_normal(Vector3.UP); st.add_vertex(v2)
					if has_uv:
						st.set_uv(uv_fn.call(Vector2(p1.x, p1.y)) as Vector2)
					st.set_normal(Vector3.UP); st.add_vertex(v1)





static func _clip_poly_to_triangle(poly: Array[Vector2], tri: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = poly.duplicate()
	for e: int in range(3):
		if result.size() < 3:
			return []
		var p0: Vector2 = tri[e]
		var p1: Vector2 = tri[(e + 1) % 3]
		var third: Vector2 = tri[(e + 2) % 3]
		
		
		var edge := p1 - p0
		var nrm := Vector2(-edge.y, edge.x)
		var c := nrm.x * p0.x + nrm.y * p0.y
		if nrm.x * third.x + nrm.y * third.y - c > 0.0:
			nrm = -nrm
			c = -c
		result = _clip_poly_to_halfplane(result, nrm, c)
	return result



static func _clip_poly_to_halfplane(poly: Array[Vector2], n: Vector2, c: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cnt := poly.size()
	if cnt < 3:
		return out
	for i: int in range(cnt):
		var cur: Vector2 = poly[i]
		var nxt: Vector2 = poly[(i + 1) % cnt]
		var d_cur := n.x * cur.x + n.y * cur.y - c
		var d_nxt := n.x * nxt.x + n.y * nxt.y - c
		var cur_in := d_cur <= 1e-9
		var nxt_in := d_nxt <= 1e-9
		if cur_in:
			out.append(cur)
		if cur_in != nxt_in:
			var t := d_cur / (d_cur - d_nxt)
			out.append(cur.lerp(nxt, t))
	return out




















static func build_terrain_draped_mesh(
		points: PackedVector3Array,
		color: Color,
		hp: HeightProvider,
		grid_step: float,
		y_offset: float = 0.01,
		clip_rect: Variant = null,  
		render_priority: int = GROUND_NO_PRIORITY,
) -> MeshInstance3D:
	if points.size() < 3:
		return null
	if hp == null or not hp.is_ready():
		return build_flat_polygon_mesh(points, color, y_offset, true, render_priority)

	
	var poly_2d: PackedVector2Array = []
	var count := points.size()
	
	if count > 1 and points[0].distance_to(points[count - 1]) < 0.01:
		count -= 1
	for i: int in range(count):
		poly_2d.append(Vector2(points[i].x, points[i].z))

	
	
	
	var min_x: float
	var max_x: float
	var min_z: float
	var max_z: float
	if clip_rect != null:
		min_x = clip_rect[0]
		max_x = clip_rect[1]
		min_z = clip_rect[2]
		max_z = clip_rect[3]
	else:
		var bounds := polygon_bounds_xz(points)
		min_x = bounds[0]
		max_x = bounds[1]
		min_z = bounds[2]
		max_z = bounds[3]

	
	
	
	
	
	
	
	var poly_parts: Array = []
	if clip_rect != null:
		var tile_rect := PackedVector2Array([
			Vector2(min_x, min_z), Vector2(min_x, max_z),
			Vector2(max_x, max_z), Vector2(max_x, min_z),
		])
		poly_parts = Geometry2D.intersect_polygons(tile_rect, poly_2d)
		if poly_parts.is_empty():
			return null  
	else:
		poly_parts = [poly_2d]

	var grid_x0 := floorf(min_x / grid_step) * grid_step
	var grid_z0 := floorf(min_z / grid_step) * grid_step
	var grid_x1 := ceilf(max_x / grid_step) * grid_step
	var grid_z1 := ceilf(max_z / grid_step) * grid_step

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_flat_material(color, render_priority))

	var has_tris := false
	var cell_x := grid_x0
	while cell_x < grid_x1 - 0.001:
		var cell_z := grid_z0
		var next_x := cell_x + grid_step
		while cell_z < grid_z1 - 0.001:
			var next_z := cell_z + grid_step
			
			var cell_rect: PackedVector2Array = PackedVector2Array([
				Vector2(cell_x, cell_z),
				Vector2(cell_x, next_z),
				Vector2(next_x, next_z),
				Vector2(next_x, cell_z),
			])

			
			for part: PackedVector2Array in poly_parts:
				var clips := Geometry2D.intersect_polygons(cell_rect, part)
				for clip: PackedVector2Array in clips:
					var indices := Geometry2D.triangulate_polygon(clip)
					if indices.size() == 0:
						continue
					for idx: int in indices:
						var p2 := clip[idx]
						
						
						var wy := hp.sample_mesh_height(p2.x, p2.y) + y_offset
						st.set_normal(Vector3.UP)
						st.add_vertex(Vector3(p2.x, wy, p2.y))
						has_tris = true

			cell_z = next_z
		cell_x = next_x

	if not has_tris:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	return mesh_instance



static func is_scrub(tags: Dictionary) -> bool:
	return tags.get("natural", "") == "scrub"


static func is_forest(tags: Dictionary) -> bool:
	return tags.get("natural", "") == "wood" or tags.get("landuse", "") == "forest"





const FOREST_DENSITY := 0.05

const FOREST_TRUNK_MIN_H := 3.0
const FOREST_TRUNK_MAX_H := 6.0

const FOREST_TRUNK_RADIUS := 0.15

const FOREST_CROWN_MIN_R := 1.5
const FOREST_CROWN_MAX_R := 3.0

const FOREST_GROUND_COLOR := Color(0.12, 0.35, 0.08)

const FOREST_TRUNK_COLOR := Color(0.30, 0.20, 0.11)





const FOREST_CROWN_COLORS: Array[Color] = [
	Color(0.16, 0.40, 0.11),   
	Color(0.22, 0.48, 0.14),   
	Color(0.30, 0.52, 0.16),   
	Color(0.34, 0.50, 0.18),   
	Color(0.24, 0.44, 0.13),   
	Color(0.19, 0.46, 0.12),   
]


static var _lollipop_mesh_cache: ArrayMesh = null



static func build_forest_area(
		points: PackedVector3Array,
		hp: HeightProvider,
		grid_step: float,
		y_offset: float = 0.01,
		clip_rect: Variant = null,
		render_priority: int = GROUND_NO_PRIORITY,
) -> Node3D:
	if points.size() < 3:
		return null

	var root := Node3D.new()

	
	var ground: MeshInstance3D
	if hp != null and hp.is_ready() and grid_step > 0.0:
		ground = build_terrain_draped_mesh(points, FOREST_GROUND_COLOR, hp, grid_step, y_offset, clip_rect, render_priority)
	else:
		ground = build_flat_polygon_mesh(points, FOREST_GROUND_COLOR, y_offset, true, render_priority)
	if ground != null:
		ground.name = "ForestGround"
		root.add_child(ground)

	
	var scatter := _scatter_points_in_polygon(points, hp, FOREST_DENSITY, clip_rect)
	if scatter.size() == 0:
		if ground != null:
			return root
		return null

	
	if _lollipop_mesh_cache == null:
		_build_lollipop_mesh()

	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = scatter.size()
	mm.mesh = _lollipop_mesh_cache

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2(points[0].x, points[0].z)) + 42

	for i: int in range(scatter.size()):
		var pos: Vector3 = scatter[i]
		
		var s := rng.randf_range(0.6, 1.3)
		var t := Transform3D()
		t = t.scaled(Vector3(s, s, s))
		t.origin = pos
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, FOREST_CROWN_COLORS[rng.randi() % FOREST_CROWN_COLORS.size()])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "ForestTrees"
	root.add_child(mmi)

	return root






const _CROWN_LOBES: Array = [
	[Vector3(0.0, 5.6, 0.0), 2.05],     
	[Vector3(1.25, 5.0, 0.9), 1.35],    
	[Vector3(-1.1, 5.15, -0.95), 1.4],  
	[Vector3(0.3, 6.75, -1.2), 1.25],   
	[Vector3(-0.55, 6.4, 1.15), 1.2],   
	[Vector3(0.85, 5.55, -1.0), 1.1],   
]


const _CROWN_BOTTOM_Y := 3.6
const _CROWN_TOP_Y := 8.0


const _CROWN_SHADE_MIN := 0.55
const _CROWN_SHADE_MAX := 1.12













static func _build_lollipop_mesh() -> void:
	var merged := ArrayMesh.new()

	
	var trunk := CylinderMesh.new()
	trunk.top_radius = FOREST_TRUNK_RADIUS * 0.6
	trunk.bottom_radius = FOREST_TRUNK_RADIUS * 1.35
	trunk.height = 4.5  
	trunk.radial_segments = 7
	trunk.rings = 1

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = FOREST_TRUNK_COLOR
	trunk_mat.roughness = 0.95

	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	st_trunk.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, 2.25, 0)))
	st_trunk.set_material(trunk_mat)
	st_trunk.commit(merged)

	
	var crown_mat := StandardMaterial3D.new()
	crown_mat.vertex_color_use_as_albedo = true
	crown_mat.roughness = 0.9

	var st_crown := SurfaceTool.new()
	st_crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lobe: Array in _CROWN_LOBES:
		var centre: Vector3 = lobe[0]
		var radius: float = lobe[1]
		_append_crown_lobe(st_crown, centre, radius)
	st_crown.set_material(crown_mat)
	st_crown.commit(merged)

	_lollipop_mesh_cache = merged





static func _append_crown_lobe(st: SurfaceTool, centre: Vector3, radius: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 7
	sphere.rings = 5

	
	var arrays := sphere.get_mesh_arrays()
	if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
		return
	if arrays.size() <= Mesh.ARRAY_NORMAL or arrays[Mesh.ARRAY_NORMAL] == null:
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var raw_indices: Variant = null
	if arrays.size() > Mesh.ARRAY_INDEX:
		raw_indices = arrays[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = raw_indices as PackedInt32Array if raw_indices != null else PackedInt32Array()
	var span: float = maxf(_CROWN_TOP_Y - _CROWN_BOTTOM_Y, 0.001)

	for idx: int in indices:
		var v: Vector3 = verts[idx] + centre
		var n: Vector3 = normals[idx]
		
		var t: float = clampf((v.y - _CROWN_BOTTOM_Y) / span, 0.0, 1.0)
		
		var up: float = clampf(n.y * 0.5 + 0.5, 0.0, 1.0)
		var shade: float = lerpf(_CROWN_SHADE_MIN, _CROWN_SHADE_MAX, t * 0.7 + up * 0.3)
		st.set_color(Color(shade, shade, shade))
		st.set_normal(n)
		st.add_vertex(v)





const SCRUB_DENSITY := 0.15

const SCRUB_MIN_DIAMETER := 1.0
const SCRUB_MAX_DIAMETER := 3.0

const SCRUB_COLORS: Array[Color] = [
	Color(0.25, 0.50, 0.15),
	Color(0.30, 0.55, 0.20),
	Color(0.35, 0.45, 0.18),
	Color(0.28, 0.52, 0.12),
	Color(0.40, 0.58, 0.22),
]

const SCRUB_GROUND_COLOR := Color(0.35, 0.45, 0.20)






static func build_scrub_area(
		points: PackedVector3Array,
		hp: HeightProvider,
		grid_step: float,
		y_offset: float = 0.01,
		clip_rect: Variant = null,
		render_priority: int = GROUND_NO_PRIORITY,
) -> Node3D:
	if points.size() < 3:
		return null

	var root := Node3D.new()

	
	var ground: MeshInstance3D
	if hp != null and hp.is_ready() and grid_step > 0.0:
		ground = build_terrain_draped_mesh(points, SCRUB_GROUND_COLOR, hp, grid_step, y_offset, clip_rect, render_priority)
	else:
		ground = build_flat_polygon_mesh(points, SCRUB_GROUND_COLOR, y_offset, true, render_priority)
	if ground != null:
		ground.name = "ScrubGround"
		root.add_child(ground)

	
	var scatter_points := _scatter_points_in_polygon(points, hp, SCRUB_DENSITY, clip_rect)
	if scatter_points.size() == 0:
		if ground != null:
			return root
		return null

	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = scatter_points.size()

	
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 8
	
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	sphere.material = mat
	mm.mesh = sphere

	var rng := RandomNumberGenerator.new()
	
	rng.seed = hash(Vector2(points[0].x, points[0].z))

	for i: int in range(scatter_points.size()):
		var pos: Vector3 = scatter_points[i]
		var diameter := rng.randf_range(SCRUB_MIN_DIAMETER, SCRUB_MAX_DIAMETER)
		var scale_val := diameter  
		var t := Transform3D()
		t = t.scaled(Vector3(scale_val, scale_val, scale_val))
		
		t.origin = Vector3(pos.x, pos.y + diameter * 0.5, pos.z)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, SCRUB_COLORS[rng.randi() % SCRUB_COLORS.size()])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "ScrubBalls"
	root.add_child(mmi)

	return root









static func _scatter_points_in_polygon(
		points: PackedVector3Array,
		hp: HeightProvider,
		density: float = SCRUB_DENSITY,
		clip_rect: Variant = null,
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var bounds := polygon_bounds_xz(points)
	var min_x := bounds[0]
	var max_x := bounds[1]
	var min_z := bounds[2]
	var max_z := bounds[3]

	
	
	
	
	if clip_rect != null:
		min_x = maxf(min_x, clip_rect[0])
		max_x = minf(max_x, clip_rect[1])
		min_z = maxf(min_z, clip_rect[2])
		max_z = minf(max_z, clip_rect[3])
	if min_x >= max_x or min_z >= max_z:
		return result
	var area := (max_x - min_x) * (max_z - min_z)
	if area < 1.0:
		return result

	var poly_2d: PackedVector2Array = []
	var count := points.size()
	if count > 1 and points[0].distance_to(points[count - 1]) < 0.01:
		count -= 1
	for i: int in range(count):
		poly_2d.append(Vector2(points[i].x, points[i].z))

	
	var n_candidates := int(area * density)
	
	n_candidates = mini(n_candidates, 4000)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2(points[0].x, points[0].z)) + 1

	for _j: int in range(n_candidates):
		var px := rng.randf_range(min_x, max_x)
		var pz := rng.randf_range(min_z, max_z)
		if Geometry2D.is_point_in_polygon(Vector2(px, pz), poly_2d):
			var py := 0.0
			if hp != null and hp.is_ready():
				py = hp.sample_local_xz(px, pz)
			result.append(Vector3(px, py, pz))

	return result





static func polygon_covers_tile(
		points: PackedVector3Array,
		tile_origin_x: float,
		tile_origin_z: float,
		tile_size: float,
		_grid_step: float  
) -> bool:
	
	
	var bounds := polygon_bounds_xz(points)
	if bounds[0] > tile_origin_x or bounds[1] < tile_origin_x + tile_size:
		return false
	if bounds[2] > tile_origin_z or bounds[3] < tile_origin_z + tile_size:
		return false

	var poly_2d: PackedVector2Array = []
	var count := points.size()
	if count > 1 and points[0].distance_to(points[count - 1]) < 0.01:
		count -= 1
	for i: int in range(count):
		poly_2d.append(Vector2(points[i].x, points[i].z))

	
	
	
	
	var tx1 := tile_origin_x + tile_size
	var tz1 := tile_origin_z + tile_size
	if not Geometry2D.is_point_in_polygon(Vector2(tile_origin_x, tile_origin_z), poly_2d):
		return false
	if not Geometry2D.is_point_in_polygon(Vector2(tx1, tile_origin_z), poly_2d):
		return false
	if not Geometry2D.is_point_in_polygon(Vector2(tile_origin_x, tz1), poly_2d):
		return false
	if not Geometry2D.is_point_in_polygon(Vector2(tx1, tz1), poly_2d):
		return false
	return true
