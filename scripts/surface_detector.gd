class_name SurfaceDetector
extends RefCounted
































enum Surface {
	ROAD,
	GRASS,
}



const _Y_TOLERANCE := 1.0




const _CULL_DISTANCE_SQ := 2500.0  




const _EDGE_TOLERANCE := 0.15


var _tree: SceneTree = null




var _triangle_cache: Dictionary = {}



func init(tree: SceneTree) -> void:
	_tree = tree




func detect(world_pos: Vector3) -> Surface:
	if _tree == null:
		return Surface.GRASS

	var roads := _tree.get_nodes_in_group(&"road_surface")
	for node: Node in roads:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue

		
		
		
		var world_aabb := mi.global_transform * mi.get_aabb()

		var center := world_aabb.get_center()
		var dx := center.x - world_pos.x
		var dz := center.z - world_pos.z
		if dx * dx + dz * dz > _CULL_DISTANCE_SQ:
			continue

		
		if not _in_aabb_xz(world_aabb, world_pos):
			continue

		
		
		if _covers_point(mi, world_pos):
			return Surface.ROAD

	return Surface.GRASS



func _in_aabb_xz(box: AABB, p: Vector3) -> bool:
	var min_y := box.position.y - _Y_TOLERANCE
	var max_y := box.end.y + _Y_TOLERANCE
	return p.x >= box.position.x - _EDGE_TOLERANCE \
		and p.x <= box.end.x + _EDGE_TOLERANCE \
		and p.z >= box.position.z - _EDGE_TOLERANCE \
		and p.z <= box.end.z + _EDGE_TOLERANCE \
		and p.y >= min_y and p.y <= max_y



func _covers_point(mi: MeshInstance3D, p: Vector3) -> bool:
	var tris := _triangles_of(mi)
	var count := tris.size()
	var i := 0
	while i + 2 < count:
		if _point_in_triangle_xz(p, tris[i], tris[i + 1], tris[i + 2]):
			return true
		i += 3
	return false










func _triangles_of(mi: MeshInstance3D) -> PackedVector3Array:
	var mesh := mi.mesh
	if mesh == null:
		return PackedVector3Array()

	var key := mesh.get_rid()
	if _triangle_cache.has(key):
		return _triangle_cache[key]

	var faces := mesh.get_faces()
	
	
	var xform := mi.global_transform
	if not xform.is_equal_approx(Transform3D.IDENTITY):
		var moved := PackedVector3Array()
		moved.resize(faces.size())
		for i: int in range(faces.size()):
			moved[i] = xform * faces[i]
		faces = moved

	_triangle_cache[key] = faces
	return faces




func _point_in_triangle_xz(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0x := c.x - a.x
	var v0z := c.z - a.z
	var v1x := b.x - a.x
	var v1z := b.z - a.z
	var v2x := p.x - a.x
	var v2z := p.z - a.z

	var dot00 := v0x * v0x + v0z * v0z
	var dot01 := v0x * v1x + v0z * v1z
	var dot02 := v0x * v2x + v0z * v2z
	var dot11 := v1x * v1x + v1z * v1z
	var dot12 := v1x * v2x + v1z * v2z

	var denom := dot00 * dot11 - dot01 * dot01
	if absf(denom) < 0.0000001:
		return false  

	var inv := 1.0 / denom
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv

	
	
	var scale := sqrt(maxf(dot00, dot11))
	var eps := 0.0 if scale < 0.0001 else _EDGE_TOLERANCE / scale

	return u >= -eps and v >= -eps and u + v <= 1.0 + eps
