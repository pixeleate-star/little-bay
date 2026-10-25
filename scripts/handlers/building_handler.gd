class_name BuildingHandler
extends OSMWayHandler











func handler_name() -> String:
	return "building"


static func is_building(way: OSMParser.OSMWay) -> bool:
	return way.tags.has("building")


func matches(way: OSMParser.OSMWay, _ctx: OSMTileContext) -> bool:
	return is_building(way)


func build(way: OSMParser.OSMWay, ctx: OSMTileContext) -> Node3D:
	if ctx.suppressed_building_ids.has(way.id):
		return null
	return ctx.building_builder.build_building_from_way(way, ctx.osm_data)
