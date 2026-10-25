class_name BuildingSurfaceUV
extends RefCounted





const CPU_SURFACES_META := &"cpu_surfaces"
static var _fallback_material: StandardMaterial3D = null


static func _material_or_fallback(material: Material) -> Material:
	if material != null:
		return material
	if _fallback_material == null:
		_fallback_material = StandardMaterial3D.new()
		_fallback_material.albedo_color = Color(0.62, 0.58, 0.52)
		_fallback_material.roughness = 0.9
	return _fallback_material



static func commit(st: SurfaceTool, instance: MeshInstance3D) -> ArrayMesh:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		instance.set_meta(CPU_SURFACES_META, [])
		return mesh
	var material := _material_or_fallback(mesh.surface_get_material(0))
	mesh.surface_set_material(0, material)
	instance.set_meta(CPU_SURFACES_META, [{"arrays": st.commit_to_arrays(), "material": material}])
	return mesh


static func apply(root: Node3D, origin: Vector3, ridge: Vector3) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			project(child, origin, ridge, child.name == "Roof")



static func faces_of(instance: MeshInstance3D) -> PackedVector3Array:
	if not instance.has_meta(CPU_SURFACES_META):
		return instance.mesh.get_faces()
	var faces := PackedVector3Array()
	for surface: Dictionary in instance.get_meta(CPU_SURFACES_META):
		var surface_arrays: Array = surface["arrays"]
		if surface_arrays.size() <= Mesh.ARRAY_VERTEX or surface_arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var raw_face_indices: Variant = null
		if surface_arrays.size() > Mesh.ARRAY_INDEX:
			raw_face_indices = surface_arrays[Mesh.ARRAY_INDEX]
		var indices: Variant = raw_face_indices
		if indices == null or indices.is_empty():
			faces.append_array(vertices)
		else:
			for index: int in indices:
				faces.append(vertices[index])
	return faces


static func project(instance: MeshInstance3D, origin: Vector3, ridge: Vector3, roof: bool) -> void:
	var mesh := ArrayMesh.new()
	var kept: Array[Dictionary] = []
	for surface: Dictionary in _surfaces_of(instance):
		var arrays: Array = surface["arrays"]
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var raw_indices: Variant = null
		if arrays.size() > Mesh.ARRAY_INDEX:
			raw_indices = arrays[Mesh.ARRAY_INDEX]
		var indices: PackedInt32Array = raw_indices as PackedInt32Array if raw_indices != null else PackedInt32Array()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(_material_or_fallback(surface["material"] as Material))
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i: int in range(0, count, 3):
			var a := indices[i] if not indices.is_empty() else i
			var b := indices[i + 1] if not indices.is_empty() else i + 1
			var c := indices[i + 2] if not indices.is_empty() else i + 2
			var n := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a]).normalized()
			if n.length_squared() < 0.5:
				continue
			var u := n.cross(Vector3.UP).normalized()
			if u.length_squared() < 0.5:
				u = ridge.normalized()
			var v := n.cross(u).normalized() if roof else Vector3.UP
			for index: int in [a, b, c]:
				var p := vertices[index] - origin
				st.set_normal(n)
				st.set_uv(Vector2(p.dot(u), p.dot(v)))
				st.add_vertex(vertices[index])
		st.generate_tangents()
		st.commit(mesh)
		kept.append({"arrays": st.commit_to_arrays(), "material": _material_or_fallback(surface["material"] as Material)})
	instance.mesh = mesh
	instance.set_meta(CPU_SURFACES_META, kept)


static func _surfaces_of(instance: MeshInstance3D) -> Array:
	if instance.has_meta(CPU_SURFACES_META):
		return instance.get_meta(CPU_SURFACES_META)
	var surfaces := []
	for surface: int in range(instance.mesh.get_surface_count()):
		surfaces.append({
			"arrays": instance.mesh.surface_get_arrays(surface),
			"material": instance.mesh.surface_get_material(surface),
		})
	return surfaces
