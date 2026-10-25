class_name QuestArrow
extends Node3D





@export var delivery_manager_path: NodePath

const ARROW_HEIGHT := 3.6
const ARROW_LENGTH := 1.35
const ARROW_COLOR := Color("6ea16e")

var _delivery: Node = null
var _target: Vector3 = Vector3.ZERO
var _has_target := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_delivery = get_node_or_null(delivery_manager_path)
	_build_visual()
	visible = false

func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = ARROW_COLOR
	material.emission_enabled = true
	material.emission = ARROW_COLOR
	material.emission_energy_multiplier = 1.8
	material.roughness = 0.35

	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.12, 0.12, ARROW_LENGTH)
	shaft.mesh = shaft_mesh
	shaft.position.z = -ARROW_LENGTH * 0.5
	shaft.material_override = material
	add_child(shaft)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.27
	head_mesh.height = 0.48
	head_mesh.radial_segments = 16
	head.mesh = head_mesh
	
	head.rotation.x = -PI * 0.5
	head.position.z = -ARROW_LENGTH - 0.24
	head.material_override = material
	add_child(head)

func _process(_delta: float) -> void:
	if _delivery == null or not _delivery.has_method("active_target"):
		visible = false
		return
	var candidate: Variant = _delivery.call("active_target")
	if candidate == null or not candidate is Vector3:
		visible = false
		return
	_target = candidate as Vector3
	var offset := _target - global_position
	offset.y = 0.0
	_has_target = offset.length_squared() > 4.0
	visible = _has_target and not bool(_delivery.call("is_complete"))
	if not visible:
		return
	position.y = ARROW_HEIGHT
	
	look_at(global_position + offset, Vector3.UP)

