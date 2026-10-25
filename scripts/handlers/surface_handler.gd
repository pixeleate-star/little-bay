class_name SurfaceHandler
extends OSMWayHandler













const SURFACE_COLORS := {
	
	"paving_stones": Color(0.55, 0.52, 0.48),
	"sett": Color(0.50, 0.47, 0.43),
	"cobblestone": Color(0.48, 0.45, 0.42),
	"unhewn_cobblestone": Color(0.46, 0.44, 0.41),
	
	"concrete": Color(0.58, 0.58, 0.56),
	"concrete:plates": Color(0.56, 0.56, 0.54),
	"concrete:lanes": Color(0.56, 0.56, 0.54),
	"asphalt": Color(0.20, 0.20, 0.20),
	
	"compacted": Color(0.52, 0.48, 0.40),
	"gravel": Color(0.55, 0.52, 0.46),
	"fine_gravel": Color(0.58, 0.55, 0.48),
	"pebblestone": Color(0.54, 0.52, 0.48),
	
	"sand": Color(0.72, 0.67, 0.52),
	"ground": Color(0.45, 0.40, 0.32),
	"earth": Color(0.45, 0.38, 0.30),
	"dirt": Color(0.42, 0.36, 0.28),
	"mud": Color(0.35, 0.30, 0.24),
	"grass": Color(0.40, 0.65, 0.30),
	"grass_paver": Color(0.45, 0.58, 0.38),
	
	"metal": Color(0.50, 0.50, 0.55),
	"wood": Color(0.50, 0.40, 0.28),
	"tartan": Color(0.55, 0.25, 0.22),
	"rubber": Color(0.30, 0.30, 0.30),
	"acrylic": Color(0.30, 0.45, 0.55),
	
	"bricks": Color(0.58, 0.38, 0.28),
	"tiles": Color(0.60, 0.55, 0.50),
	"stone": Color(0.52, 0.50, 0.46),
}

const DEFAULT_SURFACE_COLOR := Color(0.50, 0.48, 0.45)


func handler_name() -> String:
	return "surface"





static func is_surface_area(way: OSMParser.OSMWay) -> bool:
	if not way.tags.has("surface"):
		return false
	if not OSMWayHandler.is_closed_way(way):
		return false
	
	
	if way.tags.has("highway") or way.tags.has("building") \
			or way.tags.has("building:part") or way.tags.has("railway") \
			or way.tags.has("waterway") or way.tags.has("amenity") \
			or way.tags.has("landuse") or way.tags.has("natural") \
			or way.tags.has("leisure"):
		return false
	return true


func matches(way: OSMParser.OSMWay, _ctx: OSMTileContext) -> bool:
	return is_surface_area(way)


func build(way: OSMParser.OSMWay, ctx: OSMTileContext) -> Node3D:
	var points := PolygonUtils.way_to_points(way.node_ids, ctx.osm_data.nodes)
	var surface_val: String = way.tags.get("surface", "")
	var color: Color = SURFACE_COLORS.get(surface_val, DEFAULT_SURFACE_COLOR)
	
	
	
	
	var priority := PolygonUtils.SURFACE_GROUND_PRIORITY + roundi(
		PolygonUtils.ground_tiebreak_bonus(PolygonUtils.polygon_area_xz(points)))
	var mesh_instance: MeshInstance3D
	if ctx.has_terrain:
		mesh_instance = PolygonUtils.build_terrain_draped_mesh(
			points, color, ctx.osm_data.height_provider, ctx.grid_step, 0.012, ctx.tile_clip, priority)
	else:
		mesh_instance = PolygonUtils.build_flat_polygon_mesh(points, color, 0.012, true, priority)
	if mesh_instance != null:
		mesh_instance.name = "Surface_%d" % way.id
	return mesh_instance
