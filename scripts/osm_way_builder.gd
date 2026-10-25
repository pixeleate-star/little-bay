class_name OSMWayBuilder
extends RefCounted










var height_provider: HeightProvider = null
var terrain_grid_step: float = 0.0





var tile_clip_rect: Variant = null


const CLIP_MARGIN := 3.0







const RoadProfileScript := preload("res://scripts/road_profile.gd")
const RoadNetworkContextScript := preload("res://scripts/road_network_context.gd")





var network: RoadNetworkContextScript = null

const ROAD_WIDTHS := RoadProfileScript.ROAD_WIDTHS
const ROAD_COLORS := RoadProfileScript.ROAD_COLORS
const DEFAULT_WIDTH := RoadProfileScript.DEFAULT_WIDTH
const DEFAULT_COLOR := RoadProfileScript.DEFAULT_COLOR
const ROAD_Y := RoadProfileScript.ROAD_Y
const SIDEWALK_WIDTH := RoadProfileScript.SIDEWALK_WIDTH
const SIDEWALK_HEIGHT := RoadProfileScript.SIDEWALK_HEIGHT
const SIDEWALK_COLOR := RoadProfileScript.SIDEWALK_COLOR
const SIDEWALK_BASE_Y := 0.0








const MAX_TRIM_FRACTION := 0.6








const MIN_SPAN_LENGTH := 2.0

func build_road(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData) -> MeshInstance3D:
	var points := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)

	if points.size() < 2:
		return null

	
	if RoadProfileScript.is_tunnel(way):
		return null

	var highway_type := RoadProfileScript.highway_type(way)
	var color := RoadProfileScript.color_for(highway_type)

	
	
	
	var lane_spec := RoadLaneSpec.from_tags(highway_type, way.tags)
	var width := RoadProfileScript.width_for(way)

	
	
	
	
	
	var trim_start := _trim_at_way_start(way)
	
	
	var spans := _split_at_junctions(points, way, osm_data)
	if spans.is_empty():
		
		
		return null

	
	if terrain_grid_step > 0.0:
		var draped: Array = []
		for span: PackedVector3Array in spans:
			draped.append(PolygonUtils.subdivide_polyline_to_terrain(
				span, height_provider, terrain_grid_step))
		spans = draped

	
	
	points = PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
	if terrain_grid_step > 0.0:
		points = PolygonUtils.subdivide_polyline_to_terrain(
			points, height_provider, terrain_grid_step)

	
	
	
	
	
	
	
	
	
	
	
	
	var marking_spec := RoadMarkingSpec.from_way(
		way.node_ids, osm_data.nodes, RoadRegion.for_osm_data(osm_data))
	marking_spec = marking_spec.rebased(trim_start)
	
	
	var along_at := _cumulative_along(points)
	var road_length: float = along_at[along_at.size() - 1] if along_at.size() > 0 else 0.0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Road_%d" % way.id

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	
	
	
	
	var mat := RoadMaterialFactory.create_road_material(
		highway_type, color, lane_spec, width, road_length, marking_spec)
	st.set_material(mat)

	var sidewalk_st := SurfaceTool.new()
	sidewalk_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sidewalk_mat := RoadMaterialFactory.create_sidewalk_material()
	sidewalk_st.set_material(sidewalk_mat)

	var sidewalk_sides := RoadProfileScript.sidewalk_sides(way.tags)
	var has_left_sidewalk: bool = sidewalk_sides["left"]
	var has_right_sidewalk: bool = sidewalk_sides["right"]

	
	
	
	
	
	var conform := height_provider != null and height_provider.is_ready() \
		and terrain_grid_step > 0.0

	
	
	
	
	
	
	var parts: Array = []
	for span: PackedVector3Array in spans:
		if span.size() < 2:
			continue
		if tile_clip_rect == null:
			parts.append(span)
			continue
		for piece: PackedVector3Array in PolygonUtils.clip_polyline_to_rect(
				span, tile_clip_rect, CLIP_MARGIN):
			parts.append(piece)
	if parts.is_empty():
		return null  

	for part: PackedVector3Array in parts:
		var part_pts: PackedVector3Array = part
		if part_pts.size() < 2:
			continue
		
		
		var part_along0 := _along_at_point(points, along_at, part_pts[0])
		_emit_road_ribbon(
			st, sidewalk_st, part_pts, width, part_along0,
			has_left_sidewalk, has_right_sidewalk, conform)

	var mesh := st.commit()
	if has_left_sidewalk or has_right_sidewalk:
		mesh = sidewalk_st.commit(mesh)

	mesh_instance.mesh = mesh
	
	
	
	
	var layer_y := RoadProfileScript.layer_offset(way)
	if layer_y != 0.0:
		mesh_instance.position.y = layer_y
	return mesh_instance





func _trim_at_way_start(way: OSMParser.OSMWay) -> float:
	if network == null or way.node_ids.is_empty():
		return 0.0
	return network.trim_at(way.id, way.node_ids[0], true)
















func _split_at_junctions(
		points: PackedVector3Array, way: OSMParser.OSMWay,
		osm_data: OSMParser.OSMData) -> Array:
	if network == null or points.size() < 2 or way.node_ids.is_empty():
		return [points] as Array

	
	
	var cuts: Array = []   
	var along := 0.0
	var prev_pos := Vector3.ZERO
	var have_prev := false
	for i: int in range(way.node_ids.size()):
		var nid: int = way.node_ids[i]
		if not osm_data.nodes.has(nid):
			continue
		var pos: Vector3 = osm_data.nodes[nid].local_pos
		if have_prev:
			along += _xz_distance(prev_pos, pos)
		prev_pos = pos
		have_prev = true

		if not network.has_junction(nid):
			continue
		
		
		
		var trim_after := network.trim_at(way.id, nid, true)
		var trim_before := network.trim_at(way.id, nid, false)
		if trim_after <= 0.0 and trim_before <= 0.0:
			continue
		cuts.append({
			"along": along,
			"trim_before": trim_before,
			"trim_after": trim_after,
		})

	if cuts.is_empty():
		return [points] as Array

	var total := 0.0
	for i: int in range(points.size() - 1):
		total += _xz_distance(points[i], points[i + 1])

	
	var spans: Array = []
	var span_start := 0.0
	var span_start_trim := 0.0
	for cut: Dictionary in cuts:
		var cut_at: float = cut["along"]
		var end_trim: float = cut["trim_before"]
		_append_span(spans, points, span_start, span_start_trim, cut_at, end_trim, total)
		span_start = cut_at
		span_start_trim = cut["trim_after"]
	
	_append_span(spans, points, span_start, span_start_trim, total, 0.0, total)
	return spans








func _append_span(
		spans: Array, points: PackedVector3Array,
		from: float, trim_from: float, to: float, trim_to: float,
		_total: float) -> void:
	var span_len := to - from
	if span_len <= 0.01:
		return
	var requested := trim_from + trim_to
	var budget := span_len * MAX_TRIM_FRACTION
	if requested > budget and requested > 0.0:
		var scale := budget / requested
		trim_from *= scale
		trim_to *= scale

	var a := from + trim_from
	var b := to - trim_to
	if b - a <= MIN_SPAN_LENGTH:
		
		
		
		
		
		return
	spans.append(_slice_polyline(points, a, b))





static func _slice_polyline(
		points: PackedVector3Array, from: float, to: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(_point_along(points, from))
	var travelled := 0.0
	for i: int in range(points.size()):
		if i > 0:
			travelled += _xz_distance(points[i - 1], points[i])
		if travelled > from + 0.01 and travelled < to - 0.01:
			out.append(points[i])
	out.append(_point_along(points, to))
	return out










func _trim_points_at_junctions(
		points: PackedVector3Array, way: OSMParser.OSMWay) -> PackedVector3Array:
	if network == null or points.size() < 2 or way.node_ids.is_empty():
		return points

	var first_node: int = way.node_ids[0]
	var last_node: int = way.node_ids[way.node_ids.size() - 1]
	
	
	var trim_start := network.trim_at(way.id, first_node, true)
	var trim_end := network.trim_at(way.id, last_node, false)
	if trim_start <= 0.0 and trim_end <= 0.0:
		return points

	
	
	
	
	
	
	
	
	
	var total := 0.0
	for i: int in range(points.size() - 1):
		total += _xz_distance(points[i], points[i + 1])
	var budget := total * MAX_TRIM_FRACTION
	var requested := trim_start + trim_end
	if requested > budget and requested > 0.0:
		var scale := budget / requested
		trim_start *= scale
		trim_end *= scale

	return _trim_polyline(points, trim_start, trim_end)








static func _trim_polyline(
		points: PackedVector3Array, from_start: float,
		from_end: float) -> PackedVector3Array:
	var total := 0.0
	for i: int in range(points.size() - 1):
		total += _xz_distance(points[i], points[i + 1])
	if from_start + from_end >= total - 0.01:
		return PackedVector3Array()

	var out := PackedVector3Array()
	var keep_from := from_start
	var keep_to := total - from_end
	var travelled := 0.0

	
	
	out.append(_point_along(points, keep_from))
	for i: int in range(points.size()):
		if i > 0:
			travelled += _xz_distance(points[i - 1], points[i])
		if travelled > keep_from + 0.01 and travelled < keep_to - 0.01:
			out.append(points[i])
	out.append(_point_along(points, keep_to))
	return out




static func _point_along(points: PackedVector3Array, distance: float) -> Vector3:
	if points.size() == 0:
		return Vector3.ZERO
	if distance <= 0.0:
		return points[0]
	var travelled := 0.0
	for i: int in range(points.size() - 1):
		var seg := _xz_distance(points[i], points[i + 1])
		if seg <= 0.0001:
			continue
		if travelled + seg >= distance:
			var t := (distance - travelled) / seg
			return points[i].lerp(points[i + 1], t)
		travelled += seg
	return points[points.size() - 1]




static func _xz_distance(a: Vector3, b: Vector3) -> float:
	var dx := b.x - a.x
	var dz := b.z - a.z
	return sqrt(dx * dx + dz * dz)








func _emit_road_ribbon(
		st: SurfaceTool, sidewalk_st: SurfaceTool,
		part_pts: PackedVector3Array, width: float, along0: float,
		has_left_sidewalk: bool, has_right_sidewalk: bool, conform: bool) -> void:
	var half_w := width / 2.0
	var miter_limit := 2.0  
	var n_pts := part_pts.size()

	
	
	var along_at := _cumulative_along(part_pts)
	for i: int in range(along_at.size()):
		along_at[i] += along0

	
	var miter_offsets: Array[Vector3] = []
	miter_offsets.resize(n_pts)
	for i: int in range(n_pts):
		miter_offsets[i] = _miter_offset(part_pts, i, half_w, miter_limit)

	var left_edge: Array = []
	var right_edge: Array = []
	left_edge.resize(n_pts)
	right_edge.resize(n_pts)
	for i: int in range(n_pts):
		var pt := part_pts[i]
		var off := miter_offsets[i]
		var lx := pt.x - off.x
		var lz := pt.z - off.z
		var rx := pt.x + off.x
		var rz := pt.z + off.z
		left_edge[i] = Vector3(lx, _edge_height(lx, lz, pt.y) + ROAD_Y, lz)
		right_edge[i] = Vector3(rx, _edge_height(rx, rz, pt.y) + ROAD_Y, rz)

	
	for i: int in range(n_pts - 1):
		var l0: Vector3 = left_edge[i]
		var r0: Vector3 = right_edge[i]
		var r1: Vector3 = right_edge[i + 1]
		var l1: Vector3 = left_edge[i + 1]

		var c0 := part_pts[i]
		var c1 := part_pts[i + 1]
		var uv_fn := _segment_uv_fn(
			Vector2(c0.x, c0.z), Vector2(c1.x, c1.z),
			along_at[i], width)

		if conform:
			var quad := PackedVector2Array([
				Vector2(l0.x, l0.z),
				Vector2(r0.x, r0.z),
				Vector2(r1.x, r1.z),
				Vector2(l1.x, l1.z),
			])
			PolygonUtils.emit_terrain_conforming_quad(
				st, quad, height_provider, terrain_grid_step, ROAD_Y, uv_fn)
		else:
			var uv_l0 := uv_fn.call(Vector2(l0.x, l0.z)) as Vector2
			var uv_r0 := uv_fn.call(Vector2(r0.x, r0.z)) as Vector2
			var uv_r1 := uv_fn.call(Vector2(r1.x, r1.z)) as Vector2
			var uv_l1 := uv_fn.call(Vector2(l1.x, l1.z)) as Vector2
			st.set_uv(uv_l0); st.set_normal(Vector3.UP); st.add_vertex(l0)
			st.set_uv(uv_r1); st.set_normal(Vector3.UP); st.add_vertex(r1)
			st.set_uv(uv_r0); st.set_normal(Vector3.UP); st.add_vertex(r0)
			st.set_uv(uv_l0); st.set_normal(Vector3.UP); st.add_vertex(l0)
			st.set_uv(uv_l1); st.set_normal(Vector3.UP); st.add_vertex(l1)
			st.set_uv(uv_r1); st.set_normal(Vector3.UP); st.add_vertex(r1)

		
		
		
		var is_first := i == 0
		var is_last := i == n_pts - 2
		if has_left_sidewalk:
			var center := Vector3(part_pts[i].x, left_edge[i].y, part_pts[i].z)
			var outward: Vector3 = (center - left_edge[i]).normalized()
			_add_sidewalk_segment(
				sidewalk_st, left_edge[i], left_edge[i + 1], -outward,
				is_first, is_last)

		if has_right_sidewalk:
			var center := Vector3(part_pts[i].x, right_edge[i].y, part_pts[i].z)
			var outward: Vector3 = (right_edge[i] - center).normalized()
			_add_sidewalk_segment(
				sidewalk_st, right_edge[i], right_edge[i + 1], outward,
				is_first, is_last)





func _along_at_point(points: PackedVector3Array, along_at: PackedFloat32Array, p: Vector3) -> float:
	var best_i := 0
	var best_d := INF
	for i: int in range(points.size()):
		var dx := points[i].x - p.x
		var dz := points[i].z - p.z
		var d := dx * dx + dz * dz
		if d < best_d:
			best_d = d
			best_i = i
	return along_at[best_i] if best_i < along_at.size() else 0.0








func _cumulative_along(points: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(points.size())
	if points.size() == 0:
		return out
	out[0] = 0.0
	var acc := 0.0
	for i: int in range(1, points.size()):
		var dx := points[i].x - points[i - 1].x
		var dz := points[i].z - points[i - 1].z
		acc += sqrt(dx * dx + dz * dz)
		out[i] = acc
	return out










func _segment_uv_fn(c0: Vector2, c1: Vector2, along0: float, width: float) -> Callable:
	var dir := c1 - c0
	var seg_len := dir.length()
	if seg_len < 0.0001:
		return func(_p: Vector2) -> Vector2: return Vector2(along0, 0.5)
	var udir := dir / seg_len
	
	var right := Vector2(-udir.y, udir.x)
	var half_w := maxf(width * 0.5, 0.0001)
	return func(p: Vector2) -> Vector2:
		var rel := p - c0
		var along := along0 + rel.dot(udir)
		var across := rel.dot(right)
		var frac := clampf(0.5 + across / (half_w * 2.0), 0.0, 1.0)
		return Vector2(along, frac)








func _edge_height(x: float, z: float, fallback_y: float) -> float:
	if height_provider != null and height_provider.is_ready():
		return height_provider.sample_mesh_height(x, z)
	return fallback_y






func _miter_offset(points: PackedVector3Array, i: int, half_w: float, miter_limit: float) -> Vector3:
	var n_pts := points.size()
	if i == 0:
		var fwd := (points[1] - points[0]).normalized()
		return Vector3(-fwd.z, 0.0, fwd.x).normalized() * half_w
	if i == n_pts - 1:
		var fwd := (points[i] - points[i - 1]).normalized()
		return Vector3(-fwd.z, 0.0, fwd.x).normalized() * half_w
	
	var fwd_prev := (points[i] - points[i - 1]).normalized()
	var fwd_next := (points[i + 1] - points[i]).normalized()
	var lat_prev := Vector3(-fwd_prev.z, 0.0, fwd_prev.x).normalized()
	var lat_next := Vector3(-fwd_next.z, 0.0, fwd_next.x).normalized()
	var miter_dir := (lat_prev + lat_next)
	if miter_dir.length_squared() < 0.0001:
		
		miter_dir = lat_prev
	else:
		miter_dir = miter_dir.normalized()
	
	var d := miter_dir.dot(lat_prev)
	var miter_len := half_w
	if absf(d) > 0.0001:
		miter_len = half_w / d
	miter_len = clampf(miter_len, half_w, half_w * miter_limit)
	return miter_dir * miter_len

const WATERWAY_WIDTHS := {
	"river": 12.0,
	"canal": 8.0,
	"stream": 2.0,
	"ditch": 1.0,
	"drain": 1.0,
}
const WATERWAY_DEFAULT_WIDTH := 2.0
const WATERWAY_COLOR := Color(0.2, 0.4, 0.8)
const WATERWAY_Y := 0.01  




func build_waterway(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData) -> MeshInstance3D:
	var points := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
	if points.size() < 2:
		return null

	
	if terrain_grid_step > 0.0:
		points = PolygonUtils.subdivide_polyline_to_terrain(
			points, height_provider, terrain_grid_step)

	var waterway_type: String = way.tags.get("waterway", "stream")
	var width: float = WATERWAY_WIDTHS.get(waterway_type, WATERWAY_DEFAULT_WIDTH)
	if way.tags.has("width"):
		var explicit_width: float = way.tags["width"].to_float()
		if explicit_width > 0.0:
			width = explicit_width

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Waterway_%d" % way.id

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WATERWAY_COLOR
	st.set_material(mat)

	var edges := _build_ribbon_edges(points, width / 2.0, WATERWAY_Y)
	var left_edge: Array = edges["left"]
	var right_edge: Array = edges["right"]

	for i: int in range(points.size() - 1):
		var v0: Vector3 = left_edge[i]
		var v1: Vector3 = right_edge[i]
		var v2: Vector3 = right_edge[i + 1]
		var v3: Vector3 = left_edge[i + 1]
		st.set_normal(Vector3.UP); st.add_vertex(v0)
		st.set_normal(Vector3.UP); st.add_vertex(v2)
		st.set_normal(Vector3.UP); st.add_vertex(v1)
		st.set_normal(Vector3.UP); st.add_vertex(v0)
		st.set_normal(Vector3.UP); st.add_vertex(v3)
		st.set_normal(Vector3.UP); st.add_vertex(v2)

	mesh_instance.mesh = st.commit()
	return mesh_instance



const RAILWAY_WIDTHS := {
	"rail": 2.6,        
	"light_rail": 2.6,
	"subway": 2.6,
	"tram": 2.2,
	"narrow_gauge": 1.8,
	"monorail": 1.2,
	"funicular": 2.2,
	"disused": 2.6,
	"preserved": 2.6,
}
const RAILWAY_DEFAULT_WIDTH := 2.6
const RAILWAY_BED_COLOR := Color(0.32, 0.28, 0.25)   
const RAILWAY_RAIL_COLOR := Color(0.6, 0.6, 0.62)    
const RAILWAY_BED_Y := 0.03                          
const RAILWAY_RAIL_Y := 0.06                          
const RAILWAY_RAIL_HALF := 0.07                       
const RAILWAY_GAUGE_FRAC := 0.55                      





func build_railway(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData) -> MeshInstance3D:
	var points := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
	if points.size() < 2:
		return null

	
	if terrain_grid_step > 0.0:
		points = PolygonUtils.subdivide_polyline_to_terrain(
			points, height_provider, terrain_grid_step)

	var railway_type: String = way.tags.get("railway", "rail")
	var width: float = RAILWAY_WIDTHS.get(railway_type, RAILWAY_DEFAULT_WIDTH)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Railway_%d" % way.id

	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bed_mat := StandardMaterial3D.new()
	bed_mat.albedo_color = RAILWAY_BED_COLOR
	st.set_material(bed_mat)

	var bed := _build_ribbon_edges(points, width / 2.0, RAILWAY_BED_Y)
	var bed_left: Array = bed["left"]
	var bed_right: Array = bed["right"]
	for i: int in range(points.size() - 1):
		_emit_ribbon_quad(st, bed_left[i], bed_right[i], bed_right[i + 1], bed_left[i + 1])

	
	var rail_offset := (width * RAILWAY_GAUGE_FRAC) / 2.0
	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = RAILWAY_RAIL_COLOR
	rail_mat.metallic = 0.6
	rail_st.set_material(rail_mat)

	_emit_offset_strip(rail_st, points, rail_offset, RAILWAY_RAIL_HALF, RAILWAY_RAIL_Y)
	_emit_offset_strip(rail_st, points, -rail_offset, RAILWAY_RAIL_HALF, RAILWAY_RAIL_Y)

	var mesh := st.commit()
	mesh = rail_st.commit(mesh)
	mesh_instance.mesh = mesh
	return mesh_instance





func _emit_ribbon_quad(st: SurfaceTool, l0: Vector3, r0: Vector3, r1: Vector3, l1: Vector3) -> void:
	st.set_normal(Vector3.UP); st.add_vertex(l0)
	st.set_normal(Vector3.UP); st.add_vertex(r1)
	st.set_normal(Vector3.UP); st.add_vertex(r0)
	st.set_normal(Vector3.UP); st.add_vertex(l0)
	st.set_normal(Vector3.UP); st.add_vertex(l1)
	st.set_normal(Vector3.UP); st.add_vertex(r1)



func _emit_offset_strip(st: SurfaceTool, points: PackedVector3Array, center_offset: float, half: float, y: float) -> void:
	var n_pts := points.size()
	var centerline: PackedVector3Array = PackedVector3Array()
	centerline.resize(n_pts)
	for i: int in range(n_pts):
		var lateral: Vector3
		if i == 0:
			var fwd := (points[1] - points[0]).normalized()
			lateral = Vector3(-fwd.z, 0.0, fwd.x).normalized()
		elif i == n_pts - 1:
			var fwd := (points[i] - points[i - 1]).normalized()
			lateral = Vector3(-fwd.z, 0.0, fwd.x).normalized()
		else:
			var fwd_prev := (points[i] - points[i - 1]).normalized()
			var fwd_next := (points[i + 1] - points[i]).normalized()
			var lat_prev := Vector3(-fwd_prev.z, 0.0, fwd_prev.x).normalized()
			var lat_next := Vector3(-fwd_next.z, 0.0, fwd_next.x).normalized()
			lateral = (lat_prev + lat_next)
			if lateral.length_squared() < 0.0001:
				lateral = lat_prev
			else:
				lateral = lateral.normalized()
		var pt := points[i]
		centerline[i] = Vector3(pt.x + lateral.x * center_offset, pt.y, pt.z + lateral.z * center_offset)
	var edges := _build_ribbon_edges(centerline, half, y)
	var left_edge: Array = edges["left"]
	var right_edge: Array = edges["right"]
	for i: int in range(n_pts - 1):
		_emit_ribbon_quad(st, left_edge[i], right_edge[i], right_edge[i + 1], left_edge[i + 1])



func _build_ribbon_edges(points: PackedVector3Array, half_w: float, y: float) -> Dictionary:
	var miter_limit := 2.0
	var n_pts := points.size()
	var left_edge: Array = []
	var right_edge: Array = []
	for i: int in range(n_pts):
		var pt := points[i]
		var offset: Vector3
		if i == 0:
			var fwd := (points[1] - points[0]).normalized()
			offset = Vector3(-fwd.z, 0.0, fwd.x).normalized() * half_w
		elif i == n_pts - 1:
			var fwd := (points[i] - points[i - 1]).normalized()
			offset = Vector3(-fwd.z, 0.0, fwd.x).normalized() * half_w
		else:
			var fwd_prev := (points[i] - points[i - 1]).normalized()
			var fwd_next := (points[i + 1] - points[i]).normalized()
			var lat_prev := Vector3(-fwd_prev.z, 0.0, fwd_prev.x).normalized()
			var lat_next := Vector3(-fwd_next.z, 0.0, fwd_next.x).normalized()
			var miter_dir := (lat_prev + lat_next)
			if miter_dir.length_squared() < 0.0001:
				miter_dir = lat_prev
			else:
				miter_dir = miter_dir.normalized()
			var d := miter_dir.dot(lat_prev)
			var miter_len := half_w
			if absf(d) > 0.0001:
				miter_len = half_w / d
			miter_len = clampf(miter_len, half_w, half_w * miter_limit)
			offset = miter_dir * miter_len
		
		
		
		var lx := pt.x - offset.x
		var lz := pt.z - offset.z
		var rx := pt.x + offset.x
		var rz := pt.z + offset.z
		left_edge.append(Vector3(lx, _edge_height(lx, lz, pt.y) + y, lz))
		right_edge.append(Vector3(rx, _edge_height(rx, rz, pt.y) + y, rz))
	return { "left": left_edge, "right": right_edge }

func _add_sidewalk_segment(st: SurfaceTool, edge_start: Vector3, edge_end: Vector3, outward: Vector3, add_start_cap: bool, add_end_cap: bool) -> void:
	var offset := outward * SIDEWALK_WIDTH

	
	
	
	var start_base := edge_start.y - ROAD_Y + SIDEWALK_BASE_Y
	var end_base := edge_end.y - ROAD_Y + SIDEWALK_BASE_Y

	var inner_start_bottom := Vector3(edge_start.x, start_base, edge_start.z)
	var inner_end_bottom := Vector3(edge_end.x, end_base, edge_end.z)
	var inner_start_top := Vector3(edge_start.x, start_base + SIDEWALK_HEIGHT, edge_start.z)
	var inner_end_top := Vector3(edge_end.x, end_base + SIDEWALK_HEIGHT, edge_end.z)

	var outer_start := edge_start + offset
	var outer_end := edge_end + offset
	var outer_start_bottom := Vector3(outer_start.x, start_base, outer_start.z)
	var outer_end_bottom := Vector3(outer_end.x, end_base, outer_end.z)
	var outer_start_top := Vector3(outer_start.x, start_base + SIDEWALK_HEIGHT, outer_start.z)
	var outer_end_top := Vector3(outer_end.x, end_base + SIDEWALK_HEIGHT, outer_end.z)

	
	_add_quad_facing(st, inner_start_top, inner_end_top, outer_end_top, outer_start_top, Vector3.UP)
	
	_add_quad_facing(st, outer_start_bottom, outer_start_top, outer_end_top, outer_end_bottom, outward)
	
	_add_quad_facing(st, inner_start_bottom, inner_end_bottom, inner_end_top, inner_start_top, -outward)

	if add_start_cap:
		
		var cap_normal := (edge_start - edge_end).normalized()
		_add_quad_facing(st, outer_start_bottom, inner_start_bottom, inner_start_top, outer_start_top, cap_normal)

	if add_end_cap:
		
		var cap_normal := (edge_end - edge_start).normalized()
		_add_quad_facing(st, inner_end_bottom, outer_end_bottom, outer_end_top, inner_end_top, cap_normal)

func _add_quad_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, desired_normal: Vector3) -> void:
	PolygonUtils.add_quad_facing(st, a, b, c, d, desired_normal)
