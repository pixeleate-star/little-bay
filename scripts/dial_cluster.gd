class_name DialCluster
extends Control
















const InterfaceTheme := preload("res://scripts/interface_theme.gd")



signal redline_changed(redlining: bool)


@export var dial_radius_ratio: float = 0.46

@export var arc_width_ratio: float = 0.07


@export var max_rpm: float = 7500.0

@export var redline_rpm: float = 6500.0


@export var face_color: Color = Color(0.055, 0.06, 0.055, 0.97)
@export var rim_color: Color = Color("415d99")
@export var arc_track_color: Color = Color("2d272f")
@export var arc_fill_color: Color = Color("009b88")
@export var redline_color: Color = Color("8f5676")
@export var needle_color: Color = Color("6ea16e")
@export var text_color: Color = Color("6ea16e")
@export var muted_text_color: Color = Color("9d696a")



var _tacho := TachometerModel.new()


var _speed_kmh: float = 0.0
var _gear: int = Transmission.GEAR_NEUTRAL
var _gear_ratio: float = 0.0



var _tcs_level: float = 0.0
var _abs_level: float = 0.0
var _stability_level: float = 0.0


var _was_redlining: bool = false



const _TICK_COUNT := 8

const _TICK_LENGTH_RATIO := 0.12

const _NEEDLE_TAIL_RATIO := 0.12

const _HUB_RATIO := 0.30


const _ARC_SEGMENTS := 64


func _ready() -> void:
	
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tacho.max_rpm = max_rpm
	_tacho.redline_rpm = redline_rpm


func _process(delta: float) -> void:
	
	
	
	
	
	
	var tach_gear := _gear
	if _gear == Transmission.GEAR_NEUTRAL and _gear_ratio > 0.01:
		tach_gear = 1
	_tacho.update(tach_gear, _gear_ratio, _speed_kmh, delta)

	var redlining := _tacho.is_redlining()
	if redlining != _was_redlining:
		_was_redlining = redlining
		redline_changed.emit(redlining)

	
	
	_tcs_level = maxf(0.0, _tcs_level - delta * _TELLTALE_FADE)
	_abs_level = maxf(0.0, _abs_level - delta * _TELLTALE_FADE)
	_stability_level = maxf(0.0, _stability_level - delta * _TELLTALE_FADE)

	queue_redraw()



const _TELLTALE_FADE := 3.0



func set_speed(speed_kmh: float) -> void:
	_speed_kmh = absf(speed_kmh)



func set_gear(gear: int) -> void:
	_gear = gear




func set_gear_ratio(ratio: float) -> void:
	_gear_ratio = ratio




func set_assist_levels(tcs: float, abs_level: float, stability: float) -> void:
	_tcs_level = maxf(_tcs_level, clampf(tcs, 0.0, 1.0))
	_abs_level = maxf(_abs_level, clampf(abs_level, 0.0, 1.0))
	_stability_level = maxf(_stability_level, clampf(stability, 0.0, 1.0))



func get_tachometer() -> TachometerModel:
	return _tacho


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * dial_radius_ratio
	if radius <= 0.0:
		return

	_draw_face(centre, radius)
	_draw_rev_arc(centre, radius)
	_draw_ticks(centre, radius)
	_draw_needle(centre, radius)
	_draw_hub_and_gear(centre, radius)
	_draw_speed(centre, radius)
	_draw_telltales(centre, radius)




func _draw_face(centre: Vector2, radius: float) -> void:
	draw_circle(centre + Vector2(0, 4), radius + 3, Color(0, 0, 0, 0.18))
	draw_circle(centre, radius, face_color)
	var intensity := _tacho.redline_intensity()
	var rim := rim_color.lerp(redline_color, intensity)
	var width := maxf(1.0, radius * 0.01) * (1.0 + intensity)
	draw_arc(centre, radius, 0.0, TAU, _ARC_SEGMENTS, rim, width, true)
	draw_arc(centre, radius * 0.83, 0.0, TAU, _ARC_SEGMENTS, Color(0.32, 0.38, 0.39, 0.25), 1, true)




func _draw_rev_arc(centre: Vector2, radius: float) -> void:
	var arc_radius := radius * (1.0 - arc_width_ratio * 0.5)
	var width := radius * arc_width_ratio
	var start := _tacho.dial_start
	var sweep := _tacho.dial_sweep

	
	
	_draw_dial_arc(centre, arc_radius, start, start + sweep, arc_track_color, width)

	
	var redline_start := _tacho.angle_for_fraction(_tacho.redline_fraction())
	_draw_dial_arc(
		centre, arc_radius, redline_start, start + sweep,
		Color(redline_color.r, redline_color.g, redline_color.b, 0.35), width
	)

	
	var fraction := _tacho.needle_fraction()
	if fraction <= 0.0:
		return
	var fill := arc_fill_color.lerp(redline_color, _tacho.redline_intensity())
	_draw_dial_arc(
		centre, arc_radius, start, _tacho.angle_for_fraction(fraction), fill, width
	)




func _draw_ticks(centre: Vector2, radius: float) -> void:
	var inner := radius * (1.0 - arc_width_ratio - _TICK_LENGTH_RATIO)
	var outer := radius * (1.0 - arc_width_ratio)
	for i in range(_TICK_COUNT + 1):
		var fraction := float(i) / float(_TICK_COUNT)
		var angle := _tacho.angle_for_fraction(fraction)
		var dir := _dial_direction(angle)
		
		var tint := redline_color if fraction >= _tacho.redline_fraction() else muted_text_color
		draw_line(centre + dir * inner, centre + dir * outer, tint, maxf(1.0, radius * 0.018), true)
	for i in range(_TICK_COUNT * 4 + 1):
		if i % 4 == 0:
			continue
		var angle := _tacho.angle_for_fraction(float(i) / float(_TICK_COUNT * 4))
		var dir := _dial_direction(angle)
		draw_line(centre + dir * radius * 0.87, centre + dir * outer, rim_color, 1, true)



func _draw_needle(centre: Vector2, radius: float) -> void:
	var angle := _tacho.needle_angle()
	var dir := _dial_direction(angle)
	
	var side := Vector2(-dir.y, dir.x)
	var tip := centre + dir * (radius * (1.0 - arc_width_ratio - 0.04))
	var base := centre - dir * (radius * _NEEDLE_TAIL_RATIO)
	var half_width := maxf(1.5, radius * 0.035)
	
	var points := PackedVector2Array([
		tip,
		base + side * half_width,
		base - side * half_width,
	])
	draw_colored_polygon(points, needle_color)




func _draw_hub_and_gear(centre: Vector2, radius: float) -> void:
	var hub_radius := radius * _HUB_RATIO
	draw_circle(centre, hub_radius, Color(0.02, 0.03, 0.05, 0.92))
	var intensity := _tacho.redline_intensity()
	draw_arc(
		centre, hub_radius, 0.0, TAU, 32,
		rim_color.lerp(redline_color, intensity), maxf(1.5, radius * 0.02), true
	)

	var font := InterfaceTheme.DISPLAY
	var gear_size := int(maxf(12.0, hub_radius * 1.15))
	var label := Transmission.gear_label(_gear)
	var colour := text_color.lerp(redline_color, intensity)
	_draw_centred_text(font, label, gear_size, centre, colour)




func _draw_speed(centre: Vector2, radius: float) -> void:
	var font := InterfaceTheme.DISPLAY
	var speed_size := int(maxf(14.0, radius * 0.40))
	var speed_pos := centre + Vector2(0.0, radius * 0.52)
	_draw_centred_text(font, "%d" % int(round(_speed_kmh)), speed_size, speed_pos, text_color)

	var unit_size := int(maxf(9.0, radius * 0.13))
	var unit_pos := speed_pos + Vector2(0.0, radius * 0.24)
	_draw_centred_text(InterfaceTheme.BODY, "KM/H", unit_size, unit_pos, muted_text_color)





func _draw_telltales(centre: Vector2, radius: float) -> void:
	var font := InterfaceTheme.BODY
	var lamp_size := int(maxf(8.0, radius * 0.13))
	var y := centre.y - radius * 0.42
	var spacing := radius * 0.42
	var lamps := [
		["TC", _tcs_level, Color(1.0, 0.82, 0.2)],
		["ABS", _abs_level, Color(1.0, 0.65, 0.15)],
		["ESC", _stability_level, Color(0.4, 1.0, 0.6)],
	]
	for i in range(lamps.size()):
		var entry: Array = lamps[i]
		var level: float = entry[1]
		
		var lit: Color = entry[2]
		var colour := muted_text_color.lerp(lit, level)
		var x := centre.x + (float(i) - 1.0) * spacing
		_draw_centred_text(font, entry[0], lamp_size, Vector2(x, y), colour)




func _draw_centred_text(
	font: Font, text: String, font_size: int, at: Vector2, colour: Color
) -> void:
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	
	
	var pos := at - Vector2(measured.x * 0.5, -font_size * 0.35)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, colour)




func _draw_dial_arc(
	centre: Vector2, radius: float, from: float, to: float, colour: Color, width: float
) -> void:
	if to <= from:
		return
	
	
	var offset := PI * 0.5
	draw_arc(centre, radius, from + offset, to + offset, _ARC_SEGMENTS, colour, width, true)














static func _dial_direction(angle: float) -> Vector2:
	return Vector2(-sin(angle), cos(angle))
