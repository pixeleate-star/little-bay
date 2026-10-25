class_name RoadLaneSpec
extends RefCounted




















var lane_count: int = 2

var forward_lanes: int = 1

var backward_lanes: int = 1


var one_way: bool = false


var marked: bool = true


const UNMARKED_TYPES := {
	"footway": true,
	"path": true,
	"cycleway": true,
	"track": true,
	"pedestrian": true,
	"steps": true,
	"bridleway": true,
	"corridor": true,
}





const UNDIVIDED_TYPES := {
	"service": true,
	"living_street": true,
}


const LANE_WIDTH := 3.5




static func from_tags(highway_type: String, tags: Dictionary) -> RoadLaneSpec:
	var spec := RoadLaneSpec.new()

	spec.marked = not UNMARKED_TYPES.has(highway_type)
	spec.one_way = _parse_one_way(tags)

	
	var fwd := _tag_int(tags, "lanes:forward", -1)
	var bwd := _tag_int(tags, "lanes:backward", -1)
	var total := _tag_int(tags, "lanes", -1)

	if fwd >= 0 or bwd >= 0:
		
		
		spec.forward_lanes = maxi(fwd, 0)
		spec.backward_lanes = maxi(bwd, 0)
		if fwd < 0 and total > 0:
			spec.forward_lanes = maxi(total - spec.backward_lanes, 0)
		if bwd < 0 and total > 0:
			spec.backward_lanes = maxi(total - spec.forward_lanes, 0)
		spec.lane_count = maxi(spec.forward_lanes + spec.backward_lanes, 1)
	elif total > 0:
		spec.lane_count = total
		_split_by_direction(spec)
	else:
		
		
		spec.lane_count = 1 if spec.one_way else 2
		_split_by_direction(spec)

	
	
	if UNDIVIDED_TYPES.has(highway_type) and spec.lane_count <= 2:
		spec.forward_lanes = spec.lane_count
		spec.backward_lanes = 0
		spec.one_way = spec.one_way  

	return spec





static func _split_by_direction(spec: RoadLaneSpec) -> void:
	if spec.one_way:
		spec.forward_lanes = spec.lane_count
		spec.backward_lanes = 0
		return
	spec.forward_lanes = int(ceil(spec.lane_count / 2.0))
	spec.backward_lanes = spec.lane_count - spec.forward_lanes




func has_center_line() -> bool:
	return not one_way and forward_lanes > 0 and backward_lanes > 0


static func _parse_one_way(tags: Dictionary) -> bool:
	var junction := String(tags.get("junction", ""))
	if junction == "roundabout" or junction == "circular":
		return true
	var v := String(tags.get("oneway", "no"))
	return v == "yes" or v == "true" or v == "1" or v == "-1"


static func _tag_int(tags: Dictionary, key: String, fallback: int) -> int:
	if not tags.has(key):
		return fallback
	var s := String(tags[key])
	if not s.is_valid_int():
		return fallback
	return s.to_int()
