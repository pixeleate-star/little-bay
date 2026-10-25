class_name OSMTileContext
extends RefCounted

const RoadNetworkContextScript := preload("res://scripts/road_network_context.gd")













var osm_data: OSMParser.OSMData = null


var tile_key: Vector2i = Vector2i.ZERO


var tile_size: float = 200.0



var has_terrain: bool = false



var grid_step: float = 0.0



var tile_clip: Variant = null



var suppressed_building_ids: Dictionary = {}





var road_network: RoadNetworkContextScript = null




var way_builder: OSMWayBuilder = null
var infrastructure_builder: OSMInfrastructureBuilder = null
var building_builder: OSMBuildingBuilder = null
var asset_placer: OSMAssetPlacer = null





func height_provider() -> HeightProvider:
	if has_terrain and osm_data != null:
		return osm_data.height_provider
	return null
