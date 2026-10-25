extends Control

## Ace Rider front door: a custom editorial garage-style interface built in code.

const InterfaceTheme := preload("res://scripts/interface_theme.gd")
const SceneFlowScript := preload("res://scripts/scene_flow.gd")
const RunSessionScript := preload("res://scripts/run_session.gd")

func _ready() -> void:
	theme = InterfaceTheme.create()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()

func _start_drive() -> void:
	SceneFlowScript.start_drive(get_tree(), RunSessionScript.Mode.FREE_DRIVE)

func _quit() -> void:
	get_tree().quit()

func _label(text: String, size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", InterfaceTheme.DISPLAY)
	return label

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("2d272f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var top_line := ColorRect.new()
	top_line.color = Color("009b88")
	top_line.position = Vector2(58, 44)
	top_line.size = Vector2(290, 5)
	add_child(top_line)

	var eyebrow := _label("GARAGE SESSION  /  01", 13, Color("009b88"), true)
	eyebrow.position = Vector2(62, 72)
	add_child(eyebrow)

	var title := _label("LITTLE RIDER", 76, Color("6ea16e"), true)
	title.position = Vector2(58, 112)
	add_child(title)

	var subtitle := _label("DELIVERIES IN A BIG CITY", 18, Color("9d696a"), true)
	subtitle.position = Vector2(64, 208)
	add_child(subtitle)

	var description := _label("You are just a little guy.\nFive packages. One big city.", 17, Color("d8d2c6"))
	description.position = Vector2(64, 252)
	add_child(description)

	var stat_panel := PanelContainer.new()
	stat_panel.position = Vector2(64, 340)
	stat_panel.size = Vector2(420, 108)
	stat_panel.add_theme_stylebox_override("panel", _box(Color("191d1c"), Color("38403b"), 8))
	add_child(stat_panel)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 28)
	stat_panel.add_child(stats)
	stats.add_child(_label("FREE DRIVE", 16, Color("f3efe5"), true))
	stats.add_child(_label("CITY TRAFFIC", 16, Color("009b88"), true))

	var right_panel := Panel.new()
	right_panel.position = Vector2(690, 0)
	right_panel.size = Vector2(590, 720)
	right_panel.add_theme_stylebox_override("panel", _box(Color("171a1a"), Color("252b29"), 0))
	add_child(right_panel)
	var number := _label("01", 240, Color("252b29"), true)
	number.position = Vector2(790, 82)
	add_child(number)
	for y in [138, 204, 270, 336, 402, 468, 534]:
		var stripe := ColorRect.new()
		stripe.color = Color("28302d")
		stripe.position = Vector2(750, y)
		stripe.size = Vector2(440, 2)
		add_child(stripe)
	var right_caption := _label("NIGHT DISTRICT\nOPEN ROAD / NO TIMER", 19, Color("f3efe5"), true)
	right_caption.position = Vector2(760, 570)
	add_child(right_caption)

	var enter := Button.new()
	enter.text = "START DRIVING"
	enter.position = Vector2(64, 492)
	enter.size = Vector2(300, 58)
	enter.add_theme_font_size_override("font_size", 20)
	enter.add_theme_stylebox_override("normal", _box(Color("009b88"), Color("009b88"), 6))
	enter.add_theme_stylebox_override("hover", _box(Color("6ea16e"), Color("6ea16e"), 6))
	enter.add_theme_color_override("font_color", Color("151716"))
	enter.add_theme_color_override("font_hover_color", Color("151716"))
	enter.pressed.connect(_start_drive)
	add_child(enter)
	enter.grab_focus.call_deferred()

	var exit := Button.new()
	exit.text = "Exit"
	exit.position = Vector2(64, 566)
	exit.size = Vector2(120, 36)
	exit.add_theme_font_size_override("font_size", 13)
	exit.pressed.connect(_quit)
	add_child(exit)

	var controls := _label("WASD DRIVE   /   SPACE HANDBRAKE   /   R RECOVER   /   T CAMERA", 11, Color("68716b"), true)
	controls.position = Vector2(64, 676)
	add_child(controls)


func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

