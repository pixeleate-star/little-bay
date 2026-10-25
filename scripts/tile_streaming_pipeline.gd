class_name TileStreamingPipeline
extends RefCounted










































var _pending_tiles: Dictionary = {}
var _parse_tasks: Dictionary = {}
var _ready_buckets: Dictionary = {}
var _instance_queue: Array[Vector2i] = []











var _feature_queue: Array = []

var use_threads: bool = true


var instance_budget_ms: float = 4.0


var _parse_cb: Callable
var _instance_cb: Callable
var _build_feature_cb: Callable
var _is_loaded_cb: Callable
var _in_range_cb: Callable
var _record_usec_cb: Callable





func configure(
		parse_cb: Callable, instance_cb: Callable, build_feature_cb: Callable,
		is_loaded_cb: Callable, in_range_cb: Callable,
		record_usec_cb: Callable = Callable()) -> void:
	_parse_cb = parse_cb
	_instance_cb = instance_cb
	_build_feature_cb = build_feature_cb
	_is_loaded_cb = is_loaded_cb
	_in_range_cb = in_range_cb
	_record_usec_cb = record_usec_cb






func request_tile(tkey: Vector2i) -> void:
	if _is_loaded_cb.call(tkey) or _pending_tiles.has(tkey) or _ready_buckets.has(tkey):
		return
	_pending_tiles[tkey] = true
	if use_threads:
		var task_id := WorkerThreadPool.add_task(_parse_tile_task.bind(tkey))
		_parse_tasks[tkey] = task_id
	else:
		
		_ready_buckets[tkey] = _parse_cb.call(tkey)
		_instance_queue.append(tkey)





func _parse_tile_task(tkey: Vector2i) -> void:
	
	
	
	var t0 := Time.get_ticks_usec()
	var bucket: Variant = _parse_cb.call(tkey)
	if _record_usec_cb.is_valid():
		_record_usec_cb.call("parse_tile_task", Time.get_ticks_usec() - t0)
	
	
	
	_ready_buckets[tkey] = bucket





func collect_finished_parses() -> void:
	if _parse_tasks.is_empty():
		return
	var done: Array[Vector2i] = []
	for tkey: Vector2i in _parse_tasks:
		if WorkerThreadPool.is_task_completed(_parse_tasks[tkey]):
			done.append(tkey)
	for tkey: Vector2i in done:
		
		WorkerThreadPool.wait_for_task_completion(_parse_tasks[tkey])
		_parse_tasks.erase(tkey)
		_instance_queue.append(tkey)






func drain() -> void:
	if _instance_queue.is_empty() and _feature_queue.is_empty():
		return
	var deadline := Time.get_ticks_usec() + int(instance_budget_ms * 1000.0)

	
	
	
	
	var first := true
	while not _instance_queue.is_empty() and (first or Time.get_ticks_usec() < deadline):
		first = false
		var tkey: Vector2i = _instance_queue.pop_front()
		var bucket: Variant = _ready_buckets.get(tkey, {})
		_ready_buckets.erase(tkey)
		_pending_tiles.erase(tkey)
		
		
		if _is_loaded_cb.call(tkey):
			continue
		if not _in_range_cb.call(tkey):
			continue
		_instance_cb.call(tkey, bucket)  

	
	
	first = true
	while not _feature_queue.is_empty() and (first or Time.get_ticks_usec() < deadline):
		first = false
		_build_feature_cb.call(_feature_queue.pop_front())



func enqueue_features(items: Array) -> void:
	_feature_queue.append_array(items)




func cancel_pending(tkey: Vector2i) -> void:
	_pending_tiles.erase(tkey)
	_ready_buckets.erase(tkey)
	_instance_queue.erase(tkey)




func purge_features(should_keep: Callable) -> void:
	if _feature_queue.is_empty():
		return
	var kept: Array = []
	for item in _feature_queue:
		if should_keep.call(item):
			kept.append(item)
	_feature_queue = kept





func shutdown() -> void:
	for tkey: Vector2i in _parse_tasks:
		WorkerThreadPool.wait_for_task_completion(_parse_tasks[tkey])
	_parse_tasks.clear()
	_pending_tiles.clear()
	_ready_buckets.clear()
	_instance_queue.clear()
	_feature_queue.clear()
