class_name Minimap
extends Control











@export var map_radius: float = 200.0  
@export var car_node_path: NodePath
@export var tile_manager_node_path: NodePath

var _car: VehicleBody3D = null
var _tile_manager: OSMTileManager = null
var _data_ready: bool = false





var _chunks: Array = []
var _cache_center: Vector3 = Vector3.ZERO
var _has_cache: bool = false




var _rebuild_task: int = -1
var _rebuilt: Dictionary = {}



const CHUNK_SIZE := 96.0
const VISIBLE_MARGIN := 40.0
const VISIBLE_REFRESH := 30.0
var _visible_chunks: Array = []
var _visible_center := Vector2(INF, INF)
var _expanded: bool = false



var _route := PackedVector3Array()
var _route_xz := PackedVector2Array()
var _route_gates := PackedVector3Array()
var _next_gate: int = 0
var _objective := Vector3.ZERO
var _has_objective := false



var _backdrop: Layer
var _map_mask: Layer
var _map_content: Layer


const BG_COLOR := Color(0.055, 0.06, 0.055, 0.97)
const ROAD_COLOR := Color("415d99")
const MAJOR_ROAD_COLOR := Color("009b88")
const BUILDING_FILL := Color("9d696a")
const BUILDING_PALETTE := [Color("9d696a"), Color("8f5676"), Color("415d99"), Color("735fb1"), Color("6ea16e")]
const WATERWAY_COLOR := Color("009b88")
const CAR_COLOR := Color("6ea16e")
const BORDER_COLOR := Color("009b88")
const NORTH_COLOR := Color("6ea16e")
const NORTH_BORDER_COLOR := Color("9d696a")
const ROUTE_COLOR := Color("6ea16e")
const ROUTE_CASING := Color(0.04, 0.035, 0.03, 0.88)
const FINISH_COLOR := Color("eee8dc")

const MAJOR_HIGHWAYS := ["motorway", "trunk", "primary", "secondary", "tertiary",
	"motorway_link", "trunk_link", "primary_link"]


const WATERWAY_WIDTHS := {
	"river": 3.0,
	"canal": 2.5,
	"stream": 1.5,
	"ditch": 1.0,
	"drain": 1.0,
}
const WATERWAY_DEFAULT_WIDTH := 1.5




class Layer extends Control:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func _ready() -> void:
	call_deferred("_resolve_nodes")
	_backdrop = _make_layer(_paint_backdrop)
	_map_mask = _make_layer(_paint_mask)
	_map_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_map_content = _make_layer(_paint_content)
	_map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_mask.add_child(_map_content)
	add_child(_backdrop)
	add_child(_map_mask)
	resized.connect(_on_resized)


func _make_layer(painter: Callable) -> Layer:
	var layer := Layer.new()
	layer.painter = painter
	layer.show_behind_parent = true
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	return layer


func _on_resized() -> void:
	_backdrop.queue_redraw()
	_map_mask.queue_redraw()



func set_route(points: PackedVector3Array, gates: PackedVector3Array) -> void:
	_route = points
	_route_xz = _to_xz(points)
	_route_gates = gates
	_next_gate = 0



func set_next_gate(index: int) -> void:
	_next_gate = index


func clear_route() -> void:
	_route = PackedVector3Array()
	_route_xz = PackedVector2Array()
	_route_gates = PackedVector3Array()
	_next_gate = 0


func set_objective(point: Vector3) -> void:
	_objective = point
	_has_objective = true
	queue_redraw()


func clear_objective() -> void:
	_has_objective = false
	queue_redraw()


func has_route() -> bool:
	return not _route.is_empty()


func _resolve_nodes() -> void:
	if car_node_path:
		_car = get_node_or_null(car_node_path) as VehicleBody3D
	if tile_manager_node_path and _tile_manager == null:
		_tile_manager = get_node_or_null(tile_manager_node_path) as OSMTileManager
		if _tile_manager:
			
			_data_ready = _tile_manager.is_data_ready()
			if not _data_ready and not _tile_manager.data_loaded.is_connected(_on_data_loaded):
				_tile_manager.data_loaded.connect(_on_data_loaded)


func _on_data_loaded(_osm_data: OSMParser.OSMData) -> void:
	_data_ready = true
	_has_cache = false  


func _process(_delta: float) -> void:
	if _car == null or not _data_ready:
		_resolve_nodes()
		return
	var car_pos := _car.global_position
	var car_xz := Vector2(car_pos.x, car_pos.z)
	_adopt_finished_rebuild()
	if _rebuild_task == -1 and (not _has_cache or car_pos.distance_to(_cache_center) > map_radius * 1.5):
		_rebuild_task = WorkerThreadPool.add_task(_rebuild_cache.bind(car_pos))
	if _has_cache and car_xz.distance_to(_visible_center) > VISIBLE_REFRESH:
		_refresh_visible(car_xz)
	queue_redraw()
	if _map_content != null:
		_map_content.queue_redraw()


func _exit_tree() -> void:
	if _rebuild_task != -1:
		WorkerThreadPool.wait_for_task_completion(_rebuild_task)
		_rebuild_task = -1


func _adopt_finished_rebuild() -> void:
	if _rebuild_task == -1 or not WorkerThreadPool.is_task_completed(_rebuild_task):
		return
	WorkerThreadPool.wait_for_task_completion(_rebuild_task)
	_rebuild_task = -1
	if _rebuilt.is_empty():
		return
	_cache_center = _rebuilt["center"]
	_chunks = _rebuilt["chunks"]
	_rebuilt = {}
	_has_cache = true
	_visible_center = Vector2(INF, INF)


func _refresh_visible(car_xz: Vector2) -> void:
	_visible_center = car_xz
	var reach := map_radius + VISIBLE_MARGIN
	_visible_chunks = _chunks.filter(
		func(chunk: Dictionary) -> bool: return (chunk["bounds"] as Rect2).grow(reach).has_point(car_xz))



func _rebuild_cache(center: Vector3) -> void:
	if _tile_manager == null:
		_rebuilt = {}
		return

	
	
	
	
	var chunks := {}  
	var cache_radius := map_radius * 3.0
	for entry: Dictionary in _tile_manager.collect_ways_near(center, cache_radius):
		var way: OSMParser.OSMWay = entry["way"]
		var flat := _to_xz(entry["points"])
		if flat.size() < 2:
			continue
		var bounds := _bounds_of(flat)
		var cell := Vector2i((bounds.get_center() / CHUNK_SIZE).floor())
		if not chunks.has(cell):
			chunks[cell] = _new_chunk(bounds)
		var chunk: Dictionary = chunks[cell]
		chunk["bounds"] = (chunk["bounds"] as Rect2).merge(bounds)
		if way.tags.has("highway"):
			var major: bool = way.tags.get("highway", "unclassified") in MAJOR_HIGHWAYS
			_append_segments(chunk["major" if major else "minor"], flat)
		elif WaterwayHandler.is_waterway(way):
			var width: float = WATERWAY_WIDTHS.get(way.tags.get("waterway", "stream"), WATERWAY_DEFAULT_WIDTH)
			if not chunk["water"].has(width):
				chunk["water"][width] = PackedVector2Array()
			_append_segments(chunk["water"][width], flat)
		elif way.tags.has("building"):
			
			
			var ring := flat
			if ring.size() > 3 and ring[0] == ring[ring.size() - 1]:
				ring = ring.slice(0, ring.size() - 1)
			var indices := Geometry2D.triangulate_polygon(ring)
			if indices.is_empty():
				continue
			_append_polygon(chunk["b_points"], chunk["b_indices"], ring, indices)
	for chunk: Dictionary in chunks.values():
		var colors := PackedColorArray()
		colors.resize((chunk["b_points"] as PackedVector2Array).size())
		var building_points: PackedVector2Array = chunk["b_points"]
		for i: int in building_points.size():
			var p := building_points[i]
			var palette_index := absi(int(floor(p.x * 0.17 + p.y * 0.11))) % BUILDING_PALETTE.size()
			colors[i] = BUILDING_PALETTE[palette_index]
		chunk["b_colors"] = colors
	_rebuilt = {"center": center, "chunks": chunks.values()}


func toggle_expanded() -> void:
	set_expanded(not _expanded)


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	map_radius = 280.0 if expanded else 200.0
	if expanded:
		offset_left = -548.0
		offset_top = 24.0
		offset_right = -24.0
		offset_bottom = 548.0
	else:
		offset_left = -318.0
		offset_top = 28.0
		offset_right = -28.0
		offset_bottom = 248.0
	queue_redraw()


static func _new_chunk(bounds: Rect2) -> Dictionary:
	return {
		"bounds": bounds,
		"b_points": PackedVector2Array(),
		"b_indices": PackedInt32Array(),
		"water": {},
		"minor": PackedVector2Array(),
		"major": PackedVector2Array(),
	}





static func _append_polygon(points: PackedVector2Array, indices: PackedInt32Array,
		ring: PackedVector2Array, ring_indices: PackedInt32Array) -> void:
	var offset := points.size()
	for index: int in ring_indices:
		indices.append(index + offset)
	points.append_array(ring)




static func _append_segments(out: PackedVector2Array, points: PackedVector2Array) -> void:
	for i: int in range(points.size() - 1):
		out.append(points[i])
		out.append(points[i + 1])


static func _to_xz(points: PackedVector3Array) -> PackedVector2Array:
	var flat := PackedVector2Array()
	flat.resize(points.size())
	for i: int in points.size():
		flat[i] = Vector2(points[i].x, points[i].z)
	return flat


static func _bounds_of(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		bounds = bounds.expand(p)
	return bounds





func _view_transform(car_pos: Vector3, car_angle: float, scale_factor: float, center: Vector2) -> Transform2D:
	var sin_a := sin(car_angle)
	var cos_a := cos(car_angle)
	var x_axis := Vector2(-cos_a, -sin_a) * scale_factor
	var y_axis := Vector2(sin_a, -cos_a) * scale_factor
	return Transform2D(x_axis, y_axis, center - (x_axis * car_pos.x + y_axis * car_pos.z))


func _paint_backdrop(layer: Control) -> void:
	var center := layer.size / 2.0
	var radius := minf(layer.size.x, layer.size.y) / 2.0
	layer.draw_circle(center + Vector2(0, 3), radius + 3, Color(0, 0, 0, 0.22))
	layer.draw_circle(center, radius, BG_COLOR)
	layer.draw_arc(center, radius * 0.5, 0, TAU, 64, Color(0.32, 0.38, 0.39, 0.25), 1, true)



func _paint_mask(layer: Control) -> void:
	layer.draw_circle(layer.size / 2.0, minf(layer.size.x, layer.size.y) / 2.0, Color.WHITE)


func _paint_content(layer: Control) -> void:
	if _car == null:
		return
	var scale_factor := minf(size.x, size.y) / 2.0 / map_radius
	var car_pos := _car.global_position
	var car_forward := _car.global_transform.basis.z
	var car_angle := atan2(car_forward.x, car_forward.z)
	var car_xz := Vector2(car_pos.x, car_pos.z)
	layer.draw_set_transform_matrix(_view_transform(car_pos, car_angle, scale_factor, size / 2.0))

	
	var px := 1.0 / scale_factor
	var canvas := layer.get_canvas_item()
	var reach := map_radius
	var near: Array = _visible_chunks.filter(
		func(chunk: Dictionary) -> bool: return (chunk["bounds"] as Rect2).grow(reach).has_point(car_xz))

	for chunk: Dictionary in near:
		if not (chunk["b_indices"] as PackedInt32Array).is_empty():
			RenderingServer.canvas_item_add_triangle_array(
				canvas, chunk["b_indices"], chunk["b_points"], chunk["b_colors"])
	for chunk: Dictionary in near:
		for width: float in chunk["water"]:
			layer.draw_multiline(chunk["water"][width], WATERWAY_COLOR, width * px, true)
	for chunk: Dictionary in near:
		if not (chunk["minor"] as PackedVector2Array).is_empty():
			layer.draw_multiline(chunk["minor"], ROAD_COLOR, 1.5 * px, true)
	for chunk: Dictionary in near:
		if not (chunk["major"] as PackedVector2Array).is_empty():
			layer.draw_multiline(chunk["major"], MAJOR_ROAD_COLOR, 2.5 * px, true)
	if _route_xz.size() >= 2:
		layer.draw_polyline(_route_xz, ROUTE_CASING, 6.0 * px, true)
		layer.draw_polyline(_route_xz, ROUTE_COLOR, 3.0 * px, true)


func _draw() -> void:
	if _car == null:
		return

	var center_pos := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	var scale_factor := radius / map_radius

	var car_pos := _car.global_position

	
	
	var car_forward := _car.global_transform.basis.z
	
	var car_angle := atan2(car_forward.x, car_forward.z)

	
	draw_set_transform(center_pos)

	_draw_route_gates(car_pos, car_angle, scale_factor, radius)
	if _has_objective:
		var objective := _world_to_minimap(_objective, car_pos, car_angle, scale_factor)
		if objective.length() <= radius - 4.0:
			draw_circle(objective, 7.0, ROUTE_CASING)
			draw_circle(objective, 5.0, FINISH_COLOR)
			draw_arc(objective, 8.0, 0.0, TAU, 20, ROUTE_COLOR, 2.0, true)
		else:
			var objective_dir := objective.normalized()
			var tip := objective_dir * (radius - 3.0)
			var side := Vector2(-objective_dir.y, objective_dir.x) * 6.0
			var base := objective_dir * (radius - 15.0)
			draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), FINISH_COLOR)

	
	draw_circle(Vector2.ZERO, 13, Color(0.835, 0.953, 0.42, 0.12))
	var tri_size := 7.0
	var tri := PackedVector2Array([
		Vector2(0, -tri_size * 1.4),
		Vector2(-tri_size * 0.7, tri_size * 0.7),
		Vector2(tri_size * 0.7, tri_size * 0.7),
	])
	draw_colored_polygon(tri, CAR_COLOR)

	
	draw_arc(Vector2.ZERO, radius - 1.0, 0, TAU, 64, BORDER_COLOR, 1.0, true)
	for i in range(36):
		var direction := Vector2.from_angle(TAU * float(i) / 36.0)
		var length := 7.0 if i % 3 == 0 else 3.0
		draw_line(direction * (radius - length), direction * (radius - 2), BORDER_COLOR, 1, true)

	
	
	
	_draw_north_arrow(car_angle, radius)

	draw_set_transform(Vector2.ZERO)





func _draw_route_gates(car_pos: Vector3, car_angle: float, scale_factor: float, radius: float) -> void:
	if _route.is_empty():
		return
	var last := _route_gates.size() - 1
	for i: int in range(last, _next_gate - 1, -1):
		var p := _world_to_minimap(_route_gates[i], car_pos, car_angle, scale_factor)
		if p.length() > radius - 4.0:
			continue
		var color := FINISH_COLOR if i == last else ROUTE_COLOR
		if i == _next_gate:
			draw_circle(p, 7.0, ROUTE_CASING)
			draw_arc(p, 7.0, 0, TAU, 24, color, 2.5, true)
		else:
			draw_circle(p, 3.5, color)
	if _next_gate > last:
		return
	var next := _world_to_minimap(_route_gates[_next_gate], car_pos, car_angle, scale_factor)
	if next.length() > radius - 4.0:
		var dir := next.normalized()
		var tip := dir * (radius - 3.0)
		var side := Vector2(-dir.y, dir.x) * 6.0
		var base := dir * (radius - 15.0)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), ROUTE_COLOR)








static func north_screen_direction(car_angle: float) -> Vector2:
	return Vector2(-sin(car_angle), cos(car_angle))





func _draw_north_arrow(car_angle: float, radius: float) -> void:
	
	var north_dir := north_screen_direction(car_angle)
	
	var side_dir := Vector2(-north_dir.y, north_dir.x)

	
	
	var tip_dist := radius + 6.6
	var arrow_len := 14.52
	var half_width := 7.26

	var tip := north_dir * tip_dist
	var base := north_dir * (tip_dist - arrow_len)
	var left := base + side_dir * half_width
	var right := base - side_dir * half_width

	var arrow := PackedVector2Array([tip, left, right])
	draw_colored_polygon(arrow, NORTH_COLOR)
	
	var outline := PackedVector2Array([tip, left, right, tip])
	draw_polyline(outline, NORTH_BORDER_COLOR, 1.5, true)


func _world_to_minimap(world_pos: Vector3, car_pos: Vector3, car_angle: float, scale_factor: float) -> Vector2:
	var dx := world_pos.x - car_pos.x
	var dz := world_pos.z - car_pos.z

	
	
	
	
	
	
	

	var sin_a := sin(car_angle)
	var cos_a := cos(car_angle)
	var sx := -(dx * cos_a - dz * sin_a)
	var sy := -(dx * sin_a + dz * cos_a)

	return Vector2(sx, sy) * scale_factor
