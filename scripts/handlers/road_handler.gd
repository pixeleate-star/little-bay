class_name RoadHandler
extends OSMWayHandler



func handler_name() -> String:
	return "road"


static func is_road(way: OSMParser.OSMWay) -> bool:
	if not way.tags.has("highway"):
		return false
	
	
	if way.tags.get("highway", "") == "platform":
		return false
	return true


func matches(way: OSMParser.OSMWay, _ctx: OSMTileContext) -> bool:
	return is_road(way)


func build(way: OSMParser.OSMWay, ctx: OSMTileContext) -> Node3D:
	var node := ctx.way_builder.build_road(way, ctx.osm_data)
	if node != null:
		
		
		node.add_to_group(&"road_surface")
	return node
