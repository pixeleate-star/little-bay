extends Control





var _raining: bool = false
var _time: float = 0.0
var _drops: Array[Vector2] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in range(150):
		_drops.append(Vector2(float((i * 83) % 1400), float((i * 137) % 900)))

func set_raining(enabled: bool) -> void:
	_raining = enabled
	visible = enabled
	queue_redraw()

func _process(delta: float) -> void:
	if not _raining:
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	if not _raining:
		return
	for i: int in _drops.size():
		var seed := _drops[i]
		var fall_speed := 205.0 + float(i % 8) * 18.0
		var x := fposmod(seed.x + _time * (38.0 + float(i % 5) * 7.0), size.x + 100.0) - 50.0
		var y := fposmod(seed.y + _time * fall_speed, size.y + 80.0) - 40.0
		var length := 12.0 + float(i % 6) * 2.0
		draw_line(Vector2(x, y), Vector2(x - 5.0, y + length), Color(0.78, 0.84, 0.88, 0.30), 1.1, true)
