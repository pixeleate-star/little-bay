class_name OSMWayHandler
extends RefCounted



















func handler_name() -> String:
	return "OSMWayHandler"




func matches(_way: OSMParser.OSMWay, _ctx: OSMTileContext) -> bool:
	return false





func build(_way: OSMParser.OSMWay, _ctx: OSMTileContext) -> Node3D:
	return null







static func is_closed_way(way: OSMParser.OSMWay) -> bool:
	return way.node_ids.size() >= 4 and way.node_ids[0] == way.node_ids[-1]
