class_name RailwayHandler
extends OSMWayHandler







const _RAILWAY_LINE_VALUES := {
	"rail": true, "light_rail": true, "subway": true, "tram": true,
	"narrow_gauge": true, "monorail": true, "funicular": true,
	"preserved": true, "disused": true, "miniature": true,
}


func handler_name() -> String:
	return "railway"


static func is_railway(way: OSMParser.OSMWay) -> bool:
	return _RAILWAY_LINE_VALUES.has(way.tags.get("railway", ""))


func matches(way: OSMParser.OSMWay, _ctx: OSMTileContext) -> bool:
	return is_railway(way)


func build(way: OSMParser.OSMWay, ctx: OSMTileContext) -> Node3D:
	return ctx.way_builder.build_railway(way, ctx.osm_data)
