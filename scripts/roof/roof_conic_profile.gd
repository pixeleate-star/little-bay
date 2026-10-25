class_name RoofConicProfile
extends RefCounted














static func pyramidal(points: PackedVector3Array, base_y: float, roof_h: float,
		roof_color: Color) -> Array[Node3D]:
	var centroid := PolygonUtils.polygon_centroid(points)
	var profile: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.0, 1.0)]
	return build(points, base_y, roof_h, roof_color, centroid, profile)




static func dome(points: PackedVector3Array, base_y: float, roof_h: float,
		roof_color: Color) -> Array[Node3D]:
	var centroid := PolygonUtils.polygon_centroid(points)
	var dome_profile: Array[Vector2] = _make_dome_profile(8)
	return build(points, base_y, roof_h, roof_color, centroid, dome_profile)


static func _make_dome_profile(rings: int) -> Array[Vector2]:
	var profile: Array[Vector2] = []
	for j: int in range(rings + 1):
		var t := float(j) / rings
		var angle := t * PI * 0.5
		
		
		profile.append(Vector2(cos(angle), sin(angle)))
	return profile





static func onion(points: PackedVector3Array, base_y: float, roof_h: float,
		roof_color: Color) -> Array[Node3D]:
	var centroid := PolygonUtils.polygon_centroid(points)
	var onion_profile := _make_onion_profile()
	return build(points, base_y, roof_h, roof_color, centroid, onion_profile)



static func _make_onion_profile() -> Array[Vector2]:
	return [
		Vector2(1.0000, 0.0000),  
		Vector2(1.2971, 0.0999),  
		Vector2(1.2971, 0.2462),  
		Vector2(1.1273, 0.3608),  
		Vector2(0.6219, 0.4785),  
		Vector2(0.2131, 0.5984),  
		Vector2(0.1003, 0.7243),  
		Vector2(0.0000, 1.0000),  
	]





static func build(points: PackedVector3Array, base_y: float, roof_h: float,
		roof_color: Color, center: Vector3, profile: Array[Vector2]) -> Array[Node3D]:
	var st := RoofGeometry.new_st(roof_color)
	var n := points.size() - 1  
	if n < 3:
		return []
	var rows := profile.size() - 1

	
	
	
	var rings: Array[PackedVector3Array] = []
	for j: int in range(rows + 1):
		var ring: PackedVector3Array = []
		var scale_factor: float = profile[j].x
		var ring_y := base_y + roof_h * profile[j].y
		for i: int in range(n):
			var px := center.x + (points[i].x - center.x) * scale_factor
			var pz := center.z + (points[i].z - center.z) * scale_factor
			ring.append(Vector3(px, ring_y, pz))
		rings.append(ring)

	
	
	
	
	
	for j: int in range(rows - 1):
		var lower := rings[j]
		var upper := rings[j + 1]
		for i: int in range(n):
			var ni := (i + 1) % n
			RoofGeometry.add_quad(st, lower[i], upper[i], upper[ni], lower[ni])

	
	
	var top_ring := rings[rows - 1]
	var apex := Vector3(center.x, base_y + roof_h * profile[rows].y, center.z)
	for i: int in range(n):
		var ni := (i + 1) % n
		RoofGeometry.add_tri(st, top_ring[ni], top_ring[i], apex)

	var result: Array[Node3D] = []
	result.append(RoofGeometry.make_mesh(st, "Roof"))
	return result
