class_name OSMTileManager
extends Node3D

const RoadNetworkContextScript := preload("res://scripts/road_network_context.gd")
const RoadJunctionSolverScript := preload("res://scripts/road_junction_solver.gd")
const OSMJunctionBuilderScript := preload("res://scripts/osm_junction_builder.gd")
const RoadProfileScript := preload("res://scripts/road_profile.gd")






const OSMTileSourceScript := preload("res://scripts/osm_tile_source.gd")


const FrameTracerScript := preload("res://scripts/frame_tracer.gd")




const TileStreamingPipelineScript := preload("res://scripts/tile_streaming_pipeline.gd")



const TerrainShader: Shader = preload("res://scripts/shaders/terrain.gdshader")


signal data_loaded(osm_data: OSMParser.OSMData)

signal tile_loaded(tile_key: Vector2i)

signal tile_unloaded(tile_key: Vector2i)

@export var osm_file_path: String = "res://data/map.osm"



@export var tile_cache_dir: String = "res://data/tiles"
@export var tile_size: float = 200.0  
@export var load_radius: int = 2      
@export var unload_radius: int = 3    






@export var instance_budget_ms: float = 4.0





@export var terrain_subdivisions: int = 32



@export var street_lamp_lights_path: NodePath




var _tile_source: OSMTileSourceScript = null
var _height_provider: HeightProvider = null   


var _terrain_material: ShaderMaterial = null
var _loaded_tiles: Dictionary = {}    
var _current_tile: Vector2i = Vector2i(999999, 999999)











var _pipeline: TileStreamingPipelineScript = null




var _use_threads: bool = true



const _FEATURE_SLOW_MS := 30.0







var _pending_tiles: Dictionary:
	get: return _pipeline._pending_tiles if _pipeline != null else {}
var _instance_queue: Array:
	get: return _pipeline._instance_queue if _pipeline != null else []
var _feature_queue: Array:
	get: return _pipeline._feature_queue if _pipeline != null else []




class FeatureWork extends RefCounted:
	enum Kind { WAY, BUILDING_PART, ASSETS, RELATION, JUNCTION }
	var kind: int
	var tile_key: Vector2i
	var tile_root: Node3D                 
	var osm_data: OSMParser.OSMData
	var way: OSMParser.OSMWay = null      
	var relation: OSMParser.OSMRelation = null  
	var nodes: Array = []                 
	var ctx: OSMTileContext = null        
	
	var junction: RoadJunctionSolverScript.Junction = null
	
	var sidewalks: Dictionary = {}

var _way_builder: OSMWayBuilder = null
var _junction_builder: OSMJunctionBuilderScript = null
var _infrastructure_builder: OSMInfrastructureBuilder = null
var _building_builder: OSMBuildingBuilder = null
var _asset_placer: OSMAssetPlacer = null
var _relation_builder: OSMRelationBuilder = null







var _way_handlers: Array[OSMWayHandler] = []

func _ready() -> void:
	_way_builder = OSMWayBuilder.new()
	_junction_builder = OSMJunctionBuilderScript.new()
	_infrastructure_builder = OSMInfrastructureBuilder.new()
	_building_builder = OSMBuildingBuilder.new()
	_asset_placer = OSMAssetPlacer.new()
	
	
	
	
	_asset_placer.lamp_lights = get_node_or_null(street_lamp_lights_path) as StreetLampLights
	_relation_builder = OSMRelationBuilder.new()

	
	
	_pipeline = TileStreamingPipelineScript.new()
	_pipeline.use_threads = _use_threads
	_pipeline.instance_budget_ms = instance_budget_ms
	_pipeline.configure(
		_parse_tile_with_junctions,
		func(tkey: Vector2i, bucket: Variant) -> void: _instance_tile(tkey, bucket, true),
		_build_feature,
		func(tkey: Vector2i) -> bool: return _loaded_tiles.has(tkey),
		_tile_in_range,
		FrameTracerScript.record_usec)

	_way_handlers = [
		RoadHandler.new(),
		RailwayHandler.new(),
		PowerLineHandler.new(),
		GantryHandler.new(),
		WaterwayHandler.new(),
		BuildingHandler.new(),
		BarrierHandler.new(),
		PlatformHandler.new(),
		ParkingHandler.new(),
		AreaHandler.new(),
		SurfaceHandler.new(),
	]

	_load_osm_data()











func _parse_tile_with_junctions(tkey: Vector2i) -> Variant:
	var bucket: Dictionary = _tile_source.parse_tile(tkey)
	if bucket.is_empty():
		return bucket
	bucket["road_network"] = _solve_tile_junctions(tkey, bucket)
	return bucket




func _solve_tile_junctions(
		tkey: Vector2i, bucket: Dictionary) -> RoadNetworkContextScript:
	var own_ways: Array = []
	for way: OSMParser.OSMWay in bucket["ways"]:
		if way.tags.has("highway"):
			own_ways.append(way)
	if own_ways.is_empty():
		return null

	var halo := _tile_source.collect_road_halo(tkey)
	var halo_ways: Array = halo["ways"]
	var nodes: Dictionary = halo["nodes"]
	
	
	if halo_ways.is_empty():
		halo_ways = own_ways
		nodes = (bucket["osm_data"] as OSMParser.OSMData).nodes

	return RoadNetworkContextScript.build(
		own_ways, halo_ways, nodes, _tile_clip_rect(tkey))





func _load_osm_data() -> void:
	_tile_source = _create_tile_source()
	if _tile_source == null or not _tile_source.is_ready():
		push_error("OSMTileManager: Failed to load OSM data")
		return

	
	
	tile_size = _tile_source.get_tile_size()
	_height_provider = _tile_source.get_height_provider()

	
	
	
	_junction_builder.region = RoadRegion.for_coordinates(
		_tile_source.get_center_lat(), _tile_source.get_center_lon())

	
	if _has_terrain():
		var grid_step := tile_size / float(max(1, terrain_subdivisions))
		
		
		
		_height_provider.set_mesh_grid(tile_size, terrain_subdivisions)
		_relation_builder.height_provider = _height_provider
		_relation_builder.terrain_grid_step = grid_step
		_way_builder.height_provider = _height_provider
		_way_builder.terrain_grid_step = grid_step
		_junction_builder.height_provider = _height_provider
		_junction_builder.terrain_grid_step = grid_step
	print("OSMTileManager: Tile source ready, ready for tile loading")
	data_loaded.emit(get_osm_data())



func _create_tile_source() -> OSMTileSourceScript:
	var manifest := "%s/manifest.json" % tile_cache_dir.trim_suffix("/")
	if FileAccess.file_exists(manifest):
		print("OSMTileManager: Streaming from tile cache %s" % tile_cache_dir)
		return OSMTileSourceScript.DiskTileSource.new(tile_cache_dir)
	print("OSMTileManager: Loading OSM data from %s" % osm_file_path)
	return OSMTileSourceScript.InMemoryTileSource.new(osm_file_path, tile_size)

func _pos_to_tile(pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(pos.x / tile_size),
		floori(pos.z / tile_size)
	)

func _process(_delta: float) -> void:
	if _tile_source == null:
		return

	
	
	
	
	_pipeline.instance_budget_ms = instance_budget_ms
	_pipeline.collect_finished_parses()
	_pipeline.drain()

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var cam_tile := _pos_to_tile(camera.global_position)
	if cam_tile == _current_tile:
		return

	_current_tile = cam_tile
	_update_tiles()




func _update_tiles() -> void:
	
	for dx: int in range(-load_radius, load_radius + 1):
		for dz: int in range(-load_radius, load_radius + 1):
			var tkey := Vector2i(_current_tile.x + dx, _current_tile.y + dz)
			_request_tile(tkey)

	
	var to_unload: Array[Vector2i] = []
	for tkey: Vector2i in _loaded_tiles:
		var dist: int = max(abs(tkey.x - _current_tile.x), abs(tkey.y - _current_tile.y))
		if dist > unload_radius:
			to_unload.append(tkey)

	for tkey: Vector2i in to_unload:
		_unload_tile(tkey)






func _request_tile(tkey: Vector2i) -> void:
	_pipeline.request_tile(tkey)




func _drain_instance_queue() -> void:
	_pipeline.instance_budget_ms = instance_budget_ms
	_pipeline.drain()



func _tile_in_range(tkey: Vector2i) -> bool:
	var dist: int = max(abs(tkey.x - _current_tile.x), abs(tkey.y - _current_tile.y))
	return dist <= unload_radius









func _load_tile(tkey: Vector2i) -> void:
	if _loaded_tiles.has(tkey):
		return
	
	_pipeline.cancel_pending(tkey)
	var bucket := _tile_source.load_tile(tkey)
	if not bucket.is_empty():
		bucket["road_network"] = _solve_tile_junctions(tkey, bucket)
	_instance_tile(tkey, bucket)












func _instance_tile(tkey: Vector2i, bucket: Dictionary, defer: bool = false) -> void:
	
	
	
	
	var tile_root := Node3D.new()
	tile_root.name = "Tile_%d_%d" % [tkey.x, tkey.y]
	add_child(tile_root)

	if bucket.is_empty():
		
		_build_ground(tile_root, tkey, false)
		_loaded_tiles[tkey] = tile_root
		tile_loaded.emit(tkey)
		return

	var osm_data: OSMParser.OSMData = bucket["osm_data"]

	
	var tile_covered := _tile_fully_covered(tkey, bucket, osm_data)

	
	
	
	_build_ground(tile_root, tkey, tile_covered)

	
	
	
	_loaded_tiles[tkey] = tile_root

	var building_part_ways := _collect_building_part_ways(bucket, osm_data)
	var suppressed_building_ids := _collect_suppressed_buildings(
		building_part_ways, bucket, osm_data)
	var relation_way_ids := _collect_relation_way_ids(bucket["relations"], osm_data)
	var ctx := _make_tile_context(
		tkey, suppressed_building_ids, osm_data,
		bucket.get("road_network", null))

	
	var items := _plan_tile_features(
		tkey, tile_root, osm_data, bucket, ctx, building_part_ways, relation_way_ids)
	if defer:
		_pipeline.enqueue_features(items)
	else:
		for item: FeatureWork in items:
			_build_feature(item)

	tile_loaded.emit(tkey)




func _plan_tile_features(
		tkey: Vector2i, tile_root: Node3D, osm_data: OSMParser.OSMData,
		bucket: Dictionary, ctx: OSMTileContext,
		building_part_ways: Array[OSMParser.OSMWay],
		relation_way_ids: Dictionary) -> Array[FeatureWork]:
	var items: Array[FeatureWork] = []
	var processed_way_ids := {}

	for way: OSMParser.OSMWay in bucket["ways"]:
		if processed_way_ids.has(way.id):
			continue
		if relation_way_ids.has(way.id):
			processed_way_ids[way.id] = true
			continue
		
		
		
		
		if _is_building_part(way):
			continue
		processed_way_ids[way.id] = true
		var w := FeatureWork.new()
		w.kind = FeatureWork.Kind.WAY
		w.tile_key = tkey
		w.tile_root = tile_root
		w.osm_data = osm_data
		w.way = way
		w.ctx = ctx
		items.append(w)

	for part: OSMParser.OSMWay in building_part_ways:
		if processed_way_ids.has(part.id):
			continue
		processed_way_ids[part.id] = true
		var b := FeatureWork.new()
		b.kind = FeatureWork.Kind.BUILDING_PART
		b.tile_key = tkey
		b.tile_root = tile_root
		b.osm_data = osm_data
		b.way = part
		items.append(b)

	var a := FeatureWork.new()
	a.kind = FeatureWork.Kind.ASSETS
	a.tile_key = tkey
	a.tile_root = tile_root
	a.osm_data = osm_data
	a.nodes = bucket["nodes"]
	items.append(a)

	
	
	
	var network: RoadNetworkContextScript = bucket.get("road_network", null)
	if network != null:
		var sidewalks := _collect_arm_sidewalks(bucket)
		for junction: RoadJunctionSolverScript.Junction in network.owned_junctions():
			var jw := FeatureWork.new()
			jw.kind = FeatureWork.Kind.JUNCTION
			jw.tile_key = tkey
			jw.tile_root = tile_root
			jw.osm_data = osm_data
			jw.junction = junction
			jw.sidewalks = sidewalks
			items.append(jw)

	var processed_rel_ids := {}
	for rel: OSMParser.OSMRelation in bucket["relations"]:
		if processed_rel_ids.has(rel.id):
			continue
		processed_rel_ids[rel.id] = true
		var r := FeatureWork.new()
		r.kind = FeatureWork.Kind.RELATION
		r.tile_key = tkey
		r.tile_root = tile_root
		r.osm_data = osm_data
		r.relation = rel
		items.append(r)

	return items





func _build_feature(item: FeatureWork) -> void:
	
	
	
	if not is_instance_valid(item.tile_root) or not _loaded_tiles.has(item.tile_key):
		return

	var t0 := Time.get_ticks_usec()
	match item.kind:
		FeatureWork.Kind.WAY:
			
			
			
			
			_way_builder.tile_clip_rect = item.ctx.tile_clip
			_way_builder.network = item.ctx.road_network
			var handled := false
			for handler: OSMWayHandler in _way_handlers:
				if handler.matches(item.way, item.ctx):
					var node := handler.build(item.way, item.ctx)
					if node != null:
						item.tile_root.add_child(node)
					handled = true
					break
			_way_builder.tile_clip_rect = null
			_way_builder.network = null
			if not handled and not _is_ignorable_way(item.way):
				print_debug("Skipping way with tags", item.way.tags)
		FeatureWork.Kind.BUILDING_PART:
			var mi := _building_builder.build_building_from_way(item.way, item.osm_data)
			if mi != null:
				item.tile_root.add_child(mi)
		FeatureWork.Kind.ASSETS:
			var assets_root := _asset_placer.place_assets_batched(item.nodes)
			if assets_root != null:
				item.tile_root.add_child(assets_root)
		FeatureWork.Kind.JUNCTION:
			var jnode := _junction_builder.build_junction(
				item.junction, item.sidewalks)
			if jnode != null:
				
				
				jnode.add_to_group(&"road_surface")
				item.tile_root.add_child(jnode)
		FeatureWork.Kind.RELATION:
			_relation_builder.tile_clip_rect = _tile_clip_rect(item.tile_key) as Variant
			var rel_node := _relation_builder.build_relation(item.relation, item.osm_data)
			if rel_node != null:
				item.tile_root.add_child(rel_node)

	var elapsed_us := Time.get_ticks_usec() - t0
	FrameTracerScript.record_usec("build_feature", elapsed_us)
	if elapsed_us >= int(_FEATURE_SLOW_MS * 1000.0):
		
		
		
		
		if FrameTracerScript.is_enabled():
			print("[trace] SLOW feature %s took %.1f ms at tile %s" % [
				_feature_desc(item), elapsed_us / 1000.0, item.tile_key])


func _feature_desc(item: FeatureWork) -> String:
	match item.kind:
		FeatureWork.Kind.WAY:
			return "way %d %s" % [item.way.id, item.way.tags]
		FeatureWork.Kind.BUILDING_PART:
			return "building:part %d" % item.way.id
		FeatureWork.Kind.ASSETS:
			return "assets(%d nodes)" % item.nodes.size()
		FeatureWork.Kind.RELATION:
			return "relation %d %s" % [item.relation.id, item.relation.tags]
	return "unknown"







func _collect_arm_sidewalks(bucket: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for way: OSMParser.OSMWay in bucket["ways"]:
		if way.tags.has("highway"):
			out[way.id] = RoadProfileScript.sidewalk_sides(way.tags)
	return out




func _tile_fully_covered(
		tkey: Vector2i, bucket: Dictionary, osm_data: OSMParser.OSMData) -> bool:
	if not _has_terrain():
		return false
	var grid_step := tile_size / float(max(1, terrain_subdivisions))
	var origin_x := float(tkey.x) * tile_size
	var origin_z := float(tkey.y) * tile_size
	for way: OSMParser.OSMWay in bucket["ways"]:
		if AreaHandler.is_area(way) or ParkingHandler.is_parking(way):
			var pts := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
			if pts.size() >= 3 and PolygonUtils.polygon_covers_tile(
					pts, origin_x, origin_z, tile_size, grid_step):
				return true
	for rel: OSMParser.OSMRelation in bucket["relations"]:
		if rel.tags.get("type", "") != "multipolygon":
			continue
		if not (rel.tags.has("landuse") or rel.tags.has("natural") or rel.tags.has("leisure")):
			continue
		for member: Dictionary in rel.members:
			if member["type"] != "way" or member["role"] != "outer":
				continue
			var way_id: int = member["ref"]
			if not osm_data.ways.has(way_id):
				continue
			var pts := PolygonUtils.way_to_points(
				osm_data.ways[way_id].node_ids, osm_data.nodes)
			if pts.size() >= 3 and PolygonUtils.polygon_covers_tile(
					pts, origin_x, origin_z, tile_size, grid_step):
				return true
	return false


func _collect_building_part_ways(
		bucket: Dictionary, _osm_data: OSMParser.OSMData) -> Array[OSMParser.OSMWay]:
	var out: Array[OSMParser.OSMWay] = []
	for way: OSMParser.OSMWay in bucket["ways"]:
		if _is_building_part(way):
			out.append(way)
	return out



func _collect_suppressed_buildings(
		building_part_ways: Array[OSMParser.OSMWay], bucket: Dictionary,
		osm_data: OSMParser.OSMData) -> Dictionary:
	var suppressed: Dictionary = {}
	if building_part_ways.is_empty():
		return suppressed
	for part: OSMParser.OSMWay in building_part_ways:
		var part_points := PolygonUtils.way_to_points(part.node_ids, osm_data.nodes)
		if part_points.size() < 3:
			continue
		var part_centroid := PolygonUtils.polygon_centroid(part_points)
		for way: OSMParser.OSMWay in bucket["ways"]:
			if not way.tags.has("building") or way.tags.has("building:part"):
				continue
			var bld_points := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
			if bld_points.size() < 3:
				continue
			if _point_in_polygon_xz(part_centroid, bld_points):
				suppressed[way.id] = true
	return suppressed



func _make_tile_context(
		tkey: Vector2i, suppressed_building_ids: Dictionary,
		osm_data: OSMParser.OSMData,
		road_network: RoadNetworkContextScript = null) -> OSMTileContext:
	var ctx := OSMTileContext.new()
	ctx.osm_data = osm_data
	ctx.tile_key = tkey
	ctx.tile_size = tile_size
	ctx.has_terrain = _has_terrain()
	ctx.grid_step = tile_size / float(max(1, terrain_subdivisions)) if ctx.has_terrain else 0.0
	ctx.tile_clip = (_tile_clip_rect(tkey) as Variant) if ctx.has_terrain else null
	ctx.suppressed_building_ids = suppressed_building_ids
	ctx.road_network = road_network
	ctx.way_builder = _way_builder
	ctx.infrastructure_builder = _infrastructure_builder
	ctx.building_builder = _building_builder
	ctx.asset_placer = _asset_placer
	return ctx






func _exit_tree() -> void:
	if _pipeline != null:
		_pipeline.shutdown()

func _unload_tile(tkey: Vector2i) -> void:
	var tile_node: Node3D = _loaded_tiles[tkey]
	if tile_node != null:
		
		
		
		
		
		if _asset_placer != null and _asset_placer.lamp_lights != null:
			var assets := tile_node.get_node_or_null("Assets")
			if assets != null:
				_asset_placer.lamp_lights.unregister_tile(assets)
		tile_node.queue_free()
	_loaded_tiles.erase(tkey)
	
	
	
	_pipeline.purge_features(func(item: FeatureWork) -> bool: return item.tile_key != tkey)
	tile_unloaded.emit(tkey)



func get_loaded_tile_count() -> int:
	return _loaded_tiles.size()






func get_osm_data() -> OSMParser.OSMData:
	return _tile_source.get_global_osm_data() if _tile_source != null else null






func collect_ways_near(center: Vector3, radius: float) -> Array:
	if _tile_source == null:
		return []
	return _tile_source.collect_ways_near(center, radius)










func collect_osm_near(center: Vector3, radius: float, yield_every: int = 0) -> OSMParser.OSMData:
	if _tile_source == null:
		return OSMParser.OSMData.new()
	return _tile_source.collect_osm_near(center, radius, yield_every)



func is_data_ready() -> bool:
	return _tile_source != null and _tile_source.is_ready()




func get_terrain_height(world_pos: Vector3) -> float:
	if not _has_terrain():
		return 0.0
	return _height_provider.sample_local_xz(world_pos.x, world_pos.z)





func set_show_debug_labels(enabled: bool) -> void:
	_asset_placer.show_debug_labels = enabled











func ensure_tiles_around(world_pos: Vector3) -> bool:
	if _tile_source == null:
		return false
	
	for tkey: Vector2i in spawn_tiles_around(world_pos):
		load_tile_now(tkey)
	return true







func spawn_tiles_around(world_pos: Vector3) -> Array[Vector2i]:
	_current_tile = _pos_to_tile(world_pos)
	var keys: Array[Vector2i] = []
	for dx: int in range(-load_radius, load_radius + 1):
		for dz: int in range(-load_radius, load_radius + 1):
			keys.append(Vector2i(_current_tile.x + dx, _current_tile.y + dz))
	var center := _current_tile
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared())
	return keys




func load_tile_now(tkey: Vector2i) -> void:
	if _tile_source == null:
		return
	_load_tile(tkey)

func _has_terrain() -> bool:
	return _height_provider != null and _height_provider.is_ready()

func _build_ground(parent: Node3D, tkey: Vector2i, skip_visual: bool = false) -> void:
	if _has_terrain():
		_build_terrain_ground(parent, tkey, skip_visual)
	else:
		_build_flat_ground(parent, tkey)


func _build_flat_ground(parent: Node3D, tkey: Vector2i) -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.position = Vector3(
		(tkey.x + 0.5) * tile_size,
		-0.05,
		(tkey.y + 0.5) * tile_size
	)

	var ground := MeshInstance3D.new()
	ground.name = "GroundMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(tile_size, tile_size)
	ground.mesh = plane

	ground.material_override = _get_terrain_material()
	ground_body.add_child(ground)

	var col_shape := CollisionShape3D.new()
	col_shape.name = "GroundCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(tile_size, 0.1, tile_size)
	col_shape.shape = box
	ground_body.add_child(col_shape)

	parent.add_child(ground_body)





func _get_terrain_material() -> ShaderMaterial:
	if _terrain_material == null:
		_terrain_material = ShaderMaterial.new()
		_terrain_material.shader = TerrainShader
	return _terrain_material






func _build_terrain_ground(parent: Node3D, tkey: Vector2i, skip_visual: bool = false) -> void:
	var _trace := FrameTracerScript.scope("build_terrain_ground")
	var hp := _height_provider
	var subs: int = max(1, terrain_subdivisions)
	var origin_x := tkey.x * tile_size
	var origin_z := tkey.y * tile_size
	var step := tile_size / float(subs)

	
	var verts: Array[Vector3] = []
	verts.resize((subs + 1) * (subs + 1))
	for gz: int in range(subs + 1):
		for gx: int in range(subs + 1):
			var wx := origin_x + float(gx) * step
			var wz := origin_z + float(gz) * step
			var wy := hp.sample_local_xz(wx, wz)
			verts[gz * (subs + 1) + gx] = Vector3(wx, wy, wz)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_get_terrain_material())

	for gz: int in range(subs):
		for gx: int in range(subs):
			var i00: int = gz * (subs + 1) + gx
			var i10: int = i00 + 1
			var i01: int = (gz + 1) * (subs + 1) + gx
			var i11: int = i01 + 1
			
			
			
			
			_add_terrain_tri(st, verts[i00], verts[i11], verts[i01])
			_add_terrain_tri(st, verts[i00], verts[i10], verts[i11])

	st.generate_normals()
	var mesh := st.commit()

	
	
	
	FrameTracerScript.begin("terrain_trimesh_collider")
	var tri_shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	tri_shape.backface_collision = true
	FrameTracerScript.end("terrain_trimesh_collider")

	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"

	
	
	
	if not skip_visual:
		var ground := MeshInstance3D.new()
		ground.name = "GroundMesh"
		ground.mesh = mesh
		ground_body.add_child(ground)

	var col_shape := CollisionShape3D.new()
	col_shape.name = "GroundCollision"
	
	
	
	
	
	col_shape.shape = tri_shape
	ground_body.add_child(col_shape)

	parent.add_child(ground_body)

func _add_terrain_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)




func _is_building_part(way: OSMParser.OSMWay) -> bool:
	return way.tags.has("building:part")










func _collect_relation_way_ids(relations: Array, osm_data: OSMParser.OSMData) -> Dictionary:
	var ids := {}
	for rel: OSMParser.OSMRelation in relations:
		if not _relation_renders_ways(rel):
			continue
		for member: Dictionary in rel.members:
			if member["type"] != "way":
				continue
			var way_id: int = member["ref"]
			if not osm_data.ways.has(way_id):
				continue
			var way: OSMParser.OSMWay = osm_data.ways[way_id]
			
			
			
			
			if not _way_has_own_feature(way):
				ids[way_id] = true
	return ids





static func _relation_renders_ways(rel: OSMParser.OSMRelation) -> bool:
	var rel_type: String = rel.tags.get("type", "")
	if rel_type == "building":
		return true
	if rel_type == "multipolygon":
		if rel.tags.has("building") or rel.tags.has("landuse") \
				or rel.tags.has("natural") or rel.tags.has("leisure"):
			return true
	return false






static func _way_has_own_feature(way: OSMParser.OSMWay) -> bool:
	return way.tags.has("highway") or way.tags.has("building") \
		or way.tags.has("building:part") or way.tags.has("railway") \
		or way.tags.has("waterway") or way.tags.has("barrier") \
		or way.tags.has("landuse") or way.tags.has("natural") \
		or way.tags.has("leisure") or way.tags.has("amenity") \
		or way.tags.has("power") or way.tags.has("man_made")







static func _has_renderable_area_tag(way: OSMParser.OSMWay) -> bool:
	return way.tags.has("tourism") or way.tags.has("playground") \
		or way.tags.has("historic") or way.tags.has("shop") \
		or way.tags.has("area:highway") or way.tags.has("surface") \
		or way.tags.has("public_transport")








const _LIFECYCLE_PREFIXES := [
	"removed:", "disused:", "abandoned:", "razed:", "demolished:",
	"destroyed:", "construction:", "proposed:", "planned:", "was:",
]
func _is_ignorable_way(way: OSMParser.OSMWay) -> bool:
	if way.tags.is_empty():
		return true
	for key: String in way.tags:
		for prefix: String in _LIFECYCLE_PREFIXES:
			if key.begins_with(prefix):
				return true
	
	if way.tags.has("boundary"):
		return true
	
	if way.tags.size() == 1 and way.tags.has("area"):
		return true
	
	
	
	
	
	
	
	if not _way_has_own_feature(way) and not _has_renderable_area_tag(way):
		return true
	
	var man_made: String = way.tags.get("man_made", "")
	if man_made == "bridge" or man_made == "embankment":
		return true
	
	
	
	if (man_made == "breakwater" or man_made == "groyne") \
			and not OSMWayHandler.is_closed_way(way):
		return true
	
	
	if man_made == "dyke":
		return true
	
	
	
	if (man_made == "reinforced_slope" or man_made == "pier") \
			and not OSMWayHandler.is_closed_way(way):
		return true
	
	if way.tags.get("public_transport", "") == "station":
		return true
	if way.tags.get("amenity", "") == "bus_station":
		return true
	
	
	
	if way.tags.get("amenity", "") == "bench" and not OSMWayHandler.is_closed_way(way):
		return true
	
	
	if way.tags.get("public_transport", "") == "platform" \
			or way.tags.get("railway", "") == "platform" \
			or way.tags.get("highway", "") == "platform":
		return true
	
	
	
	if way.tags.has("playground") and not OSMWayHandler.is_closed_way(way):
		return true
	
	
	if way.tags.has("waterway"):
		if way.tags.get("tunnel", "") != "" or way.tags.has("culvert") \
				or way.tags.get("layer", "0").to_int() < 0:
			return true
	return false

func _point_in_polygon_xz(point: Vector3, polygon: PackedVector3Array) -> bool:
	var inside := false
	var n := polygon.size()
	var j := n - 1
	for i: int in range(n):
		var pi := polygon[i]
		var pj := polygon[j]
		if ((pi.z > point.z) != (pj.z > point.z)) and \
				(point.x < (pj.x - pi.x) * (point.z - pi.z) / (pj.z - pi.z) + pi.x):
			inside = not inside
		j = i
	return inside


func _tile_clip_rect(tkey: Vector2i) -> Array[float]:
	var ox := float(tkey.x) * tile_size
	var oz := float(tkey.y) * tile_size
	return [ox, ox + tile_size, oz, oz + tile_size]
