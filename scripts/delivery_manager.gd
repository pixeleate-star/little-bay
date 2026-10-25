class_name DeliveryManager
extends Node3D

## Small, readable delivery loop for Little Rider. Everything here is procedural
## so the game stays lightweight and does not depend on another asset pack.

const JAM_DARK := Color("2d272f")
const JAM_GREEN := Color("6ea16e")
const JAM_TEAL := Color("009b88")
const JAM_MAUVE := Color("8f5676")
const JAM_BLUE := Color("415d99")
const DELIVERIES_PER_BATCH: int = 5
const MIN_DELIVERY_DISTANCE_M: float = 300.0

var _player: CarController
var _traffic: TrafficManager
var _jobs: Array[Dictionary] = []
var _job_index: int = 0
var _carrying: bool = false
var _complete: bool = false
var _completed_deliveries: int = 0
var _pickup_node: Node3D
var _drop_node: Node3D
var _status_label: Label
var _status_refresh := 0.0
var _minimap: Node = null

func setup(player: CarController, traffic: TrafficManager) -> void:
	_player = player
	_traffic = traffic
	_minimap = get_node_or_null("../HUD/Minimap")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_status_panel()
	_build_jobs()

func _process(_delta: float) -> void:
	if _player == null or _complete or _jobs.is_empty():
		return
	var target: Vector3 = (_jobs[_job_index]["drop"] if _carrying else _jobs[_job_index]["pickup"]) as Vector3
	_status_refresh -= _delta
	if _status_refresh <= 0.0:
		_status_refresh = 0.5
		_set_status("DELIVERY %d  •  %s  •  %s  •  %dm" % [
			_completed_deliveries + _job_index + 1, _rank_label(),
			"DRIVE TO DROP" if _carrying else "COLLECT PACKAGE",
			int(round(_player.global_position.distance_to(target)))])
	if _player.global_position.distance_to(target) > (6.0 if _carrying else 5.0):
		return
	if _carrying:
		_finish_delivery()
	else:
		_collect_package()

func _build_jobs() -> void:
	_jobs.clear()
	_job_index = 0
	_carrying = false
	_complete = false
	if _traffic == null or _traffic.road_network() == null:
		_set_status("CITY ROUTES LOADING…")
		return
	var roads: Array[TrafficRoadNetwork.Road] = _traffic.road_network().get_roads()
	var usable: Array[TrafficRoadNetwork.Road] = []
	for road: TrafficRoadNetwork.Road in roads:
		if road.length >= 35.0 and road.points.size() >= 2:
			usable.append(road)
	if usable.is_empty():
		_set_status("NO ROAD ROUTE FOUND")
		return

	for i: int in DELIVERIES_PER_BATCH:
		var source: TrafficRoadNetwork.Road = usable[(i * 3) % usable.size()]
		var pickup: Vector3 = _point_on_road(source, source.length * (0.28 + 0.09 * float(i % 3)))
		var drop_fraction := 0.62 - 0.07 * float(i % 3)
		var destination: TrafficRoadNetwork.Road = _destination_road_for(pickup, usable, (i * 3 + 1) % usable.size(), drop_fraction)
		var dropoff: Vector3 = _point_on_road(destination, destination.length * drop_fraction)
		_jobs.append({"pickup": pickup, "drop": dropoff})
	_show_current_job()

func _destination_road_for(pickup: Vector3, roads: Array[TrafficRoadNetwork.Road], start_index: int, drop_fraction: float) -> TrafficRoadNetwork.Road:
	# Keep the drop on the real road graph, but avoid the old adjacent-road
	# selection that produced almost identical ~135 m deliveries. Prefer the
	# first valid road at least MIN_DELIVERY_DISTANCE_M away, then fall back to
	# the farthest available road if this map ever becomes too compact.
	var farthest: TrafficRoadNetwork.Road = roads[start_index]
	var farthest_distance := -1.0
	for offset: int in roads.size():
		var candidate: TrafficRoadNetwork.Road = roads[(start_index + offset) % roads.size()]
		var candidate_point := _point_on_road(candidate, candidate.length * drop_fraction)
		var distance := pickup.distance_to(candidate_point)
		if distance > farthest_distance:
			farthest = candidate
			farthest_distance = distance
		if distance >= MIN_DELIVERY_DISTANCE_M:
			return candidate
	return farthest

## The active objective in world coordinates. The waypoint/arrow uses this
## instead of duplicating quest selection logic, so marker and completion always
## refer to the same target.
func active_target() -> Variant:
	if _complete or _jobs.is_empty() or _job_index >= _jobs.size():
		return null
	return (_jobs[_job_index]["drop"] if _carrying else _jobs[_job_index]["pickup"]) as Vector3

func is_complete() -> bool:
	return _complete

func _point_on_road(road: TrafficRoadNetwork.Road, distance: float) -> Vector3:
	var remaining: float = clampf(distance, 0.0, road.length)
	for i: int in range(road.points.size() - 1):
		var a: Vector3 = road.points[i]
		var b: Vector3 = road.points[i + 1]
		var segment: float = a.distance_to(b)
		if remaining <= segment:
			return a.lerp(b, remaining / maxf(segment, 0.001))
		remaining -= segment
	return road.points[road.points.size() - 1]

func _build_status_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 230)
	panel.size = Vector2(330, 58)
	var style := StyleBoxFlat.new()
	style.bg_color = JAM_DARK
	style.border_color = JAM_TEAL
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", JAM_GREEN)
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(_status_label)

func _package_visual(number: int) -> Node3D:
	var holder := Node3D.new()
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.8, 0.8)
	box.mesh = mesh
	box.material_override = _material(JAM_MAUVE)
	holder.add_child(box)
	var ribbon := MeshInstance3D.new()
	var ribbon_mesh := BoxMesh.new()
	ribbon_mesh.size = Vector3(0.84, 0.16, 0.84)
	ribbon.mesh = ribbon_mesh
	ribbon.position.y = 0.12
	ribbon.material_override = _material(JAM_GREEN)
	holder.add_child(ribbon)
	var label := Label3D.new()
	label.text = "PACKAGE %02d" % number
	label.position.y = 1.25
	label.modulate = JAM_GREEN
	label.font_size = 28
	label.outline_size = 8
	label.outline_modulate = JAM_DARK
	holder.add_child(label)
	return holder

func _drop_visual(number: int) -> Node3D:
	var holder := Node3D.new()
	var pad := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.7
	mesh.bottom_radius = 1.7
	mesh.height = 0.08
	pad.mesh = mesh
	pad.material_override = _material(JAM_TEAL)
	holder.add_child(pad)
	var beacon := MeshInstance3D.new()
	var beacon_mesh := BoxMesh.new()
	beacon_mesh.size = Vector3(0.25, 2.8, 0.25)
	beacon.mesh = beacon_mesh
	beacon.position.y = 1.4
	beacon.material_override = _material(JAM_BLUE)
	holder.add_child(beacon)
	var label := Label3D.new()
	label.text = "DROP %02d" % number
	label.position.y = 3.0
	label.modulate = JAM_TEAL
	label.font_size = 30
	label.outline_size = 8
	label.outline_modulate = JAM_DARK
	holder.add_child(label)
	return holder

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

func _show_current_job() -> void:
	if _pickup_node != null:
		_pickup_node.queue_free()
	if _drop_node != null:
		_drop_node.queue_free()
	if _complete or _jobs.is_empty():
		if _minimap != null and _minimap.has_method("clear_objective"):
			_minimap.call("clear_objective")
		return
	var job: Dictionary = _jobs[_job_index]
	if _minimap != null and _minimap.has_method("set_objective"):
		_minimap.call("set_objective", active_target())
	if _carrying:
		_drop_node = _drop_visual(_job_index + 1)
		_drop_node.position = (job["drop"] as Vector3) + Vector3.UP * 0.08
		add_child(_drop_node)
		_set_status("DELIVERY %d  •  %s  •  DRIVE TO DROP" % [_completed_deliveries + _job_index + 1, _rank_label()])
	else:
		_pickup_node = _package_visual(_job_index + 1)
		_pickup_node.position = (job["pickup"] as Vector3) + Vector3.UP * 0.8
		add_child(_pickup_node)
		_set_status("DELIVERY %d  •  %s  •  COLLECT PACKAGE" % [_completed_deliveries + _job_index + 1, _rank_label()])

func _collect_package() -> void:
	_carrying = true
	_show_current_job()

func _finish_delivery() -> void:
	_carrying = false
	_completed_deliveries += 1
	_job_index += 1
	if _job_index >= _jobs.size():
		# Keep the delivery loop alive; rank is based on the lifetime total.
		_build_jobs()
		return
	_show_current_job()


func _rank_label() -> String:
	if _completed_deliveries >= 30:
		return "GOD"
	if _completed_deliveries >= 25:
		return "ACE"
	if _completed_deliveries >= 20:
		return "LEGEND"
	if _completed_deliveries >= 15:
		return "BEGINNER"
	if _completed_deliveries >= 10:
		return "ROOKIE"
	if _completed_deliveries >= 5:
		return "LITTLE LEGEND"
	return "NEW RIDER"

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
