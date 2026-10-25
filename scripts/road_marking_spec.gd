class_name RoadMarkingSpec
extends RefCounted




















enum Kind {
	ZEBRA = 1,        
	STOP = 2,         
	GIVE_WAY = 3,     
	
	
	
	
	
	
	
	
	SHARK_TEETH = 4,
}




const MAX_MARKINGS := 8



class Marking:
	var along: float = 0.0
	var kind: int = Kind.ZEBRA
	
	
	
	
	
	
	
	
	var facing: float = 1.0

	func _init(
			p_along: float = 0.0, p_kind: int = Kind.ZEBRA,
			p_facing: float = 1.0) -> void:
		along = p_along
		kind = p_kind
		facing = p_facing


var markings: Array[Marking] = []



func is_empty() -> bool:
	return markings.is_empty()










func rebased(offset: float) -> RoadMarkingSpec:
	if offset <= 0.0:
		return self
	var out := RoadMarkingSpec.new()
	for m: Marking in markings:
		var shifted := m.along - offset
		if shifted < 0.0:
			continue
		out.markings.append(Marking.new(shifted, m.kind, m.facing))
	return out




func along_positions() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(mini(markings.size(), MAX_MARKINGS)):
		out.append(markings[i].along)
	return out




func kinds() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(mini(markings.size(), MAX_MARKINGS)):
		out.append(float(markings[i].kind))
	return out




func facings() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(mini(markings.size(), MAX_MARKINGS)):
		out.append(markings[i].facing)
	return out


















static func from_way(
		node_ids: Array[int], osm_nodes: Dictionary,
		region: RoadRegion = null) -> RoadMarkingSpec:
	var spec := RoadMarkingSpec.new()

	
	
	var pts: Array = []          
	var along_at: Array = []     
	var acc := 0.0
	for i in range(node_ids.size()):
		var nid: int = node_ids[i]
		if not osm_nodes.has(nid):
			continue
		var p: Vector3 = osm_nodes[nid].local_pos
		var here := Vector2(p.x, p.z)
		if not pts.is_empty():
			acc += here.distance_to(pts[pts.size() - 1])
		pts.append(here)
		along_at.append(acc)

		var tags: Dictionary = osm_nodes[nid].tags
		var kind := _classify(tags, region)
		if kind != 0:
			spec.markings.append(Marking.new(acc, kind, _facing_of(tags, i, node_ids.size())))

	
	
	spec.markings.sort_custom(func(a: Marking, b: Marking) -> bool:
		return a.along < b.along)
	return spec
















static func _facing_of(tags: Dictionary, index: int, node_count: int) -> float:
	match String(tags.get("direction", "")):
		"forward":
			return 1.0
		"backward":
			return -1.0
	if node_count < 2:
		return 1.0
	
	return 1.0 if float(index) >= float(node_count - 1) * 0.5 else -1.0










static func _classify(tags: Dictionary, region: RoadRegion = null) -> int:
	var highway := String(tags.get("highway", ""))
	if highway == "stop":
		return Kind.STOP
	if highway == "give_way":
		return give_way_kind(region)
	if highway == "crossing":
		return _crossing_kind(tags)
	return 0





static func give_way_kind(region: RoadRegion) -> int:
	if region != null and region.give_way_style == RoadRegion.GiveWayStyle.SHARK_TEETH:
		return Kind.SHARK_TEETH
	return Kind.GIVE_WAY





static func _crossing_kind(tags: Dictionary) -> int:
	var crossing_markings := String(tags.get("crossing:markings", tags.get("marking", "")))
	if crossing_markings != "":
		return 0 if (crossing_markings == "no") else Kind.ZEBRA

	var crossing := String(tags.get("crossing", ""))
	match crossing:
		"zebra", "marked", "uncontrolled", "traffic_signals":
			return Kind.ZEBRA
		"unmarked", "no", "informal":
			return 0
		_:
			
			
			return Kind.ZEBRA
