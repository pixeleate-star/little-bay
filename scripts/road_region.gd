class_name RoadRegion
extends RefCounted





































enum DrivingSide {
	RIGHT = 0,  
	LEFT = 1,   
}


enum GiveWayStyle {
	
	
	DASHED = 0,
	
	
	SHARK_TEETH = 1,
}










const BENELUX_BOUNDS := Rect2(2.5, 49.4, 4.7, 4.2)   




const BRITISH_ISLES_BOUNDS := Rect2(-11.0, 49.8, 13.0, 11.2)  


var driving_side: int = DrivingSide.RIGHT
var give_way_style: int = GiveWayStyle.DASHED


func _init(
		p_driving_side: int = DrivingSide.RIGHT,
		p_give_way_style: int = GiveWayStyle.DASHED) -> void:
	driving_side = p_driving_side
	give_way_style = p_give_way_style



func drives_on_left() -> bool:
	return driving_side == DrivingSide.LEFT









func lateral_sign() -> float:
	return -1.0 if drives_on_left() else 1.0









static func for_coordinates(lat: float, lon: float) -> RoadRegion:
	var here := Vector2(lon, lat)
	if BENELUX_BOUNDS.has_point(here):
		return RoadRegion.new(DrivingSide.RIGHT, GiveWayStyle.SHARK_TEETH)
	if BRITISH_ISLES_BOUNDS.has_point(here):
		return RoadRegion.new(DrivingSide.LEFT, GiveWayStyle.DASHED)
	return RoadRegion.new()








static func for_osm_data(data: OSMParser.OSMData) -> RoadRegion:
	if data == null:
		return RoadRegion.new()
	return for_coordinates(data.center_lat, data.center_lon)




static func for_style(driving_side: int, give_way_style: int) -> RoadRegion:
	return RoadRegion.new(driving_side, give_way_style)
