class_name RoadNetworkContext
extends RefCounted

const RoadProfileScript := preload("res://scripts/road_profile.gd")
const RoadNetworkContextScript := preload("res://scripts/road_network_context.gd")
const RoadJunctionSolverScript := preload("res://scripts/road_junction_solver.gd")





























var junctions: Dictionary = {}







var owned_caps: Dictionary = {}



func has_junction(node_id: int) -> bool:
	return junctions.has(node_id)



func junction_at(node_id: int) -> RoadJunctionSolverScript.Junction:
	return junctions.get(node_id, null)







func trim_at(way_id: int, node_id: int, at_way_start: bool) -> float:
	var junction: RoadJunctionSolverScript.Junction = junctions.get(node_id, null)
	if junction == null:
		return 0.0
	return junction.trim_for(way_id, at_way_start)



func owned_junctions() -> Array[RoadJunctionSolverScript.Junction]:
	var out: Array[RoadJunctionSolverScript.Junction] = []
	for nid: int in owned_caps:
		var j: RoadJunctionSolverScript.Junction = junctions.get(nid, null)
		if j != null:
			out.append(j)
	return out












static func build(
		own_ways: Array, halo_ways: Array, nodes: Dictionary,
		tile_rect: Array) -> RoadNetworkContextScript:
	var ctx := RoadNetworkContextScript.new()

	
	
	
	var is_road_fn := func(w: OSMParser.OSMWay) -> bool:
		return RoadProfileScript.is_drivable(w)
	var width_fn := func(w: OSMParser.OSMWay) -> float:
		return RoadProfileScript.width_for(w)

	ctx.junctions = RoadJunctionSolverScript.solve_all(
		halo_ways, nodes, is_road_fn, width_fn)
	if ctx.junctions.is_empty():
		return ctx

	
	
	if tile_rect.size() < 4:
		for nid: int in ctx.junctions:
			ctx.owned_caps[nid] = true
		return ctx

	var min_x: float = tile_rect[0]
	var max_x: float = tile_rect[1]
	var min_z: float = tile_rect[2]
	var max_z: float = tile_rect[3]
	for nid: int in ctx.junctions:
		var j: RoadJunctionSolverScript.Junction = ctx.junctions[nid]
		var p := j.center
		
		
		if p.x >= min_x and p.x < max_x and p.z >= min_z and p.z < max_z:
			ctx.owned_caps[nid] = true
	return ctx
