class_name OSMTileSource
extends RefCounted



























func is_ready() -> bool:
	return false



func get_tile_size() -> float:
	return 200.0



func get_height_provider() -> HeightProvider:
	return null



func get_center_lat() -> float:
	return 0.0

func get_center_lon() -> float:
	return 0.0






func get_global_osm_data() -> OSMParser.OSMData:
	return null



func has_tile(_tile_key: Vector2i) -> bool:
	return false






func _is_cached(_tile_key: Vector2i) -> bool:
	return false






func load_tile(_tile_key: Vector2i) -> Dictionary:
	return {}










func parse_tile(tile_key: Vector2i) -> Dictionary:
	return load_tile(tile_key)




func pos_to_tile(pos: Vector3) -> Vector2i:
	var ts := get_tile_size()
	return Vector2i(floori(pos.x / ts), floori(pos.z / ts))



















func collect_ways_near(center: Vector3, radius: float) -> Array:
	var out: Array = []
	if not is_ready():
		return out

	var ts := get_tile_size()
	
	
	
	var min_tile := Vector2i(
		floori((center.x - radius) / ts) - 1,
		floori((center.z - radius) / ts) - 1)
	var max_tile := Vector2i(
		floori((center.x + radius) / ts) + 1,
		floori((center.z + radius) / ts) + 1)

	var seen_ways: Dictionary = {}   
	var r_sq := radius * radius
	for tx: int in range(min_tile.x, max_tile.x + 1):
		for tz: int in range(min_tile.y, max_tile.y + 1):
			var tkey := Vector2i(tx, tz)
			if not has_tile(tkey):
				continue
			var bucket := parse_tile(tkey)
			if bucket.is_empty():
				continue
			var osm_data: OSMParser.OSMData = bucket["osm_data"]
			for way: OSMParser.OSMWay in bucket["ways"]:
				if seen_ways.has(way.id):
					continue
				var points := _way_points(way, osm_data)
				if points.is_empty():
					continue
				if not _points_within(points, center, r_sq):
					continue
				seen_ways[way.id] = true
				out.append({"way": way, "points": points})
	return out
























func collect_osm_near(center: Vector3, radius: float, yield_every: int = 0) -> OSMParser.OSMData:
	var data := OSMParser.OSMData.new()
	data.center_lat = get_center_lat()
	data.center_lon = get_center_lon()
	data.height_provider = get_height_provider()
	if not is_ready():
		return data

	var ts := get_tile_size()
	var min_tile := Vector2i(
		floori((center.x - radius) / ts) - 1,
		floori((center.z - radius) / ts) - 1)
	var max_tile := Vector2i(
		floori((center.x + radius) / ts) + 1,
		floori((center.z + radius) / ts) + 1)

	var r_sq := radius * radius
	var cold_parses := 0
	for tx: int in range(min_tile.x, max_tile.x + 1):
		for tz: int in range(min_tile.y, max_tile.y + 1):
			var tkey := Vector2i(tx, tz)
			if not has_tile(tkey):
				continue
			
			
			var was_cached := _is_cached(tkey)
			var bucket := parse_tile(tkey)
			if bucket.is_empty():
				continue
			if yield_every > 0 and not was_cached:
				cold_parses += 1
				if cold_parses % yield_every == 0:
					OS.delay_msec(0)  
			var src: OSMParser.OSMData = bucket["osm_data"]
			for way: OSMParser.OSMWay in bucket["ways"]:
				if data.ways.has(way.id):
					continue
				var points := _way_points(way, src)
				if points.is_empty() or not _points_within(points, center, r_sq):
					continue
				data.ways[way.id] = way
				
				
				for nid: int in way.node_ids:
					if src.nodes.has(nid) and not data.nodes.has(nid):
						data.nodes[nid] = src.nodes[nid]
	return data




















func collect_road_halo(tile_key: Vector2i) -> Dictionary:
	var ways: Array = []
	var nodes: Dictionary = {}
	if not is_ready():
		return {"ways": ways, "nodes": nodes}

	var seen_ways: Dictionary = {}
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var tkey := Vector2i(tile_key.x + dx, tile_key.y + dz)
			if not has_tile(tkey):
				continue
			var bucket := parse_tile(tkey)
			if bucket.is_empty():
				continue
			var src: OSMParser.OSMData = bucket["osm_data"]
			for way: OSMParser.OSMWay in bucket["ways"]:
				if seen_ways.has(way.id):
					continue
				if not way.tags.has("highway"):
					continue
				seen_ways[way.id] = true
				ways.append(way)
				for nid: int in way.node_ids:
					if not nodes.has(nid) and src.nodes.has(nid):
						nodes[nid] = src.nodes[nid]
	return {"ways": ways, "nodes": nodes}




static func _way_points(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for nid: int in way.node_ids:
		if osm_data.nodes.has(nid):
			pts.append((osm_data.nodes[nid] as OSMParser.OSMNode).local_pos)
	return pts


static func _points_within(points: PackedVector3Array, center: Vector3, r_sq: float) -> bool:
	for p: Vector3 in points:
		var dx := p.x - center.x
		var dz := p.z - center.z
		if dx * dx + dz * dz < r_sq:
			return true
	return false






class InMemoryTileSource extends OSMTileSource:
	var _osm_data: OSMParser.OSMData = null
	var _spatial_index: Dictionary = {}  
	var _tile_size: float = 200.0
	var _ready: bool = false

	func _init(osm_file_path: String, tile_size: float) -> void:
		_tile_size = tile_size
		_osm_data = OSMParser.parse_file(osm_file_path)
		if _osm_data == null:
			push_error("InMemoryTileSource: failed to parse %s" % osm_file_path)
			return
		_build_spatial_index()
		_ready = true

	func is_ready() -> bool:
		return _ready

	func get_tile_size() -> float:
		return _tile_size

	func get_height_provider() -> HeightProvider:
		return _osm_data.height_provider if _osm_data != null else null

	func get_center_lat() -> float:
		return _osm_data.center_lat if _osm_data != null else 0.0

	func get_center_lon() -> float:
		return _osm_data.center_lon if _osm_data != null else 0.0

	func get_global_osm_data() -> OSMParser.OSMData:
		return _osm_data

	func has_tile(tile_key: Vector2i) -> bool:
		return _spatial_index.has(tile_key)

	
	
	func _is_cached(_tile_key: Vector2i) -> bool:
		return true

	
	
	func load_tile(tile_key: Vector2i) -> Dictionary:
		if not _spatial_index.has(tile_key):
			return {}
		var bucket: Dictionary = _spatial_index[tile_key]
		return {
			"osm_data": _osm_data,
			"nodes": bucket["nodes"],
			"ways": bucket["ways"],
			"relations": bucket["relations"],
		}

	func _pos_to_tile(pos: Vector3) -> Vector2i:
		return Vector2i(floori(pos.x / _tile_size), floori(pos.z / _tile_size))

	func _ensure_bucket(tkey: Vector2i) -> void:
		if not _spatial_index.has(tkey):
			_spatial_index[tkey] = {"nodes": [], "ways": [], "relations": []}

	
	
	func _build_spatial_index() -> void:
		_spatial_index.clear()

		for node: OSMParser.OSMNode in _osm_data.nodes.values():
			if node.tags.size() > 0:
				var tkey := _pos_to_tile(node.local_pos)
				_ensure_bucket(tkey)
				_spatial_index[tkey]["nodes"].append(node)

		for way: OSMParser.OSMWay in _osm_data.ways.values():
			var tiles_touched := {}
			for nid: int in way.node_ids:
				if _osm_data.nodes.has(nid):
					var node: OSMParser.OSMNode = _osm_data.nodes[nid]
					tiles_touched[_pos_to_tile(node.local_pos)] = true
			for tkey: Vector2i in tiles_touched:
				_ensure_bucket(tkey)
				_spatial_index[tkey]["ways"].append(way)

		for rel: OSMParser.OSMRelation in _osm_data.relations.values():
			var tiles_touched := {}
			for member: Dictionary in rel.members:
				if member["type"] == "way":
					var ref_id: int = member["ref"]
					if _osm_data.ways.has(ref_id):
						var w: OSMParser.OSMWay = _osm_data.ways[ref_id]
						for nid: int in w.node_ids:
							if _osm_data.nodes.has(nid):
								var node: OSMParser.OSMNode = _osm_data.nodes[nid]
								tiles_touched[_pos_to_tile(node.local_pos)] = true
				elif member["type"] == "node":
					var ref_id: int = member["ref"]
					if _osm_data.nodes.has(ref_id):
						var node: OSMParser.OSMNode = _osm_data.nodes[ref_id]
						tiles_touched[_pos_to_tile(node.local_pos)] = true
			for tkey: Vector2i in tiles_touched:
				_ensure_bucket(tkey)
				_spatial_index[tkey]["relations"].append(rel)






class DiskTileSource extends OSMTileSource:
	
	const SUPPORTED_VERSION := 1
	
	
	
	
	
	
	const CACHE_CAPACITY := 128

	var _dir: String = ""
	var _tile_size: float = 200.0
	var _center_lat: float = 0.0
	var _center_lon: float = 0.0
	var _tile_files: Dictionary = {}   
	var _height_provider: HeightProvider = null
	var _ready: bool = false

	
	
	
	
	
	
	var _cache: Dictionary = {}
	var _lru: Array[Vector2i] = []
	var _cache_mutex := Mutex.new()

	func _init(tiles_dir: String) -> void:
		_dir = tiles_dir.trim_suffix("/")
		if not _load_manifest():
			return
		
		
		_height_provider = HeightProvider.new()
		if not _height_provider.load_from_files(_center_lat, _center_lon):
			_height_provider = null
		_ready = true

	func is_ready() -> bool:
		return _ready

	func get_tile_size() -> float:
		return _tile_size

	func get_height_provider() -> HeightProvider:
		return _height_provider

	func get_center_lat() -> float:
		return _center_lat

	func get_center_lon() -> float:
		return _center_lon

	
	
	
	func get_global_osm_data() -> OSMParser.OSMData:
		var data := OSMParser.OSMData.new()
		data.center_lat = _center_lat
		data.center_lon = _center_lon
		data.height_provider = _height_provider
		return data

	func has_tile(tile_key: Vector2i) -> bool:
		return _tile_files.has(tile_key)

	
	
	func _is_cached(tile_key: Vector2i) -> bool:
		_cache_mutex.lock()
		var present := _cache.has(tile_key)
		_cache_mutex.unlock()
		return present

	
	
	
	func load_tile(tile_key: Vector2i) -> Dictionary:
		return parse_tile(tile_key)

	
	
	
	
	
	func parse_tile(tile_key: Vector2i) -> Dictionary:
		if not _tile_files.has(tile_key):
			return {}

		
		_cache_mutex.lock()
		if _cache.has(tile_key):
			_touch_locked(tile_key)
			var hit: Dictionary = _cache[tile_key]
			_cache_mutex.unlock()
			return hit
		_cache_mutex.unlock()

		
		
		var bucket := _parse_tile_uncached(tile_key)

		
		
		
		_cache_mutex.lock()
		if _cache.has(tile_key):
			_touch_locked(tile_key)
			bucket = _cache[tile_key]
		elif not bucket.is_empty():
			_insert_locked(tile_key, bucket)
		_cache_mutex.unlock()
		return bucket

	
	
	
	func _parse_tile_uncached(tile_key: Vector2i) -> Dictionary:
		var path := "%s/%s" % [_dir, _tile_files[tile_key]]
		
		
		var data := OSMParser.parse_file(path, false)
		data.height_provider = _height_provider
		
		if _height_provider != null and _height_provider.is_ready():
			for node: OSMParser.OSMNode in data.nodes.values():
				node.local_pos.y = _height_provider.sample_latlon(node.lat, node.lon)

		return _bucket_from_data(data, tile_key)

	
	
	
	
	func _bucket_from_data(data: OSMParser.OSMData, tile_key: Vector2i) -> Dictionary:
		var nodes: Array = []
		var ways: Array = []
		var relations: Array = []

		for node: OSMParser.OSMNode in data.nodes.values():
			if node.tags.size() > 0 and _pos_to_tile(node.local_pos) == tile_key:
				nodes.append(node)

		for way: OSMParser.OSMWay in data.ways.values():
			for nid: int in way.node_ids:
				if data.nodes.has(nid) \
						and _pos_to_tile((data.nodes[nid] as OSMParser.OSMNode).local_pos) == tile_key:
					ways.append(way)
					break

		for rel: OSMParser.OSMRelation in data.relations.values():
			if _relation_touches_tile(rel, data, tile_key):
				relations.append(rel)

		return {
			"osm_data": data,
			"nodes": nodes,
			"ways": ways,
			"relations": relations,
		}

	func _relation_touches_tile(
			rel: OSMParser.OSMRelation, data: OSMParser.OSMData, tile_key: Vector2i) -> bool:
		for member: Dictionary in rel.members:
			if member["type"] == "way" and data.ways.has(member["ref"]):
				var w: OSMParser.OSMWay = data.ways[member["ref"]]
				for nid: int in w.node_ids:
					if data.nodes.has(nid) \
							and _pos_to_tile((data.nodes[nid] as OSMParser.OSMNode).local_pos) == tile_key:
						return true
			elif member["type"] == "node" and data.nodes.has(member["ref"]):
				if _pos_to_tile((data.nodes[member["ref"]] as OSMParser.OSMNode).local_pos) == tile_key:
					return true
		return false

	func _pos_to_tile(pos: Vector3) -> Vector2i:
		return Vector2i(floori(pos.x / _tile_size), floori(pos.z / _tile_size))

	func _load_manifest() -> bool:
		var path := "%s/manifest.json" % _dir
		if not FileAccess.file_exists(path):
			return false
		var text := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("DiskTileSource: malformed manifest at %s" % path)
			return false
		var m: Dictionary = parsed
		var version := int(m.get("version", 0))
		if version != SUPPORTED_VERSION:
			push_error("DiskTileSource: manifest version %d unsupported (expected %d); re-run bake_osm_tiles.py" % [version, SUPPORTED_VERSION])
			return false
		_tile_size = float(m.get("tile_size", 200.0))
		_center_lat = float(m.get("center_lat", 0.0))
		_center_lon = float(m.get("center_lon", 0.0))
		for entry: Dictionary in m.get("tiles", []):
			var tkey := Vector2i(int(entry["x"]), int(entry["z"]))
			_tile_files[tkey] = String(entry["file"])
		return true

	
	func _insert_locked(tkey: Vector2i, bucket: Dictionary) -> void:
		_cache[tkey] = bucket
		_lru.append(tkey)
		while _lru.size() > CACHE_CAPACITY:
			var evict: Vector2i = _lru.pop_front()
			
			if not _lru.has(evict):
				_cache.erase(evict)

	func _touch_locked(tkey: Vector2i) -> void:
		_lru.erase(tkey)
		_lru.append(tkey)
