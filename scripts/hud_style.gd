extends CanvasLayer





const InterfaceTheme := preload("res://scripts/interface_theme.gd")

var speed_value: Label
var gear_value: Label
var traffic_value: Label
var state_value: Label
var car: Node3D

func _ready() -> void:
	for node in get_children():
		if node is Control and node.name not in ["DialCluster", "Minimap"]:
			node.visible = false
	car = get_node_or_null("../Car") as Node3D
	_build_dashboard()

func _process(_delta: float) -> void:
	if car == null:
		return
	var rigid_car := car as RigidBody3D
	if rigid_car == null:
		return
	speed_value.text = "%03d" % int(round(rigid_car.linear_velocity.length() * 3.6))
	var traffic := get_node_or_null("../TrafficManager")
	traffic_value.text = "%02d CARS" % (int(traffic.call("car_count")) if traffic != null else 0)

func _panel(fill: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _label(text: String, size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", InterfaceTheme.DISPLAY)
	return label

func _build_dashboard() -> void:
	var root := Control.new()
	root.name = "AceDashboard"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_rule := ColorRect.new()
	top_rule.color = InterfaceTheme.ACCENT
	top_rule.position = Vector2(28, 24)
	top_rule.size = Vector2(220, 3)
	root.add_child(top_rule)
	top_rule.visible = false

	var brand := _label("LITTLE RIDER", 28, InterfaceTheme.PAPER, true)
	brand.position = Vector2(44, 40)
	root.add_child(brand)
	brand.visible = false
	var district := _label("NIGHT DISTRICT  //  FREE DRIVE", 11, InterfaceTheme.ACCENT, true)
	district.position = Vector2(46, 76)
	root.add_child(district)
	district.visible = false

	var drive_panel := PanelContainer.new()
	drive_panel.name = "DriveInfoCard"
	drive_panel.position = Vector2(28, 28)
	drive_panel.size = Vector2(330, 190)
	drive_panel.add_theme_stylebox_override("panel", _panel(Color("2d272f"), Color("009b88"), 10))
	root.add_child(drive_panel)
	var drive_column := VBoxContainer.new()
	drive_column.add_theme_constant_override("separation", 4)
	drive_panel.add_child(drive_column)
	drive_column.add_child(_label("LITTLE RIDER", 28, InterfaceTheme.PAPER, true))
	traffic_value = _label("00 CARS", 13, InterfaceTheme.ACCENT, true)
	drive_column.add_child(traffic_value)
	drive_column.add_child(_label("DRIVE CONTROLS", 12, InterfaceTheme.ACCENT, true))
	drive_column.add_child(_label("WASD  -  DRIVE     SPACE  -  HANDBRAKE", 11, InterfaceTheme.PAPER, true))
	drive_column.add_child(_label("R  -  RESET / RECOVER     T  -  CAMERA", 11, InterfaceTheme.PAPER, true))
	drive_column.add_child(_label("M  -  MAP     ESC  -  PAUSE", 11, InterfaceTheme.PAPER, true))

	var little_guy := PanelContainer.new()
	little_guy.name = "LittleGuyBadge"
	little_guy.position = Vector2(270, 44)
	little_guy.size = Vector2(72, 66)
	little_guy.add_theme_stylebox_override("panel", _panel(Color("415d99"), Color("009b88"), 8))
	root.add_child(little_guy)
	var guy_column := VBoxContainer.new()
	guy_column.alignment = BoxContainer.ALIGNMENT_CENTER
	little_guy.add_child(guy_column)
	var silhouette := _label("●\n│", 20, InterfaceTheme.PAPER, true)
	silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guy_column.add_child(silhouette)
	var guy_caption := _label("LITTLE\nGUY", 8, InterfaceTheme.PAPER, true)
	guy_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guy_column.add_child(guy_caption)

	var speed_panel := PanelContainer.new()
	speed_panel.position = Vector2(34, 570)
	speed_panel.size = Vector2(340, 112)
	speed_panel.add_theme_stylebox_override("panel", _panel(Color("2d272f"), Color("415d99")))
	root.add_child(speed_panel)
	
	
	
	speed_panel.visible = false
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 12)
	speed_panel.add_child(speed_row)
	speed_value = _label("000", 58, InterfaceTheme.PAPER, true)
	speed_value.custom_minimum_size = Vector2(150, 0)
	speed_row.add_child(speed_value)
	var unit_stack := VBoxContainer.new()
	unit_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_child(unit_stack)
	unit_stack.add_child(_label("KM/H", 14, InterfaceTheme.ACCENT, true))
	gear_value = _label("D", 30, InterfaceTheme.PAPER, true)
	unit_stack.add_child(gear_value)

	var bottom_right := _label("R  RECOVER    T  CAMERA    ESC  PAUSE", 11, InterfaceTheme.MUTED, true)
	bottom_right.position = Vector2(920, 680)
	root.add_child(bottom_right)
	bottom_right.visible = false

