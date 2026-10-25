class_name TrafficSpawnPolicy
extends RefCounted










class RoadPlan:
	var road: TrafficRoadNetwork.Road
	var desired_cars: int

	func _init(r: TrafficRoadNetwork.Road, cars: int) -> void:
		road = r
		desired_cars = cars











static func select_active_roads(
		roads: Array[TrafficRoadNetwork.Road],
		center: Vector3,
		radius: float,
		max_cars: int) -> Array[RoadPlan]:
	var plans: Array[RoadPlan] = []
	if max_cars <= 0 or radius <= 0.0:
		return plans

	var in_range: Array[TrafficRoadNetwork.Road] = []
	for road: TrafficRoadNetwork.Road in roads:
		if _road_in_range(road, center, radius):
			in_range.append(road)

	
	
	in_range.sort_custom(_wider_first)

	var budget := max_cars
	for road: TrafficRoadNetwork.Road in in_range:
		if budget <= 0:
			break
		
		
		var want: int = clampi(maxi(1, road.capacity), 1, budget)
		plans.append(RoadPlan.new(road, want))
		budget -= want
	return plans



static func total_desired(plans: Array[RoadPlan]) -> int:
	var total := 0
	for p: RoadPlan in plans:
		total += p.desired_cars
	return total





static func _road_in_range(road: TrafficRoadNetwork.Road, center: Vector3, radius: float) -> bool:
	var r2 := radius * radius
	for p: Vector3 in road.points:
		var dx := p.x - center.x
		var dz := p.z - center.z
		if dx * dx + dz * dz <= r2:
			return true
	return false




static func _wider_first(a: TrafficRoadNetwork.Road, b: TrafficRoadNetwork.Road) -> bool:
	if a.width == b.width:
		return a.length > b.length
	return a.width > b.width
