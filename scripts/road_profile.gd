class_name RoadProfile
extends RefCounted



















const ROAD_WIDTHS := {
	"motorway": 12.0,
	"motorway_link": 6.0,
	"trunk": 10.0,
	"trunk_link": 5.0,
	"primary": 8.0,
	"primary_link": 4.5,
	"secondary": 7.0,
	"secondary_link": 4.0,
	"tertiary": 6.0,
	"tertiary_link": 3.5,
	"residential": 5.0,
	"living_street": 4.0,
	"service": 3.0,
	"unclassified": 5.0,
	"pedestrian": 3.0,
	"footway": 1.5,
	"cycleway": 2.0,
	"path": 1.0,
	"track": 3.0,
	"busway": 6.0,
}






const ROAD_COLORS := {
	"motorway": Color("2d272f"), "motorway_link": Color("2d272f"),
	"trunk": Color("2d272f"), "trunk_link": Color("2d272f"),
	"primary": Color("2d272f"), "primary_link": Color("2d272f"),
	"secondary": Color("2d272f"), "secondary_link": Color("2d272f"),
	"tertiary": Color("2d272f"), "tertiary_link": Color("2d272f"),
	"residential": Color("2d272f"), "living_street": Color("2d272f"),
	"service": Color("2d272f"), "busway": Color("2d272f"),
	"footway": Color("8f5676"), "cycleway": Color("415d99"),
	"path": Color("8f5676"), "pedestrian": Color("8f5676"),
}

const DEFAULT_WIDTH := 4.0
const DEFAULT_COLOR := Color("2d272f")



const ROAD_Y := 0.02



const SIDEWALK_WIDTH := 2.2
const SIDEWALK_HEIGHT := 0.12
const SIDEWALK_COLOR := Color("9d696a")




const LAYER_HEIGHT := 5.0



const SOFT_TYPES := {
	"footway": true,
	"path": true,
	"cycleway": true,
	"track": true,
	"pedestrian": true,
	"steps": true,
	"bridleway": true,
	"corridor": true,
}




const DRIVABLE_TYPES := {
	"motorway": true,
	"motorway_link": true,
	"trunk": true,
	"trunk_link": true,
	"primary": true,
	"primary_link": true,
	"secondary": true,
	"secondary_link": true,
	"tertiary": true,
	"tertiary_link": true,
	"residential": true,
	"living_street": true,
	"unclassified": true,
	"service": true,
	"busway": true,
}



static func is_road(way: OSMParser.OSMWay) -> bool:
	if not way.tags.has("highway"):
		return false
	
	return String(way.tags.get("highway", "")) != "platform"





static func is_drivable(way: OSMParser.OSMWay) -> bool:
	if not is_road(way):
		return false
	return DRIVABLE_TYPES.has(String(way.tags.get("highway", "")))



static func is_paved(highway_type: String) -> bool:
	return not SOFT_TYPES.has(highway_type)



static func highway_type(way: OSMParser.OSMWay) -> String:
	return String(way.tags.get("highway", "unclassified"))



static func color_for(highway_type: String) -> Color:
	return ROAD_COLORS.get(highway_type, DEFAULT_COLOR)














static func width_for(way: OSMParser.OSMWay) -> float:
	var ht := highway_type(way)
	var tags := way.tags

	if tags.has("width"):
		var explicit: float = String(tags["width"]).to_float()
		if explicit > 0.0:
			return explicit

	var default_width: float = ROAD_WIDTHS.get(ht, DEFAULT_WIDTH)
	if SOFT_TYPES.has(ht):
		return default_width

	var lane_spec := RoadLaneSpec.from_tags(ht, tags)
	if lane_spec == null or not lane_spec.marked:
		return default_width

	var per_lane: float = maxf(default_width * 0.5, RoadLaneSpec.LANE_WIDTH)
	return lane_spec.lane_count * per_lane











static func layer_offset(way: OSMParser.OSMWay) -> float:
	return float(layer_of(way)) * LAYER_HEIGHT



static func layer_of(way: OSMParser.OSMWay) -> int:
	var tags := way.tags
	if tags.has("layer"):
		var raw := String(tags["layer"])
		if raw.is_valid_int():
			return clampi(raw.to_int(), -5, 5)

	
	
	var bridge := String(tags.get("bridge", ""))
	if bridge != "" and bridge != "no":
		return 1
	var tunnel := String(tags.get("tunnel", ""))
	if tunnel != "" and tunnel != "no":
		return -1
	return 0




static func is_bridge(way: OSMParser.OSMWay) -> bool:
	var bridge := String(way.tags.get("bridge", ""))
	return bridge != "" and bridge != "no"




static func is_tunnel(way: OSMParser.OSMWay) -> bool:
	var tunnel := String(way.tags.get("tunnel", ""))
	if tunnel != "" and tunnel != "no":
		return true
	return layer_of(way) < 0














static func sidewalk_sides(tags: Dictionary) -> Dictionary:
	var left := false
	var right := false

	if tags.has("sidewalk"):
		match String(tags["sidewalk"]):
			"both":
				left = true
				right = true
			"left":
				left = true
			"right":
				right = true
			_:
				
				left = false
				right = false

	if tags.has("sidewalk:both"):
		var both := _is_present(String(tags["sidewalk:both"]))
		left = both
		right = both

	if tags.has("sidewalk:left"):
		left = _is_present(String(tags["sidewalk:left"]))
	if tags.has("sidewalk:right"):
		right = _is_present(String(tags["sidewalk:right"]))

	return {"left": left, "right": right}




static func _is_present(value: String) -> bool:
	return value != "no" and value != "none" and value != "separate" and value != ""
