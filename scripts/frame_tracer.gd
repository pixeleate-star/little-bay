class_name FrameTracer
extends RefCounted


































const _DEFAULT_THRESHOLD_MS := 4.0

static var _enabled: bool = false
static var _threshold_us: int = int(_DEFAULT_THRESHOLD_MS * 1000.0)
static var _configured: bool = false



static var _open: Dictionary = {}




static var _stats: Dictionary = {}
static var _stats_mutex := Mutex.new()




static func _ensure_configured() -> void:
	if _configured:
		return
	_configured = true
	if OS.has_environment("OSMRACER_TRACE"):
		var v := OS.get_environment("OSMRACER_TRACE").strip_edges()
		_enabled = v != "" and v != "0" and v.to_lower() != "false"
	if OS.has_environment("OSMRACER_TRACE_MS"):
		var ms := OS.get_environment("OSMRACER_TRACE_MS").to_float()
		if ms > 0.0:
			_threshold_us = int(ms * 1000.0)



static func set_enabled(on: bool) -> void:
	_ensure_configured()
	_enabled = on


static func is_enabled() -> bool:
	_ensure_configured()
	return _enabled



static func set_threshold_ms(ms: float) -> void:
	_threshold_us = int(maxf(0.0, ms) * 1000.0)




static func begin(label: String) -> void:
	if not is_enabled():
		return
	_open[label] = Time.get_ticks_usec()





static func end(label: String) -> int:
	if not is_enabled() or not _open.has(label):
		return 0
	var elapsed: int = Time.get_ticks_usec() - int(_open[label])
	_open.erase(label)
	_accumulate(label, elapsed)
	if elapsed >= _threshold_us:
		print("[trace] %s took %.2f ms" % [label, elapsed / 1000.0])
	return elapsed





static func scope(label: String) -> Span:
	return Span.new(label)





static func record_usec(label: String, elapsed_us: int) -> void:
	if not is_enabled():
		return
	_accumulate(label, elapsed_us)
	if elapsed_us >= _threshold_us:
		print("[trace] %s took %.2f ms" % [label, elapsed_us / 1000.0])


static func _accumulate(label: String, elapsed_us: int) -> void:
	
	
	
	_stats_mutex.lock()
	var s: Dictionary = _stats.get(label, {"count": 0, "total_us": 0, "max_us": 0})
	s["count"] = int(s["count"]) + 1
	s["total_us"] = int(s["total_us"]) + elapsed_us
	s["max_us"] = maxi(int(s["max_us"]), elapsed_us)
	_stats[label] = s
	_stats_mutex.unlock()





static func dump_summary() -> void:
	if not is_enabled():
		return
	_stats_mutex.lock()
	var snapshot := _stats.duplicate(true)
	_stats.clear()
	_stats_mutex.unlock()
	if snapshot.is_empty():
		return
	print("[trace] ── summary ──────────────────────────────")
	var labels := snapshot.keys()
	labels.sort()
	for label: String in labels:
		var s: Dictionary = snapshot[label]
		var count := int(s["count"])
		var total := int(s["total_us"])
		var avg := float(total) / maxi(1, count)
		print("[trace]   %-28s n=%-5d total=%8.2f ms  avg=%6.2f ms  max=%6.2f ms" % [
			label, count, total / 1000.0, avg / 1000.0, int(s["max_us"]) / 1000.0])
	print("[trace] ─────────────────────────────────────────")





class Span extends RefCounted:
	var _label: String = ""
	var _active: bool = false

	func _init(label: String) -> void:
		
		
		
		if _Tracer.is_enabled():
			_label = label
			_active = true
			_Tracer.begin(label)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _active:
			_Tracer.end(_label)
			_active = false

	
	func close() -> void:
		if _active:
			_Tracer.end(_label)
			_active = false

const _Tracer := preload("res://scripts/frame_tracer.gd")
