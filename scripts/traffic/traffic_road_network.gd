class_name TrafficRoadNetwork
extends RefCounted


















class Road:
	
	
	
	
	
	
	var segment_id: int = -1
	
	
	var way_id: int = 0
	
	var highway_type: String = ""
	
	var points: PackedVector3Array = PackedVector3Array()
	
	
	var width: float = 0.0
	
	var length: float = 0.0
	
	var one_way: bool = false
	
	
	var capacity: int = 0
	
	
	
	var start_node: int = 0
	var end_node: int = 0
	
	
	var name: String = ""
	var ref: String = ""




const DRIVABLE_TYPES := {
	"motorway": true,
	"motorway_link": true,
	"trunk": true,
	"trunk_link": true,
	"primary": true,
	"primary_link": true,
	"secondary": true,
	"secondary_link": true,
	"tertiary": true,
	"tertiary_link": true,
	"residential": true,
	"living_street": true,
	"unclassified": true,
	"service": true,
}



const ROAD_WIDTHS := {
	"motorway": 12.0,
	"motorway_link": 6.0,
	"trunk": 10.0,
	"trunk_link": 5.0,
	"primary": 8.0,
	"primary_link": 4.5,
	"secondary": 7.0,
	"secondary_link": 4.0,
	"tertiary": 6.0,
	"tertiary_link": 3.5,
	"residential": 5.0,
	"living_street": 4.0,
	"service": 3.0,
	"unclassified": 5.0,
}
const DEFAULT_WIDTH := 4.0





const METERS_PER_CAR := 90.0


const MIN_DRIVABLE_WIDTH := 2.5


const LANE_WIDTH := 3.5

var _roads: Array[Road] = []



var _by_way_id: Dictionary = {}




var _by_node: Dictionary = {}



func build(osm_data: OSMParser.OSMData) -> void:
	_roads.clear()
	_by_way_id.clear()
	_by_node.clear()
	if osm_data == null:
		return
	
	
	
	
	
	
	
	var junctions := _find_junction_nodes(osm_data)
	for way: OSMParser.OSMWay in osm_data.ways.values():
		for road: Road in _roads_from_way(way, osm_data, junctions):
			
			
			
			
			
			
			
			
			
			road.segment_id = _segment_id_for(road.way_id, road.start_node, road.end_node)
			_roads.append(road)
			_by_way_id[road.segment_id] = road
	_build_junction_index()







static func _segment_id_for(way_id: int, start_node: int, end_node: int) -> int:
	var lo: int = min(start_node, end_node)
	var hi: int = max(start_node, end_node)
	
	
	var h: int = way_id * 1099511628211
	h = (h ^ lo) * 1099511628211
	h = (h ^ hi) * 1099511628211
	return (h & 0x7fffffffffffffff) | 1






func _find_junction_nodes(osm_data: OSMParser.OSMData) -> Dictionary:
	var use_count: Dictionary = {}
	for way: OSMParser.OSMWay in osm_data.ways.values():
		if not _is_drivable_way(way):
			continue
		
		
		
		var seen: Dictionary = {}
		for nid: int in way.node_ids:
			if not osm_data.nodes.has(nid) or seen.has(nid):
				continue
			seen[nid] = true
			use_count[nid] = int(use_count.get(nid, 0)) + 1
	var junctions: Dictionary = {}
	for nid: int in use_count:
		if int(use_count[nid]) >= 2:
			junctions[nid] = true
	return junctions




func _build_junction_index() -> void:
	for road: Road in _roads:
		_add_to_node(road.start_node, road)
		if road.end_node != road.start_node:
			_add_to_node(road.end_node, road)


func _add_to_node(node_id: int, road: Road) -> void:
	if not _by_node.has(node_id):
		_by_node[node_id] = ([] as Array[Road])
	(_by_node[node_id] as Array[Road]).append(road)



func get_roads() -> Array[Road]:
	return _roads



func road_count() -> int:
	return _roads.size()





func total_capacity() -> int:
	var total := 0
	for road: Road in _roads:
		total += road.capacity
	return total







func nearest_point(pos: Vector3, min_width: float = 0.0) -> Dictionary:
	var target := Vector2(pos.x, pos.z)
	var best := {}
	var best_d2 := INF
	for road: Road in _roads:
		if road.width < min_width:
			continue
		var pts := road.points
		for i: int in range(pts.size() - 1):
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			var seg_len := a.distance_to(b)
			if seg_len < 0.001:
				continue
			var q := Geometry2D.get_closest_point_to_segment(target, a, b)
			var d2 := target.distance_squared_to(q)
			if d2 >= best_d2:
				continue
			best_d2 = d2
			var along := a.distance_to(q) / seg_len
			best = {
				"road": road,
				"position": pts[i].lerp(pts[i + 1], along),
				"direction": Vector3(b.x - a.x, 0.0, b.y - a.y) / seg_len,
				"index": i,
			}
	if not best.is_empty():
		best["distance"] = sqrt(best_d2)
	return best






func road_under(pos: Vector3, heading: Vector3, margin: float = 1.5) -> Road:
	var flat_heading := Vector2(heading.x, heading.z)
	if flat_heading.length_squared() > 0.0001:
		flat_heading = flat_heading.normalized()
	var target := Vector2(pos.x, pos.z)
	var best: Road = null
	var best_alignment := -1.0
	var best_dist := INF
	for road: Road in _roads:
		var reach := road.width * 0.5 + margin
		var pts := road.points
		for i: int in range(pts.size() - 1):
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			if a.distance_squared_to(b) < 0.000001:
				continue
			var dist := target.distance_to(Geometry2D.get_closest_point_to_segment(target, a, b))
			if dist > reach:
				continue
			var alignment := absf((b - a).normalized().dot(flat_heading))
			if alignment > best_alignment + 0.01 \
					or (absf(alignment - best_alignment) <= 0.01 and dist < best_dist):
				best = road
				best_alignment = alignment
				best_dist = dist
	return best



static func is_drivable(highway_type: String) -> bool:
	return DRIVABLE_TYPES.has(highway_type)





func find_road(segment_id: int) -> Road:
	return _by_way_id.get(segment_id, null)




func roads_at_node(node_id: int) -> Array[Road]:
	return _by_node.get(node_id, ([] as Array[Road]))












func next_road(road: Road, exiting_at_end: bool, rng: RandomNumberGenerator) -> Continuation:
	if road == null:
		return null
	var junction: int = road.end_node if exiting_at_end else road.start_node
	var candidates := roads_at_node(junction)
	
	
	
	var options: Array[Continuation] = []
	for other: Road in candidates:
		if other == road:
			continue
		
		if other.start_node == junction:
			options.append(Continuation.new(other, false))
		
		
		if other.end_node == junction and not other.one_way:
			options.append(Continuation.new(other, true))
	if options.is_empty():
		return null

	var incoming := _exit_direction(road, exiting_at_end)

	
	
	options.sort_custom(func(a: Continuation, b: Continuation) -> bool:
		return _straightness(incoming, a) > _straightness(incoming, b))

	if options.size() == 1:
		return options[0]

	
	
	
	
	var forward: Array[Continuation] = []
	for opt: Continuation in options:
		if _straightness(incoming, opt) > _U_TURN_COS:
			forward.append(opt)
	var pool := forward if forward.size() > 0 else options

	if pool.size() == 1:
		return pool[0]

	
	
	
	return _weighted_pick(pool, incoming, rng)















func plan_route(road: Road, reversed: bool, steps: int, rng: RandomNumberGenerator) -> Array[Continuation]:
	var route: Array[Continuation] = []
	if road == null or steps <= 0:
		return route
	var current := road
	var current_reversed := reversed
	var prev_segment_id := -1
	for _i: int in range(steps):
		
		
		var exiting_at_end := not current_reversed
		var cont := next_road(current, exiting_at_end, rng)
		if cont == null:
			break
		
		
		
		if cont.road.segment_id == prev_segment_id:
			var retry := next_road(current, exiting_at_end, rng)
			if retry == null or retry.road.segment_id == prev_segment_id:
				break
			cont = retry
		route.append(cont)
		prev_segment_id = current.segment_id
		current = cont.road
		current_reversed = cont.reversed
	return route




const _U_TURN_COS := -0.3





static func _weighted_pick(pool: Array[Continuation], incoming: Vector3, rng: RandomNumberGenerator) -> Continuation:
	var weights: Array[float] = []
	var total := 0.0
	for opt: Continuation in pool:
		
		var s := (_straightness(incoming, opt) + 1.0) * 0.5
		var w: float = pow(maxf(s, 0.01), 3.0)
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i: int in range(pool.size()):
		r -= weights[i]
		if r <= 0.0:
			return pool[i]
	return pool[0]





class Continuation:
	var road: Road
	var reversed: bool

	func _init(r: Road, rev: bool) -> void:
		road = r
		reversed = rev



static func _exit_direction(road: Road, exiting_at_end: bool) -> Vector3:
	var pts := road.points
	var n := pts.size()
	if n < 2:
		return Vector3.ZERO
	var d: Vector3
	if exiting_at_end:
		d = pts[n - 1] - pts[n - 2]
	else:
		d = pts[0] - pts[1]
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO





static func _straightness(incoming: Vector3, cont: Continuation) -> float:
	var pts := cont.road.points
	var n := pts.size()
	if n < 2 or incoming == Vector3.ZERO:
		return 0.0
	var d: Vector3
	if cont.reversed:
		d = pts[n - 2] - pts[n - 1]
	else:
		d = pts[1] - pts[0]
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return 0.0
	return incoming.dot(d.normalized())





static func capacity_for(length: float, width: float) -> int:
	if width < MIN_DRIVABLE_WIDTH or length <= 0.0:
		return 0
	var lanes: float = maxf(1.0, width / LANE_WIDTH)
	var cars: float = (length / METERS_PER_CAR) * lanes
	return int(floor(cars))







static func _is_drivable_way(way: OSMParser.OSMWay) -> bool:
	if not way.tags.has("highway"):
		return false
	if not is_drivable(String(way.tags["highway"])):
		return false
	
	
	return way.tags.get("area", "no") != "yes"














func _roads_from_way(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData, junctions: Dictionary) -> Array[Road]:
	var out: Array[Road] = []
	if not _is_drivable_way(way):
		return out

	
	
	var present_ids: Array[int] = []
	for nid: int in way.node_ids:
		if osm_data.nodes.has(nid):
			present_ids.append(nid)
	if present_ids.size() < 2:
		return out

	var highway_type: String = String(way.tags["highway"])
	var width := _width_for_way(way, highway_type)
	var one_way := _is_one_way(way.tags)

	
	
	
	
	var seg_start := 0
	for i: int in range(1, present_ids.size()):
		var is_last := i == present_ids.size() - 1
		var is_junction: bool = junctions.has(present_ids[i])
		if is_junction or is_last:
			var seg := _make_segment(
				way.id, highway_type, width, one_way,
				present_ids, seg_start, i, osm_data)
			if seg != null:
				seg.name = String(way.tags.get("name", ""))
				seg.ref = String(way.tags.get("ref", ""))
				out.append(seg)
			seg_start = i
	return out




func _make_segment(
		way_id: int, highway_type: String, width: float, one_way: bool,
		present_ids: Array[int], from: int, to: int,
		osm_data: OSMParser.OSMData) -> Road:
	if to - from < 1:
		return null
	var span_ids: Array[int] = present_ids.slice(from, to + 1)
	var points := PolygonUtils.way_to_points(span_ids, osm_data.nodes)
	if points.size() < 2:
		return null
	var length := _polyline_length(points)
	if length <= 0.0:
		return null
	var road := Road.new()
	road.way_id = way_id
	road.highway_type = highway_type
	road.points = points
	road.width = width
	road.length = length
	road.one_way = one_way
	road.capacity = capacity_for(length, width)
	road.start_node = span_ids[0]
	road.end_node = span_ids[span_ids.size() - 1]
	return road




static func _width_for_way(way: OSMParser.OSMWay, highway_type: String) -> float:
	var width: float = ROAD_WIDTHS.get(highway_type, DEFAULT_WIDTH)
	if way.tags.has("lanes"):
		var lanes: int = String(way.tags["lanes"]).to_int()
		if lanes > 0:
			width = lanes * LANE_WIDTH
	if way.tags.has("width"):
		var explicit: float = String(way.tags["width"]).to_float()
		if explicit > 0.0:
			width = explicit
	return width



static func _polyline_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total






static func _is_one_way(tags: Dictionary) -> bool:
	
	var junction: String = String(tags.get("junction", ""))
	if junction == "roundabout" or junction == "circular":
		return true
	var v: String = String(tags.get("oneway", "no"))
	return v == "yes" or v == "true" or v == "1"
