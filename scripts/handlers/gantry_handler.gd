class_name GantryHandler
extends OSMWayHandler







func handler_name() -> String:
	return "gantry"


static func is_gantry(way: OSMParser.OSMWay) -> bool:
	if OSMWayHandler.is_closed_way(way):
		return false
	return way.tags.get("man_made", "") == "gantry"


func matches(way: OSMParser.OSMWay, _ctx: OSMTileContext) -> bool:
	return is_gantry(way)


func build(way: OSMParser.OSMWay, ctx: OSMTileContext) -> Node3D:
	return ctx.infrastructure_builder.build_gantry(way, ctx.osm_data)
