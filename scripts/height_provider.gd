class_name HeightProvider
extends RefCounted
























const DEFAULT_HEIGHTMAP_PATH := "res://data/map.dem.png"
const DEFAULT_META_PATH := "res://data/map.dem.json"

var _ready: bool = false
var _width: int = 0
var _height: int = 0





var _elev: PackedFloat32Array = PackedFloat32Array()


var _min_lon: float = 0.0
var _min_lat: float = 0.0
var _max_lon: float = 0.0
var _max_lat: float = 0.0


var _min_elev: float = 0.0
var _max_elev: float = 0.0



var _ref_lat: float = 0.0
var _ref_lon: float = 0.0


var _m_per_deg_lat: float = 111132.0
var _m_per_deg_lon: float = 111132.0



var _inv_m_per_deg_lat: float = 0.0   
var _inv_m_per_deg_lon: float = 0.0   
var _u_scale: float = 0.0             
var _v_scale: float = 0.0             
var _max_x: int = 0                   
var _max_y: int = 0                   

var _source: String = ""







var _grid_tile_size: float = 0.0   
var _grid_step: float = 0.0        
var _inv_grid_step: float = 0.0    





func set_mesh_grid(tile_size: float, subdivisions: int) -> void:
	var subs: int = max(1, subdivisions)
	_grid_tile_size = tile_size
	_grid_step = tile_size / float(subs)
	_inv_grid_step = 1.0 / _grid_step if _grid_step > 0.0 else 0.0



func is_ready() -> bool:
	return _ready







func load_from_files(ref_lat: float, ref_lon: float,
		heightmap_path: String = DEFAULT_HEIGHTMAP_PATH,
		meta_path: String = DEFAULT_META_PATH) -> bool:
	_ready = false
	_ref_lat = ref_lat
	_ref_lon = ref_lon
	_m_per_deg_lat = 111132.0
	_m_per_deg_lon = 111132.0 * cos(deg_to_rad(ref_lat))

	if not FileAccess.file_exists(meta_path):
		print("HeightProvider: no DEM metadata at %s; terrain is flat." % meta_path)
		return false
	if not FileAccess.file_exists(heightmap_path):
		print("HeightProvider: no heightmap at %s; terrain is flat." % heightmap_path)
		return false

	var meta := _read_meta(meta_path)
	if meta.is_empty():
		return false

	var img := _load_heightmap_image(heightmap_path)
	if img == null:
		push_error("HeightProvider: failed to load heightmap %s" % heightmap_path)
		return false

	
	if img.get_format() != Image.FORMAT_L8 and img.get_format() != Image.FORMAT_RF \
			and img.get_format() != Image.FORMAT_RH:
		img.convert(Image.FORMAT_RF)

	_width = img.get_width()
	_height = img.get_height()
	if _width < 2 or _height < 2:
		push_error("HeightProvider: heightmap too small (%dx%d)" % [_width, _height])
		return false

	_min_lon = meta.get("min_lon", 0.0)
	_min_lat = meta.get("min_lat", 0.0)
	_max_lon = meta.get("max_lon", 0.0)
	_max_lat = meta.get("max_lat", 0.0)
	_min_elev = meta.get("min_elev", 0.0)
	_max_elev = meta.get("max_elev", 0.0)
	_source = meta.get("source", "DEM")

	if _max_lon <= _min_lon or _max_lat <= _min_lat:
		push_error("HeightProvider: invalid bounds in metadata")
		return false

	
	
	
	
	
	if _ref_lon < _min_lon or _ref_lon > _max_lon \
			or _ref_lat < _min_lat or _ref_lat > _max_lat:
		print("HeightProvider: DEM at %s covers [%.4f,%.4f]..[%.4f,%.4f] but dataset center is (%.4f, %.4f); ignoring stale DEM, terrain is flat." % [
			meta_path, _min_lon, _min_lat, _max_lon, _max_lat, _ref_lon, _ref_lat])
		return false

	
	
	_inv_m_per_deg_lat = 1.0 / _m_per_deg_lat
	_inv_m_per_deg_lon = 1.0 / _m_per_deg_lon
	_max_x = _width - 1
	_max_y = _height - 1
	_u_scale = float(_max_x) / (_max_lon - _min_lon)
	_v_scale = float(_max_y) / (_max_lat - _min_lat)

	
	
	_decode_elevations(img)

	_ready = true
	print("HeightProvider: loaded %s heightmap %dx%d, elev %.1f..%.1f m" % [
		_source, _width, _height, _min_elev, _max_elev
	])
	return true




func _decode_elevations(img: Image) -> void:
	var count := _width * _height
	_elev.resize(count)
	var range_elev := _max_elev - _min_elev
	var min_elev := _min_elev
	
	
	var i := 0
	for y: int in range(_height):
		for x: int in range(_width):
			_elev[i] = min_elev + img.get_pixel(x, y).r * range_elev
			i += 1



func sample_local_xz(x: float, z: float) -> float:
	if not _ready:
		return 0.0
	
	
	var lon := _ref_lon + x * _inv_m_per_deg_lon
	var lat := _ref_lat - z * _inv_m_per_deg_lat
	return sample_latlon(lat, lon)














func sample_mesh_height(x: float, z: float) -> float:
	if not _ready:
		return 0.0
	if _grid_step <= 0.0:
		return sample_local_xz(x, z)

	
	
	
	var fx := x * _inv_grid_step
	var fz := z * _inv_grid_step
	var cell_x := floori(fx)
	var cell_z := floori(fz)
	var u := fx - float(cell_x)   
	var v := fz - float(cell_z)   

	
	
	var x0 := float(cell_x) * _grid_step
	var z0 := float(cell_z) * _grid_step
	var x1 := x0 + _grid_step
	var z1 := z0 + _grid_step
	var h00 := sample_local_xz(x0, z0)   
	var h10 := sample_local_xz(x1, z0)   
	var h01 := sample_local_xz(x0, z1)   
	var h11 := sample_local_xz(x1, z1)   

	
	
	
	
	if u >= v:
		return h00 + u * (h10 - h00) + v * (h11 - h10)
	return h00 + v * (h01 - h00) + u * (h11 - h01)




func sample_latlon(lat: float, lon: float) -> float:
	if not _ready:
		return 0.0

	
	
	
	var fx := (lon - _min_lon) * _u_scale
	var fy := (_max_lat - lat) * _v_scale
	fx = clampf(fx, 0.0, float(_max_x))
	fy = clampf(fy, 0.0, float(_max_y))

	var x0 := int(fx)
	var y0 := int(fy)
	var x1 := mini(x0 + 1, _max_x)
	var y1 := mini(y0 + 1, _max_y)
	var tx := fx - float(x0)
	var ty := fy - float(y0)

	
	var row0 := y0 * _width
	var row1 := y1 * _width
	var h00 := _elev[row0 + x0]
	var h10 := _elev[row0 + x1]
	var h01 := _elev[row1 + x0]
	var h11 := _elev[row1 + x1]

	var top := lerpf(h00, h10, tx)
	var bottom := lerpf(h01, h11, tx)
	return lerpf(top, bottom, ty)






func _load_heightmap_image(path: String) -> Image:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var tex := ResourceLoader.load(path) as Texture2D
		if tex != null:
			var tex_img := tex.get_image()
			if tex_img != null:
				return tex_img
	return Image.load_from_file(path)


func _read_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("HeightProvider: cannot open metadata %s" % path)
		return {}
	var text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HeightProvider: metadata is not a JSON object: %s" % path)
		return {}
	return parsed
