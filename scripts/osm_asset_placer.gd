class_name OSMAssetPlacer
extends RefCounted








var _scene_cache: Dictionary = {}  





var show_debug_labels: bool = false







var lamp_lights: StreetLampLights = null





const ASSET_DEFS := {
	"highway": {
		"traffic_signals": { "color": Color("009b88"), "size": Vector3(0.42, 4.6, 0.42), "y_offset": 2.3, "label": "Traffic Light", "scene": "res://scenes/models/traffic_light.blend" },
		
		
		
		
		
		
		"street_lamp": {
			"color": Color(0.25, 0.22, 0.12), "size": Vector3(0.15, 4.0, 0.15), "y_offset": 2.0, "label": "Street Lamp", "light": true,
			"support": {
				"bent_mast": { "scene": "res://scenes/models/street_lamp-bent_mast.blend" },
			},
		},
		"bus_stop": { "color": Color(0.2, 0.4, 0.8), "size": Vector3(0.8, 2.5, 0.3), "y_offset": 1.25, "label": "Bus Stop", "scene": "res://scenes/models/bus_stop.blend" },
		
		
		
		
		
		"stop": { "color": Color(0.9, 0.1, 0.1), "size": Vector3(0.5, 2.0, 0.05), "y_offset": 1.0, "label": "Stop Sign" },
		"give_way": { "color": Color(0.9, 0.9, 0.1), "size": Vector3(0.5, 2.0, 0.05), "y_offset": 1.0, "label": "Give Way", "scene": "res://scenes/models/give_way.blend" },
	},
	"natural": {
		"tree": { "color": Color(0.15, 0.5, 0.1), "size": Vector3(2.0, 5.0, 2.0), "y_offset": 2.5, "label": "Tree", "scene": "res://scenes/models/tree.blend" },
		"tree_row": { "color": Color(0.15, 0.5, 0.1), "size": Vector3(2.0, 5.0, 2.0), "y_offset": 2.5, "label": "Tree", "scene": "res://scenes/models/tree.blend" },
		"peak": { "color": Color(0.6, 0.5, 0.4), "size": Vector3(1.0, 3.0, 1.0), "y_offset": 1.5, "label": "Peak" },
	},
	"amenity": {
		"bench": { "color": Color(0.5, 0.35, 0.2), "size": Vector3(1.5, 0.5, 0.5), "y_offset": 0.25, "label": "Bench" },
		"waste_basket": { "color": Color(0.3, 0.3, 0.3), "size": Vector3(0.4, 0.8, 0.4), "y_offset": 0.4, "label": "Waste Basket" },
		"post_box": { "color": Color(0.9, 0.8, 0.1), "size": Vector3(0.4, 1.2, 0.3), "y_offset": 0.6, "label": "Post Box" },
		"telephone": { "color": Color(0.8, 0.2, 0.2), "size": Vector3(0.8, 2.2, 0.8), "y_offset": 1.1, "label": "Phone Booth" },
		"fuel": { "color": Color(0.8, 0.3, 0.1), "size": Vector3(2.0, 3.0, 1.0), "y_offset": 1.5, "label": "Fuel Station" },
		"parking": { "color": Color(0.3, 0.3, 0.7), "size": Vector3(1.0, 2.0, 0.1), "y_offset": 1.0, "label": "Parking Sign" },
		"charging_station": { "color": Color(0.2, 0.8, 0.3), "size": Vector3(0.5, 1.4, 0.4), "y_offset": 0.7, "label": "Charging Station" },
	},
	"barrier": {
		"bollard": { "color": Color(0.5, 0.5, 0.5), "size": Vector3(0.2, 0.8, 0.2), "y_offset": 0.4, "label": "Bollard", "scene": "res://scenes/models/bollard.blend" },
		"gate": { "color": Color(0.4, 0.3, 0.2), "size": Vector3(3.0, 1.5, 0.1), "y_offset": 0.75, "label": "Gate" },
		"fence": { "color": Color(0.5, 0.4, 0.3), "size": Vector3(0.1, 1.5, 0.1), "y_offset": 0.75, "label": "Fence Post" },
		"hedge": { "color": Color(0.2, 0.45, 0.15), "size": Vector3(0.6, 1.2, 0.6), "y_offset": 0.6, "label": "Hedge" },
		"wall": { "color": Color(0.55, 0.55, 0.55), "size": Vector3(0.3, 1.5, 0.3), "y_offset": 0.75, "label": "Wall" },
		
		"noise_barrier": { "color": Color(0.5, 0.52, 0.58), "size": Vector3(0.3, 3.0, 0.3), "y_offset": 1.5, "label": "Noise Barrier" },
	},
	"man_made": {
		"tower": { "color": Color(0.6, 0.6, 0.6), "size": Vector3(2.0, 15.0, 2.0), "y_offset": 7.5, "label": "Tower" },
		"mast": { "color": Color(0.5, 0.5, 0.5), "size": Vector3(0.5, 20.0, 0.5), "y_offset": 10.0, "label": "Mast" },
		"chimney": { "color": Color(0.55, 0.45, 0.4), "size": Vector3(1.5, 25.0, 1.5), "y_offset": 12.5, "label": "Chimney" },
	},
	"power": {
		"tower": { "color": Color(0.5, 0.5, 0.55), "size": Vector3(1.5, 20.0, 1.5), "y_offset": 10.0, "label": "Power Tower" },
		"pole": { "color": Color(0.45, 0.4, 0.35), "size": Vector3(0.2, 8.0, 0.2), "y_offset": 4.0, "label": "Power Pole" },
	},
	"tourism": {
		"information": { "color": Color(0.2, 0.5, 0.8), "size": Vector3(0.5, 2.0, 0.1), "y_offset": 1.0, "label": "Info Board" },
		"viewpoint": { "color": Color(0.3, 0.6, 0.9), "size": Vector3(1.0, 1.0, 1.0), "y_offset": 0.5, "label": "Viewpoint" },
	},
	"shop": {
		"*": { "color": Color(0.8, 0.6, 0.2), "size": Vector3(1.0, 2.5, 1.0), "y_offset": 1.25, "label": "Shop" },
	},
	"traffic_sign": {
		"city_limit": { "color": Color(0.9, 0.9, 0.9), "size": Vector3(0.6, 2.0, 0.05), "y_offset": 1.5, "label": "Traffic Sign", "scene": "res://scenes/models/city_limit.blend" },
		"*": { "color": Color(0.9, 0.9, 0.9), "size": Vector3(0.6, 2.0, 0.05), "y_offset": 1.5, "label": "Traffic Sign" },
	},
}











func place_assets_batched(nodes: Array) -> Node3D:
	if nodes.is_empty():
		return null

	var root := Node3D.new()
	root.name = "Assets"

	
	
	var box_groups: Dictionary = {}  

	
	
	var lamp_group := StreetLampLights.LampGroup.new()

	for node: OSMParser.OSMNode in nodes:
		var def := _find_asset_def(node.tags)
		if def.is_empty():
			continue

		if def.get("light", false):
			
			var lamp := _build_street_lamp(def, node, lamp_group)
			if lamp != null:
				root.add_child(lamp)
				_add_debug_label_at(root, def, node.tags, node.local_pos)
			continue

		if def.has("scene"):
			
			var placed := place_asset(node)
			if placed != null:
				root.add_child(placed)
			continue

		var key := _box_group_key(def)
		if not box_groups.has(key):
			box_groups[key] = { "def": def, "transforms": [] as Array[Transform3D] }
		var y_offset: float = def["y_offset"]

		
		
		
		var count := _node_block_count(node.tags)
		var size: Vector3 = def["size"]
		var spacing: float = size.x + 0.2
		var row_start: float = -spacing * float(count - 1) * 0.5
		for i in range(count):
			var col_offset := Vector3(row_start + spacing * float(i), 0.0, 0.0)
			var xform := Transform3D(Basis.IDENTITY, node.local_pos + col_offset + Vector3(0.0, y_offset, 0.0))
			box_groups[key]["transforms"].append(xform)

		
		
		
		
		_add_debug_label_at(root, def, node.tags, node.local_pos)

	for key: String in box_groups:
		var group: Dictionary = box_groups[key]
		var mmi := _build_box_multimesh(group["def"], group["transforms"])
		if mmi != null:
			root.add_child(mmi)

	if root.get_child_count() == 0:
		root.free()
		return null

	
	
	
	
	if lamp_lights != null and not lamp_group.lights.is_empty():
		lamp_lights.register_tile(root, lamp_group)

	return root


func _box_group_key(def: Dictionary) -> String:
	var size: Vector3 = def["size"]
	var color: Color = def["color"]
	return "%s|%s" % [size, color]





func _node_block_count(tags: Dictionary) -> int:
	if not tags.has("capacity"):
		return 1
	var raw: String = str(tags["capacity"]).strip_edges()
	if not raw.is_valid_int():
		return 1
	return clampi(raw.to_int(), 1, 16)


func _build_box_multimesh(def: Dictionary, transforms: Array) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null

	var box := BoxMesh.new()
	box.size = def["size"]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = def["color"]
	box.material = mat

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "%s_x%d" % [def["label"].replace(" ", ""), transforms.size()]
	mmi.multimesh = multimesh
	return mmi







const _LAMP_LIGHT_COLOR := Color(1.0, 0.85, 0.55)




const _LAMP_COLOUR_BY_NAME := {
	"white": Color(1.0, 0.97, 0.9),
	"warm_white": Color(1.0, 0.9, 0.72),
	"yellow": Color(1.0, 0.85, 0.45),
	"orange": Color(1.0, 0.6, 0.25),
}




const _LAMP_COLOUR_BY_TYPE := {
	"led": Color(1.0, 0.97, 0.9),
	"fluorescent": Color(1.0, 0.97, 0.9),
	"metal_halide": Color(0.92, 0.95, 1.0),
	"mercury": Color(0.9, 0.95, 1.0),
	"high_pressure_sodium": Color(1.0, 0.6, 0.25),
	"sodium": Color(1.0, 0.55, 0.15),
	"incandescent": Color(1.0, 0.88, 0.68),
	"gaslight": Color(1.0, 0.82, 0.55),
}



const _LAMP_LIGHT_ENERGY := 3.0


const _LAMP_LIGHT_RANGE := 12.0


const _LAMP_GLOW_ENERGY := 6.0






const _LAMP_HEAD_MESH_NAME := "light"




const _LAMP_COUNT_MAX := 8




const _LAMP_BULB_SPACING := 0.45


const _LAMP_BULB_SIZE := 0.3












func _build_street_lamp(def: Dictionary, node: OSMParser.OSMNode, group: StreetLampLights.LampGroup) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%d" % [def["label"].replace(" ", ""), node.id]
	root.position = node.local_pos

	group.light_energy = _LAMP_LIGHT_ENERGY
	group.glow_energy = _LAMP_GLOW_ENERGY
	group.color = _resolve_lamp_color(node.tags)
	var count := _resolve_lamp_count(node.tags)
	var height := _resolve_lamp_height(node.tags, def)

	if def.has("scene"):
		
		
		
		_build_scene_lamp_body(def, root, group, count)
	else:
		_build_placeholder_lamp_body(def, root, group, count, height)

	return root







func _resolve_lamp_color(tags: Dictionary) -> Color:
	if tags.has("light:colour"):
		var raw: String = str(tags["light:colour"]).strip_edges().to_lower()
		if _LAMP_COLOUR_BY_NAME.has(raw):
			return _LAMP_COLOUR_BY_NAME[raw]
		
		if raw.begins_with("#") and raw.is_valid_html_color():
			return Color.html(raw)

	for type_key: String in ["lamp_type", "light:method"]:
		if tags.has(type_key):
			var type_value: String = str(tags[type_key]).strip_edges().to_lower()
			if _LAMP_COLOUR_BY_TYPE.has(type_value):
				return _LAMP_COLOUR_BY_TYPE[type_value]

	return _LAMP_LIGHT_COLOR






func _resolve_lamp_count(tags: Dictionary) -> int:
	if not tags.has("light:count"):
		return 1
	var raw: String = str(tags["light:count"]).strip_edges()
	if not raw.is_valid_int():
		return 1
	return clampi(raw.to_int(), 1, _LAMP_COUNT_MAX)







func _build_scene_lamp_body(def: Dictionary, root: Node3D, group: StreetLampLights.LampGroup, count: int = 1) -> void:
	var scene := _load_scene(def["scene"])
	if scene == null:
		_build_placeholder_lamp_body(def, root, group, count)
		return
	var model := scene.instantiate()
	root.add_child(model)

	var head := _find_node_by_name(model, _LAMP_HEAD_MESH_NAME) as MeshInstance3D
	if head == null:
		push_warning("OSMAssetPlacer: street-lamp model %s has no '%s' mesh; using placeholder light" % [def["scene"], _LAMP_HEAD_MESH_NAME])
		_build_placeholder_lamp_body(def, root, group, count)
		return

	
	
	
	var head_mat := head.get_active_material(0)
	if head_mat is StandardMaterial3D:
		var unique := (head_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		unique.emission = group.color
		unique.emission_enabled = false
		unique.emission_energy_multiplier = 0.0
		head.set_surface_override_material(0, unique)
		group.materials.append(unique)

	
	
	
	var head_center := _node_aabb_center_in(head, root)
	_add_lamp_light(root, group, head_center)










func _build_placeholder_lamp_body(def: Dictionary, root: Node3D, group: StreetLampLights.LampGroup, count: int = 1, height: float = -1.0) -> void:
	var size: Vector3 = def["size"]
	
	
	
	var pole_height := height if height > 0.0 else size.y
	var y_offset := pole_height * 0.5

	
	
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(size.x, pole_height, size.z)
	pole.mesh = pole_mesh
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = def["color"]
	pole.material_override = pole_mat
	pole.position.y = y_offset
	root.add_child(pole)

	
	
	
	var head_y := y_offset + pole_height * 0.5
	var radius := 0.0
	if count > 1:
		radius = maxf(_LAMP_BULB_SIZE, _LAMP_BULB_SPACING / sin(PI / count))

	for i: int in range(count):
		var offset := Vector3.ZERO
		if count > 1:
			var angle := TAU * float(i) / float(count)
			offset = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_add_placeholder_bulb(root, group, head_y, offset, i)






func _add_placeholder_bulb(root: Node3D, group: StreetLampLights.LampGroup, head_y: float, offset: Vector3, index: int) -> void:
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb%d" % index
	var bulb_mesh := BoxMesh.new()
	bulb_mesh.size = Vector3(_LAMP_BULB_SIZE, 0.18, _LAMP_BULB_SIZE)
	bulb.mesh = bulb_mesh
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = group.color
	bulb_mat.emission = group.color
	bulb_mat.emission_enabled = false
	bulb_mat.emission_energy_multiplier = 0.0
	bulb.material_override = bulb_mat
	bulb.position = Vector3(offset.x, head_y, offset.z)
	root.add_child(bulb)
	group.materials.append(bulb_mat)

	_add_lamp_light(root, group, Vector3(offset.x, head_y - 0.2, offset.z))






func _add_lamp_light(root: Node3D, group: StreetLampLights.LampGroup, local_pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = group.color
	light.light_energy = 0.0
	light.omni_range = _LAMP_LIGHT_RANGE
	light.shadow_enabled = false
	light.visible = false
	light.position = local_pos
	root.add_child(light)
	group.lights.append(light)






func _find_node_by_name(node: Node, target: String) -> Node:
	if node.name.to_lower().begins_with(target.to_lower()):
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target)
		if found != null:
			return found
	return null










func _node_aabb_center_in(mesh: MeshInstance3D, relative_to: Node3D) -> Vector3:
	var center := mesh.get_aabb().get_center()
	var xform := Transform3D.IDENTITY
	var n: Node = mesh
	while n != null and n != relative_to:
		if n is Node3D:
			xform = (n as Node3D).transform * xform
		n = n.get_parent()
	return xform * center


func place_asset(node: OSMParser.OSMNode) -> Node3D:
	var def := _find_asset_def(node.tags)
	if def.is_empty():
		return null

	var root := Node3D.new()
	root.name = "%s_%d" % [def["label"].replace(" ", ""), node.id]
	root.position = node.local_pos

	
	if def.has("scene"):
		var scene_path: String = def["scene"]
		var scene := _load_scene(scene_path)
		if scene != null:
			var instance := scene.instantiate()
			root.add_child(instance)
			_add_debug_label(root, def, node.tags)
			return root

	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	var box := BoxMesh.new()
	var size: Vector3 = def["size"]
	box.size = size
	mesh_instance.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = def["color"]
	mesh_instance.material_override = mat
	mesh_instance.position.y = def["y_offset"]

	root.add_child(mesh_instance)
	_add_debug_label(root, def, node.tags)

	return root

func place_way_asset(way: OSMParser.OSMWay, osm_data: OSMParser.OSMData) -> Node3D:
	var def := _find_asset_def(way.tags)
	if def.is_empty():
		return null

	var points := PolygonUtils.way_to_points(way.node_ids, osm_data.nodes)
	if points.size() < 2:
		return null

	var root := Node3D.new()
	root.name = "%s_%d" % [def["label"].replace(" ", ""), way.id]

	var color: Color = def["color"]
	var height: float = def["size"].y
	var width: float = def["size"].x

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	
	
	
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)

	var half_w := width / 2.0

	for i: int in range(points.size() - 1):
		var p0 := points[i]
		var p1 := points[i + 1]
		var forward := (p1 - p0).normalized()
		var right := Vector3(-forward.z, 0.0, forward.x).normalized() * half_w

		
		
		var bl0 := Vector3(p0.x - right.x, p0.y, p0.z - right.z)
		var br0 := Vector3(p0.x + right.x, p0.y, p0.z + right.z)
		var bl1 := Vector3(p1.x - right.x, p1.y, p1.z - right.z)
		var br1 := Vector3(p1.x + right.x, p1.y, p1.z + right.z)

		
		var tl0 := Vector3(bl0.x, p0.y + height, bl0.z)
		var tr0 := Vector3(br0.x, p0.y + height, br0.z)
		var tl1 := Vector3(bl1.x, p1.y + height, bl1.z)
		var tr1 := Vector3(br1.x, p1.y + height, br1.z)

		
		
		
		
		var left_normal := -right.normalized()
		var right_normal := right.normalized()

		
		PolygonUtils.add_quad_facing(st, tl0, tr0, tr1, tl1, Vector3.UP)
		
		PolygonUtils.add_quad_facing(st, bl0, tl0, tl1, bl1, left_normal)
		
		PolygonUtils.add_quad_facing(st, br0, tr0, tr1, br1, right_normal)

		
		if i == 0:
			PolygonUtils.add_quad_facing(st, bl0, br0, tr0, tl0, -forward)

		
		if i == points.size() - 2:
			PolygonUtils.add_quad_facing(st, bl1, br1, tr1, tl1, forward)

	mesh_instance.mesh = st.commit()
	root.add_child(mesh_instance)

	
	@warning_ignore("integer_division")
	var mid_index := points.size() / 2
	var mid_point := points[mid_index]
	_add_debug_label_at(root, def, way.tags, mid_point)

	return root

func _add_debug_label(parent: Node3D, def: Dictionary, tags: Dictionary) -> void:
	_add_debug_label_at(parent, def, tags, Vector3.ZERO)

func _add_debug_label_at(parent: Node3D, def: Dictionary, tags: Dictionary, pos: Vector3) -> void:
	var label := Label3D.new()
	label.name = "DebugLabel"
	var text: String = def["label"]
	if tags.has("name"):
		text += " - " + tags["name"]
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	
	label.no_depth_test = false
	label.modulate = Color(1.0, 1.0, 1.0, 0.9)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	label.outline_size = 8
	
	
	
	var label_y: float = pos.y + def["y_offset"] * 2.0 + 1.0
	label.position = Vector3(pos.x, label_y, pos.z)
	label.visible = show_debug_labels
	parent.add_child(label)
	label.add_to_group("debug_labels")

func _load_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		_scene_cache[path] = scene
		return scene
	push_warning("OSMAssetPlacer: Scene not found: %s, using placeholder" % path)
	return null




const _LAMP_DEFAULT_HEIGHT := 4.0





func _resolve_lamp_height(tags: Dictionary, def: Dictionary) -> float:
	if tags.has("height"):
		var h := _parse_height(str(tags["height"]))
		if h > 0.0:
			return clampf(h, 1.0, 30.0)
	return def["size"].y







func _parse_height(value: String) -> float:
	var s := value.strip_edges()
	if s.is_empty():
		return 0.0
	
	if s.ends_with("'") or s.ends_with("ft"):
		var num_str := s.replace("ft", "").replace("'", "").strip_edges()
		var ft := num_str.to_float()
		return ft * 0.3048
	
	if s.ends_with("m"):
		var num_str := s.left(s.length() - 1).strip_edges()
		return num_str.to_float()
	
	return s.to_float()


func _find_asset_def(tags: Dictionary) -> Dictionary:
	for tag_key: String in ASSET_DEFS:
		if tags.has(tag_key):
			var tag_value: String = tags[tag_key]
			var sub: Dictionary = ASSET_DEFS[tag_key]
			
			
			
			if tag_key == "barrier" and tag_value == "wall" and tags.has("wall"):
				var wall_value: String = tags["wall"]
				if sub.has(wall_value):
					return sub[wall_value]
			var base: Dictionary = {}
			if sub.has(tag_value):
				base = sub[tag_value]
			elif sub.has("*"):
				base = sub["*"]
			if not base.is_empty():
				return _apply_support_variant(base, tags)
	return {}









func _apply_support_variant(base: Dictionary, tags: Dictionary) -> Dictionary:
	if not base.has("support") or not tags.has("support"):
		return base
	var variants: Dictionary = base["support"]
	var support_value: String = tags["support"]
	if not variants.has(support_value):
		
		var fallback := base.duplicate()
		fallback.erase("support")
		return fallback
	var merged := base.duplicate()
	merged.erase("support")
	for key: String in variants[support_value]:
		merged[key] = variants[support_value][key]
	return merged
