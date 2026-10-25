class_name PlatformHandler
extends OSMWayHandler

















const PLATFORM_COLOR := Color(0.62, 0.62, 0.60)



const PLATFORM_Y_OFFSET := 0.05


func handler_name() -> String:
	return "platform"





static func is_platform(way: OSMParser.OSMWay) -> bool:
	if not OSMWayHandler.is_closed_way(way):
		return false
	if way.tags.get("public_transport", "") == "platform":
		return true
	if way.tags.get("railway", "") == "platform":
		return true
	if way.tags.get("highway", "") == "platform":
		return true
	return false


func matches(way: OSMParser.OSMWay, _ctx: OSMTileContext) -> bool:
	return is_platform(way)


func build(way: OSMParser.OSMWay, ctx: OSMTileContext) -> Node3D:
	var points := PolygonUtils.way_to_points(way.node_ids, ctx.osm_data.nodes)
	
	
	var surface_val: String = way.tags.get("surface", "")
	var color: Color = SurfaceHandler.SURFACE_COLORS.get(surface_val, PLATFORM_COLOR)
	
	
	
	var priority := PolygonUtils.PLATFORM_GROUND_PRIORITY + roundi(
		PolygonUtils.ground_tiebreak_bonus(PolygonUtils.polygon_area_xz(points)))
	var mesh_instance: MeshInstance3D
	if ctx.has_terrain:
		mesh_instance = PolygonUtils.build_terrain_draped_mesh(
			points, color, ctx.osm_data.height_provider, ctx.grid_step,
			PLATFORM_Y_OFFSET, ctx.tile_clip, priority)
	else:
		mesh_instance = PolygonUtils.build_flat_polygon_mesh(
			points, color, PLATFORM_Y_OFFSET, true, priority)
	if mesh_instance != null:
		mesh_instance.name = "Platform_%d" % way.id
	return mesh_instance
