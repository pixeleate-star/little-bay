class_name RoadJunctionSolver
extends RefCounted









































class Arm extends RefCounted:
	
	var way_id: int = 0
	
	var node_id: int = 0
	
	var dir: Vector3 = Vector3.ZERO
	
	var bearing: float = 0.0
	
	var half_width: float = 0.0
	
	var highway_type: String = ""
	
	
	
	var at_way_start: bool = true
	
	
	var trim: float = 0.0
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	var polyline: PackedVector3Array = PackedVector3Array()

	
	
	
	func point_at(origin: Vector3, distance: float) -> Vector3:
		if polyline.size() >= 2:
			var p := _walk(distance)
			return Vector3(p.x, origin.y, p.z)
		return Vector3(
			origin.x + dir.x * distance,
			origin.y,
			origin.z + dir.z * distance)

	
	
	
	
	
	
	
	
	func dir_at(distance: float) -> Vector3:
		var n := polyline.size()
		if n < 2:
			return dir
		var travelled := 0.0
		var last := dir
		for i: int in range(n - 1):
			var seg := _seg_dir(i)
			if seg == Vector3.ZERO:
				continue
			last = seg
			var seg_len := _seg_len(i)
			if travelled + seg_len > distance + 0.01:
				return last
			travelled += seg_len
		return last

	
	
	func lateral() -> Vector3:
		return Vector3(-dir.z, 0.0, dir.x)

	
	
	func lateral_at(distance: float) -> Vector3:
		var d := dir_at(distance)
		return Vector3(-d.z, 0.0, d.x)

	
	
	
	
	func _walk(distance: float) -> Vector3:
		var n := polyline.size()
		if distance <= 0.0:
			return polyline[0]
		var travelled := 0.0
		var last_i := -1
		for i: int in range(n - 1):
			var seg_len := _seg_len(i)
			if seg_len <= 0.0001:
				continue
			last_i = i
			if travelled + seg_len >= distance:
				return polyline[i].lerp(
					polyline[i + 1], (distance - travelled) / seg_len)
			travelled += seg_len
		if last_i < 0:
			return polyline[0]
		var tail := polyline[last_i + 1]
		var over := distance - travelled
		var d := _seg_dir(last_i)
		return Vector3(tail.x + d.x * over, tail.y, tail.z + d.z * over)

	
	func _seg_len(i: int) -> float:
		var a := polyline[i]
		var b := polyline[i + 1]
		var dx := b.x - a.x
		var dz := b.z - a.z
		return sqrt(dx * dx + dz * dz)

	
	func _seg_dir(i: int) -> Vector3:
		var a := polyline[i]
		var b := polyline[i + 1]
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if d.length_squared() < 0.000001:
			return Vector3.ZERO
		return d.normalized()



class Junction extends RefCounted:
	
	var node_id: int = 0
	
	var center: Vector3 = Vector3.ZERO
	
	var arms: Array[Arm] = []
	
	
	
	var cap: PackedVector3Array = PackedVector3Array()
	
	
	
	
	
	var raw_cap: PackedVector3Array = PackedVector3Array()
	
	
	var dominant_type: String = ""
	
	var max_half_width: float = 0.0

	
	
	
	func trim_for(way_id: int, at_way_start: bool) -> float:
		for arm: Arm in arms:
			if arm.way_id == way_id and arm.at_way_start == at_way_start:
				return arm.trim
		return 0.0





const MIN_ARMS := 3





const MAX_TRIM := 14.0












const TRIM_SETBACK := 0.0
















const FILLET_SEGMENTS := 0




const MIN_ARM_SEPARATION := 0.12  









const CORNER_SOLVE_PASSES := 4


















static func find_junction_nodes(
		ways: Array, nodes: Dictionary, is_road_fn: Callable) -> Dictionary:
	var arm_count: Dictionary = {}
	for way: OSMParser.OSMWay in ways:
		if not is_road_fn.call(way):
			continue
		var n := way.node_ids.size()
		if n < 2:
			continue
		
		
		
		var seen: Dictionary = {}
		for i: int in range(n):
			var nid: int = way.node_ids[i]
			if not nodes.has(nid):
				continue
			
			
			var arms_here := 2 if (i > 0 and i < n - 1) else 1
			
			
			seen[nid] = int(seen.get(nid, 0)) + arms_here
		for nid: int in seen:
			arm_count[nid] = int(arm_count.get(nid, 0)) + int(seen[nid])

	var junctions: Dictionary = {}
	for nid: int in arm_count:
		if int(arm_count[nid]) >= MIN_ARMS:
			junctions[nid] = true
	return junctions








static func solve_all(
		ways: Array, nodes: Dictionary,
		is_road_fn: Callable, width_fn: Callable) -> Dictionary:
	var junction_nodes := find_junction_nodes(ways, nodes, is_road_fn)
	if junction_nodes.is_empty():
		return {}

	
	var arms_by_node: Dictionary = {}   
	for way: OSMParser.OSMWay in ways:
		if not is_road_fn.call(way):
			continue
		for arm: Arm in _arms_of_way(way, nodes, junction_nodes, width_fn):
			if not arms_by_node.has(arm.node_id):
				arms_by_node[arm.node_id] = ([] as Array[Arm])
			(arms_by_node[arm.node_id] as Array[Arm]).append(arm)

	var out: Dictionary = {}
	for nid: int in arms_by_node:
		var junction := _solve_one(nid, arms_by_node[nid], nodes[nid].local_pos)
		if junction != null:
			out[nid] = junction
	return out








static func _arms_of_way(
		way: OSMParser.OSMWay, nodes: Dictionary,
		junction_nodes: Dictionary, width_fn: Callable) -> Array[Arm]:
	var out: Array[Arm] = []
	var n := way.node_ids.size()
	if n < 2:
		return out

	var width: float = width_fn.call(way)
	if width <= 0.0:
		return out
	var half_w := width * 0.5
	var highway_type: String = way.tags.get("highway", "unclassified")

	for i: int in range(n):
		var nid: int = way.node_ids[i]
		if not junction_nodes.has(nid) or not nodes.has(nid):
			continue
		var here: Vector3 = nodes[nid].local_pos

		
		
		if i < n - 1:
			var fwd := _dir_between(here, nodes, way.node_ids, i, 1)
			if fwd != Vector3.ZERO:
				var arm := _make_arm(
					way.id, nid, fwd, half_w, highway_type, true)
				arm.polyline = _centreline_from(way, nodes, i, 1)
				out.append(arm)

		
		
		if i > 0:
			var bwd := _dir_between(here, nodes, way.node_ids, i, -1)
			if bwd != Vector3.ZERO:
				var arm := _make_arm(
					way.id, nid, bwd, half_w, highway_type, false)
				arm.polyline = _centreline_from(way, nodes, i, -1)
				out.append(arm)
	return out
















static func _centreline_from(
		way: OSMParser.OSMWay, nodes: Dictionary, i: int,
		step: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not nodes.has(way.node_ids[i]):
		return out
	out.append(nodes[way.node_ids[i]].local_pos)

	var banked := 0.0
	var j := i + step
	while j >= 0 and j < way.node_ids.size():
		var nid: int = way.node_ids[j]
		if nodes.has(nid):
			var p: Vector3 = nodes[nid].local_pos
			var prev := out[out.size() - 1]
			var dx := p.x - prev.x
			var dz := p.z - prev.z
			var seg := sqrt(dx * dx + dz * dz)
			if seg > 0.0001:
				out.append(p)
				banked += seg
				if banked >= MAX_TRIM:
					break
		j += step
	return out






static func _dir_between(
		here: Vector3, nodes: Dictionary, node_ids: Array[int],
		i: int, step: int) -> Vector3:
	var j := i + step
	while j >= 0 and j < node_ids.size():
		var nid: int = node_ids[j]
		if nodes.has(nid):
			var there: Vector3 = nodes[nid].local_pos
			var d := Vector3(there.x - here.x, 0.0, there.z - here.z)
			if d.length_squared() > 0.000001:
				return d.normalized()
		j += step
	return Vector3.ZERO


static func _make_arm(
		way_id: int, node_id: int, dir: Vector3, half_width: float,
		highway_type: String, at_way_start: bool) -> Arm:
	var arm := Arm.new()
	arm.way_id = way_id
	arm.node_id = node_id
	arm.dir = dir
	arm.bearing = atan2(dir.z, dir.x)
	arm.half_width = half_width
	arm.highway_type = highway_type
	arm.at_way_start = at_way_start
	return arm




static func _solve_one(node_id: int, arms_in: Array, center: Vector3) -> Junction:
	var arms: Array[Arm] = []
	for a: Arm in arms_in:
		arms.append(a)
	if arms.size() < MIN_ARMS:
		return null

	
	
	
	arms.sort_custom(func(a: Arm, b: Arm) -> bool:
		if is_equal_approx(a.bearing, b.bearing):
			return a.way_id < b.way_id
		return a.bearing < b.bearing)

	arms = _drop_near_duplicate_arms(arms)
	if arms.size() < MIN_ARMS:
		return null

	
	
	var count := arms.size()
	var corner_dist: Array[float] = []
	corner_dist.resize(count)
	for i: int in range(count):
		var a: Arm = arms[i]
		var b: Arm = arms[(i + 1) % count]
		corner_dist[i] = _corner_distance(a, b, center)

	
	
	for i: int in range(count):
		var prev_corner: float = corner_dist[(i - 1 + count) % count]
		var here_corner: float = corner_dist[i]
		var trim := maxf(prev_corner, here_corner) + TRIM_SETBACK
		arms[i].trim = clampf(trim, 0.0, MAX_TRIM)

	var junction := Junction.new()
	junction.node_id = node_id
	junction.center = center
	junction.arms = arms
	junction.raw_cap = _build_cap_walk(arms, center)
	junction.cap = _ensure_simple(junction.raw_cap, center)
	for arm: Arm in arms:
		if arm.half_width > junction.max_half_width:
			junction.max_half_width = arm.half_width
			junction.dominant_type = arm.highway_type
	return junction





static func _drop_near_duplicate_arms(arms: Array[Arm]) -> Array[Arm]:
	if arms.size() < 2:
		return arms
	var out: Array[Arm] = []
	for arm: Arm in arms:
		var merged := false
		for i: int in range(out.size()):
			if _angle_between(out[i].bearing, arm.bearing) < MIN_ARM_SEPARATION:
				
				if arm.half_width > out[i].half_width:
					out[i] = arm
				merged = true
				break
		if not merged:
			out.append(arm)
	return out



static func _angle_between(a: float, b: float) -> float:
	var d := fposmod(a - b, TAU)
	if d > PI:
		d = TAU - d
	return d





































static func _corner_distance(a: Arm, b: Arm, center: Vector3) -> float:
	var theta := _angle_between(a.bearing, b.bearing)
	
	if theta < MIN_ARM_SEPARATION or theta > PI - 0.001:
		return maxf(a.half_width, b.half_width)

	var floor_d := maxf(a.half_width, b.half_width)
	var ta := 0.0
	var tb := 0.0
	for _pass: int in range(CORNER_SOLVE_PASSES):
		
		
		var a_dir := a.dir_at(ta)
		var b_dir := b.dir_at(tb)
		var a_edge := a.point_at(center, ta) + a.lateral_at(ta) * a.half_width
		var b_edge := b.point_at(center, tb) - b.lateral_at(tb) * b.half_width

		var hit := _ray_intersect_xz(a_edge, a_dir, b_edge, b_dir)
		if not hit.hit:
			return floor_d
		var p := hit.point

		
		
		var next_a := ta + (p.x - a_edge.x) * a_dir.x + (p.z - a_edge.z) * a_dir.z
		var next_b := tb + (p.x - b_edge.x) * b_dir.x + (p.z - b_edge.z) * b_dir.z
		next_a = clampf(next_a, 0.0, MAX_TRIM)
		next_b = clampf(next_b, 0.0, MAX_TRIM)
		
		if absf(next_a - ta) < 0.001 and absf(next_b - tb) < 0.001:
			ta = next_a
			tb = next_b
			break
		ta = next_a
		tb = next_b

	
	
	return clampf(maxf(ta, tb), floor_d, MAX_TRIM)





class LineHit extends RefCounted:
	var hit: bool = false
	var point: Vector3 = Vector3.ZERO

	func _init(p_hit: bool = false, p_point: Vector3 = Vector3.ZERO) -> void:
		hit = p_hit
		point = p_point




static func _ray_intersect_xz(
		p0: Vector3, d0: Vector3, p1: Vector3, d1: Vector3) -> LineHit:
	var denom := d0.x * d1.z - d0.z * d1.x
	if absf(denom) < 0.000001:
		return LineHit.new(false)
	var dx := p1.x - p0.x
	var dz := p1.z - p0.z
	var t := (dx * d1.z - dz * d1.x) / denom
	return LineHit.new(true, Vector3(p0.x + d0.x * t, 0.0, p0.z + d0.z * t))
























static func _build_cap_walk(arms: Array[Arm], center: Vector3) -> PackedVector3Array:
	var walk := PackedVector3Array()
	var count := arms.size()
	if count < MIN_ARMS:
		return walk

	for i: int in range(count):
		var arm: Arm = arms[i]
		var mouth := arm.point_at(center, arm.trim)
		
		
		
		
		
		var lat := arm.lateral_at(arm.trim) * arm.half_width
		walk.append(Vector3(mouth.x - lat.x, center.y, mouth.z - lat.z))
		walk.append(Vector3(mouth.x + lat.x, center.y, mouth.z + lat.z))
	return _drop_coincident(walk)













static func _drop_coincident(poly: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := poly.size()
	for i: int in range(n):
		var p := poly[i]
		var q := poly[(i + 1) % n]
		if Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)) > 0.001:
			out.append(p)
	return out















static func _ensure_simple(
		cap: PackedVector3Array, center: Vector3) -> PackedVector3Array:
	if cap.size() < 3:
		return cap
	
	
	var flat := PackedVector2Array()
	for p: Vector3 in cap:
		flat.append(Vector2(p.x, p.z))
	if Geometry2D.triangulate_polygon(flat).size() >= 3:
		return cap

	var hull := Geometry2D.convex_hull(flat)
	if hull.size() < 3:
		return cap  
	var out := PackedVector3Array()
	for p: Vector2 in hull:
		out.append(Vector3(p.x, center.y, p.y))
	
	
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) < 0.001:
		out.remove_at(out.size() - 1)
	return out
