class_name TrafficManager
extends Node3D






















@export var active_radius: float = 260.0


@export var recycle_radius: float = 340.0


@export var max_cars: int = 40



@export var refresh_interval: float = 0.75



@export var detail_distance: float = 90.0


@export var car_path: NodePath

@export var tile_manager_path: NodePath












const _NETWORK_REBUILD_THRESHOLD := 200.0


const TRAFFIC_CAR_SCENE := preload("res://scenes/traffic_car.tscn")




const FrameTracerScript := preload("res://scripts/frame_tracer.gd")


const _SPEED_MIN := 5.0
const _SPEED_MAX := 11.0


const _SPAWN_CLEARANCE := 11.0
const _SPAWN_ATTEMPTS := 24

var _network := TrafficRoadNetwork.new()
var _car: Node3D = null
var _tile_manager: OSMTileManager = null



















var _rebuild_thread: Thread = null
var _rebuild_center: Vector3 = Vector3.ZERO
var _pending_network: TrafficRoadNetwork = null
var _rebuild_done: bool = false
var _rebuild_mutex := Mutex.new()
var _use_threads: bool = true

var _cars: Array[TrafficCar] = []
var _refresh_accum: float = 0.0


var _rng := RandomNumberGenerator.new()





var _routes: Dictionary = {}




const _PLAN_AHEAD := 6



const _SPAWN_MIN_WIDTH := 4.0



var _network_center: Vector3 = Vector3.ZERO
var _network_built: bool = false
var _last_reported_count := -1


func _ready() -> void:
	_rng.randomize()
	
	
	
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_car = get_node_or_null(car_path) as Node3D
	_tile_manager = get_node_or_null(tile_manager_path) as OSMTileManager
	if _tile_manager == null:
		push_warning("TrafficManager: no tile manager wired; traffic disabled")
		return
	
	
	
	
	if _tile_manager.is_data_ready():
		_on_data_loaded(null)
	else:
		_tile_manager.data_loaded.connect(_on_data_loaded)







func _exit_tree() -> void:
	if _rebuild_thread != null:
		_rebuild_thread.wait_to_finish()
		_rebuild_thread = null
	_pending_network = null


func _on_data_loaded(_osm_data: OSMParser.OSMData) -> void:
	
	
	
	
	if _car != null:
		_rebuild_network_sync(_car.global_position)
		_refresh_population()












func _build_radius() -> float:
	var ts := _tile_manager.tile_size if _tile_manager != null else 200.0
	return maxf(recycle_radius + ts, 400.0)





func _build_network_for(center: Vector3) -> TrafficRoadNetwork:
	
	
	
	var t0 := Time.get_ticks_usec()
	
	
	
	var yield_every := 4 if _use_threads else 0
	var osm_data := _tile_manager.collect_osm_near(center, _build_radius(), yield_every)
	var t1 := Time.get_ticks_usec()
	FrameTracerScript.record_usec("traffic_collect_osm", t1 - t0)
	var net := TrafficRoadNetwork.new()
	net.build(osm_data)
	FrameTracerScript.record_usec("traffic_network_build", Time.get_ticks_usec() - t1)
	return net






func _adopt_network(net: TrafficRoadNetwork, center: Vector3) -> void:
	
	
	var _trace := FrameTracerScript.scope("traffic_adopt_network")
	_network = net
	_network_center = center
	_network_built = true
	for c: TrafficCar in _cars:
		var wid := c.current_way_id()
		if wid != -1 and _network.find_road(wid) == null:
			_routes.erase(c.get_instance_id())





func _rebuild_network_sync(center: Vector3) -> void:
	_adopt_network(_build_network_for(center), center)






func _request_rebuild(center: Vector3) -> void:
	if _rebuild_thread != null:
		return  
	if not _use_threads:
		_rebuild_network_sync(center)
		_refresh_population()
		return
	_rebuild_center = center
	_rebuild_mutex.lock()
	_rebuild_done = false
	_rebuild_mutex.unlock()
	_rebuild_thread = Thread.new()
	
	
	_rebuild_thread.start(_rebuild_thread_body)






func _rebuild_thread_body() -> void:
	var t0 := Time.get_ticks_usec()
	var net := _build_network_for(_rebuild_center)
	FrameTracerScript.record_usec("traffic_rebuild_task", Time.get_ticks_usec() - t0)
	_rebuild_mutex.lock()
	_pending_network = net
	_rebuild_done = true
	_rebuild_mutex.unlock()





func _collect_finished_rebuild() -> void:
	if _rebuild_thread == null:
		return
	_rebuild_mutex.lock()
	var done := _rebuild_done
	_rebuild_mutex.unlock()
	if not done:
		return
	_rebuild_thread.wait_to_finish()  
	_rebuild_thread = null
	if _pending_network != null:
		_adopt_network(_pending_network, _rebuild_center)
		_pending_network = null
		_refresh_population()


func _physics_process(delta: float) -> void:
	if _car == null:
		return

	
	_collect_finished_rebuild()

	
	
	
	
	
	
	if _tile_manager != null and _tile_manager.is_data_ready():
		if not _network_built:
			
			_rebuild_network_sync(_car.global_position)
			_refresh_population()
		elif _car.global_position.distance_to(_network_center) > _NETWORK_REBUILD_THRESHOLD:
			
			_request_rebuild(_car.global_position)

	if _network.road_count() == 0:
		return
	
	
	
	_advance_finished_cars()
	
	
	_update_car_lod()

	_refresh_accum += delta
	if _refresh_accum >= refresh_interval:
		_refresh_accum = 0.0
		_refresh_population()






func _refresh_population() -> void:
	if _car == null:
		return
	
	
	var _trace := FrameTracerScript.scope("traffic_refresh_population")
	var center := _car.global_position
	var plans := TrafficSpawnPolicy.select_active_roads(
		_network.get_roads(), center, active_radius, max_cars)

	
	
	
	var free_cars: Array[TrafficCar] = []
	for c: TrafficCar in _cars:
		if c.current_way_id() == -1 or _out_of_range(c.global_position, center, recycle_radius):
			free_cars.append(c)

	for plan: TrafficSpawnPolicy.RoadPlan in plans:
		var have := _count_cars_on_road(plan.road)
		var need := plan.desired_cars - have
		while need > 0:
			var car := _take_free_car(free_cars)
			if car == null:
				if _cars.size() >= max_cars:
					return  
				car = _spawn_car()
			if _assign_to_road(car, plan.road, _rng.randf_range(0.0, maxf(0.0, plan.road.length))):
				need -= 1
			else:
				
				
				car.set_route(PackedVector3Array(), 0.0, -1)
				_routes.erase(car.get_instance_id())
				car.visible = false
				free_cars.append(car)
				break
	if _cars.size() != _last_reported_count:
		_last_reported_count = _cars.size()
		print("[traffic] live=%d routed=%d roads=%d" % [_cars.size(), _routed_car_count(), _network.road_count()])






func _advance_finished_cars() -> void:
	var center := _car.global_position
	for c: TrafficCar in _cars:
		if c.current_way_id() == -1 or not c.is_finished():
			continue
		
		
		if _out_of_range(c.global_position, center, recycle_radius):
			c.set_route(PackedVector3Array(), 0.0, -1)
			_routes.erase(c.get_instance_id())
			continue
		if not _continue_car(c):
			
			c.set_route(PackedVector3Array(), 0.0, -1)
			_routes.erase(c.get_instance_id())






func _continue_car(car: TrafficCar) -> bool:
	var road := _network.find_road(car.current_way_id())
	if road == null:
		return false
	
	
	
	
	var cont := _next_planned_continuation(car, road)
	if cont == null:
		return false
	var path := _reverse_points(cont.road.points) if cont.reversed else cont.road.points
	car.continue_route(path, car.overshoot(), cont.road.segment_id, cont.reversed, _lane_offset_for(cont.road))
	return true






func _next_planned_continuation(car: TrafficCar, road: TrafficRoadNetwork.Road) -> TrafficRoadNetwork.Continuation:
	var key := car.get_instance_id()
	var plan: Array = _routes.get(key, [])
	
	
	if not plan.is_empty():
		var head: TrafficRoadNetwork.Continuation = plan[0]
		if not _connects(road, car.is_reversed(), head):
			plan = []
	if plan.is_empty():
		plan = _network.plan_route(road, car.is_reversed(), _PLAN_AHEAD, _rng)
	if plan.is_empty():
		_routes.erase(key)
		return null
	var cont: TrafficRoadNetwork.Continuation = plan.pop_front()
	_routes[key] = plan
	return cont




static func _connects(road: TrafficRoadNetwork.Road, reversed: bool, cont: TrafficRoadNetwork.Continuation) -> bool:
	var junction: int = road.start_node if reversed else road.end_node
	var enter: int = cont.road.end_node if cont.reversed else cont.road.start_node
	return junction == enter












func _assign_to_road(car: TrafficCar, road: TrafficRoadNetwork.Road, start_distance: float, reversed: bool = false) -> bool:
	
	
	if not reversed and not road.one_way:
		reversed = _rng.randf() < 0.5
	var path := _reverse_points(road.points) if reversed else road.points
	var lane_offset := _lane_offset_for(road)
	var chosen_distance := clampf(start_distance, 0.0, maxf(0.0, road.length))
	var safe_position := _spawn_position_on_path(path, chosen_distance, lane_offset)
	var found_clear_slot := false
	for _attempt: int in range(_SPAWN_ATTEMPTS):
		if _spawn_slot_is_clear(safe_position, car):
			found_clear_slot = true
			break
		chosen_distance = _rng.randf_range(0.0, maxf(0.0, road.length))
		safe_position = _spawn_position_on_path(path, chosen_distance, lane_offset)
	if not found_clear_slot:
		return false
	car.cruise_speed = _rng.randf_range(_SPEED_MIN, _SPEED_MAX)
	car.set_route(path, chosen_distance, road.segment_id, reversed, lane_offset)
	car.visible = true
	
	
	
	_routes[car.get_instance_id()] = _network.plan_route(road, reversed, _PLAN_AHEAD, _rng)
	return true


func _spawn_slot_is_clear(candidate: Vector3, ignored: TrafficCar) -> bool:
	if _car != null and candidate.distance_to(_car.global_position) < _SPAWN_CLEARANCE:
		return false
	for other: TrafficCar in _cars:
		if other == ignored or not is_instance_valid(other) or other.current_way_id() == -1:
			continue
		if candidate.distance_to(other.global_position) < _SPAWN_CLEARANCE:
			return false
	return true


func _spawn_position_on_path(path: PackedVector3Array, distance: float, lane_offset: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	var remaining := distance
	for i: int in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var segment := a.distance_to(b)
		if segment <= 0.001:
			continue
		if remaining <= segment:
			var point := a.lerp(b, remaining / segment)
			var forward := b - a
			forward.y = 0.0
			if absf(lane_offset) > 0.001 and forward.length_squared() > 0.001:
				point += forward.normalized().cross(Vector3.UP) * lane_offset
			return point
		remaining -= segment
	var end := path[path.size() - 1]
	return end





func spawn_pose_near(pos: Vector3) -> Dictionary:
	var hit := _network.nearest_point(pos, _SPAWN_MIN_WIDTH)
	if hit.is_empty():
		hit = _network.nearest_point(pos)
	if hit.is_empty():
		return {}
	var forward: Vector3 = hit["direction"]
	var right := forward.cross(Vector3.UP)
	return {
		"position": (hit["position"] as Vector3) + right * _lane_offset_for(hit["road"]),
		"forward": forward,
	}




func road_network() -> TrafficRoadNetwork:
	return _network




func road_under(pos: Vector3, heading: Vector3) -> TrafficRoadNetwork.Road:
	return _network.road_under(pos, heading)










func _lane_offset_for(road: TrafficRoadNetwork.Road) -> float:
	if road.one_way:
		return 0.0
	
	
	return maxf(road.width * 0.25, 0.0)



func _spawn_car() -> TrafficCar:
	var car: TrafficCar = TRAFFIC_CAR_SCENE.instantiate()
	add_child(car)
	_cars.append(car)
	return car



func _take_free_car(free_cars: Array[TrafficCar]) -> TrafficCar:
	while free_cars.size() > 0:
		var c: TrafficCar = free_cars.pop_back()
		if is_instance_valid(c):
			return c
	return null





func _update_car_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	var ref_pos := cam.global_position if cam != null else _car.global_position
	var d2 := detail_distance * detail_distance
	for c: TrafficCar in _cars:
		var dx := c.global_position.x - ref_pos.x
		var dz := c.global_position.z - ref_pos.z
		c.set_detailed(dx * dx + dz * dz <= d2)








func _count_cars_on_road(road: TrafficRoadNetwork.Road) -> int:
	var count := 0
	for c: TrafficCar in _cars:
		if c.current_way_id() == road.segment_id:
			count += 1
	return count



func car_count() -> int:
	return _cars.size()


func _routed_car_count() -> int:
	var count := 0
	for c: TrafficCar in _cars:
		if c.current_way_id() != -1:
			count += 1
	return count



func detailed_car_count() -> int:
	var n := 0
	for c: TrafficCar in _cars:
		if c.is_detailed():
			n += 1
	return n




static func _out_of_range(pos: Vector3, center: Vector3, radius: float) -> bool:
	var dx := pos.x - center.x
	var dz := pos.z - center.z
	return dx * dx + dz * dz > radius * radius


static func _reverse_points(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(points.size())
	var n := points.size()
	for i: int in range(n):
		out[i] = points[n - 1 - i]
	return out
