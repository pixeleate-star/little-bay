extends Node3D





const FrameTracerScript := preload("res://scripts/frame_tracer.gd")
const ScreenshotScript := preload("res://scripts/screenshot.gd")






const TopDownCameraScript := preload("res://scripts/top_down_camera.gd")
const SceneFlowScript := preload("res://scripts/scene_flow.gd")
const RunSessionScript := preload("res://scripts/run_session.gd")
const RunControllerScript := preload("res://scripts/run_controller.gd")



signal loading_progress(fraction: float, status: String)


signal world_ready



@export var game_mode: RunSessionScript.Mode = RunSessionScript.Mode.FREE_DRIVE


const _TILE_PROGRESS_SHARE := 0.85


const _SPAWN_FRAME_BUDGET_MS := 50.0



const _WARMUP_FRAMES := 30

@onready var tile_manager: OSMTileManager = $OSMTileManager
@onready var car: CarController = $Car

@onready var traffic_manager: TrafficManager = $TrafficManager
@onready var delivery_manager: Node3D = $DeliveryManager


@onready var dial_cluster: DialCluster = $HUD/DialCluster


@onready var speed_blur: SpeedBlur = $SpeedBlurLayer/SpeedBlur
@onready var info_label: Label = $HUD/InfoLabel
@onready var kudos_label: Label = $HUD/KudosLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var kudos_popup: Label = $HUD/KudosPopup
@onready var street_banner: Control = $HUD/StreetBanner
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var resume_button: Button = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/ResumeButton
@onready var quit_button: Button = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/QuitButton
@onready var main_menu_button: Button = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/MainMenuButton
@onready var pause_eyebrow: Label = $PauseMenu/CenterContainer/Panel/Margin/Columns/Identity/Eyebrow
@onready var sky_controller: SkyController = $SkyController



@onready var post_processing: PostProcessing = $PostProcessing
@onready var day_night_toggle: CheckButton = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/DayNightToggle
@onready var debug_labels_toggle: CheckButton = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/DebugLabelsToggle
@onready var wet_weather_toggle: CheckButton = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/WetWeatherToggle
@onready var speed_blur_toggle: CheckButton = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/SpeedBlurToggle
@onready var minimap: Minimap = $HUD/Minimap
@onready var driving_assists_toggle: CheckButton = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/DrivingAssistsToggle
@onready var frame_tracer_toggle: CheckButton = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/FrameTracerToggle
@onready var dump_frame_times_button: Button = $PauseMenu/CenterContainer/Panel/Margin/Columns/Settings/DumpFrameTimesButton
@onready var headlights: Headlights = $Car/Headlights
@onready var street_lamp_lights: StreetLampLights = $StreetLampLights


@onready var weather_controller: WeatherController = $WeatherController




@onready var isometric_camera: Camera3D = $IsometricCamera
@onready var top_down_camera: Camera3D = $TopDownCamera





var _cameras: Array[Camera3D] = []



var _camera_index: int = 0



var _kudos_popup_tween: Tween = null



var _is_world_ready: bool = false


var _run: RunControllerScript = null

func _ready() -> void:
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	car.set_engine_muted(true)
	
	
	if OS.has_feature("web"):
		post_processing.glow_enabled = false
		post_processing.ssao_enabled = false
		post_processing.ssil_enabled = false
		post_processing.ssr_enabled = false
		post_processing.dof_enabled = false
		speed_blur.enabled = true
	
	speed_blur.enabled = true
	
	
	
	kudos_label.visible = false
	combo_label.visible = false
	kudos_popup.visible = false

	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	
	
	
	car.speed_changed.connect(_on_car_speed_changed)
	car.gear_changed.connect(_on_car_gear_changed)
	car.gear_ratio_changed.connect(dial_cluster.set_gear_ratio)
	car.assists_changed.connect(dial_cluster.set_assist_levels)
	car.kudos_changed.connect(_on_car_kudos_changed)
	car.kudos_event.connect(_on_car_kudos_event)

	if game_mode != RunSessionScript.Mode.FREE_DRIVE:
		_run = RunControllerScript.new()
		_run.name = "RunController"
		_run.mode = game_mode
		_run.car = car
		_run.minimap = $HUD/Minimap
		add_child(_run)
		car.kudos_event.connect(_run.record_event)
		_run.free_drive_requested.connect(_on_run_abandoned)
	_update_mode_labels()

	
	tile_manager.tile_loaded.connect(_on_tiles_changed)
	tile_manager.tile_unloaded.connect(_on_tiles_changed)

	
	
	
	
	car.freeze = true
	
	
	
	var osm_data := tile_manager.get_osm_data()
	if osm_data != null:
		_on_world_ready(osm_data)
	else:
		tile_manager.data_loaded.connect(_on_world_ready)

	
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_update_info_label)

	
	resume_button.pressed.connect(_set_paused.bind(false))
	quit_button.pressed.connect(_on_quit_pressed)
	main_menu_button.pressed.connect(SceneFlowScript.go_to_title.bind(get_tree()))

	
	
	day_night_toggle.button_pressed = sky_controller.is_day()
	_update_day_night_label(sky_controller.is_day())
	day_night_toggle.toggled.connect(_on_day_night_toggled)

	
	
	
	debug_labels_toggle.button_pressed = false
	debug_labels_toggle.toggled.connect(_on_debug_labels_toggled)

	
	
	
	wet_weather_toggle.button_pressed = weather_controller.is_wet()
	wet_weather_toggle.toggled.connect(_on_wet_weather_toggled)

	
	
	
	driving_assists_toggle.button_pressed = car.are_driving_assists_enabled()
	driving_assists_toggle.toggled.connect(_on_driving_assists_toggled)

	
	
	
	frame_tracer_toggle.button_pressed = FrameTracerScript.is_enabled()
	frame_tracer_toggle.toggled.connect(_on_frame_tracer_toggled)
	dump_frame_times_button.pressed.connect(FrameTracerScript.dump_summary)

	
	
	
	
	
	
	sky_controller.day_night_changed.connect(_on_day_night_changed)
	headlights.set_on(not sky_controller.is_day())
	street_lamp_lights.set_on(not sky_controller.is_day())

	
	
	_cameras = [car.camera, isometric_camera, top_down_camera]

func _process(delta: float) -> void:
	
	if not _is_world_ready:
		return
	
	if _run != null and _run.is_showing_results():
		return

	if Input.is_action_just_pressed("ui_cancel"):
		_set_paused(not get_tree().paused)

	
	if Input.is_action_just_pressed("reset_car") and not get_tree().paused \
			and not car.freeze and not car.input_locked:
		recover_car()

	
	
	
	
	if not get_tree().paused:
		speed_blur.update_speed(car.linear_velocity.length() * 3.6, delta)









func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		
		
		frame_tracer_toggle.button_pressed = not FrameTracerScript.is_enabled()
	elif key.keycode == KEY_F4:
		FrameTracerScript.dump_summary()
	elif key.keycode == KEY_F5:
		
		wet_weather_toggle.button_pressed = not weather_controller.is_wet()
	elif key.keycode == KEY_P:
		_take_screenshot()
	elif key.keycode == KEY_T:
		cycle_camera()
	elif key.keycode == KEY_M:
		minimap.call("toggle_expanded")















func cycle_camera() -> int:
	if _cameras.is_empty():
		return _camera_index
	_camera_index = (_camera_index + 1) % _cameras.size()
	var cam := _cameras[_camera_index]
	
	
	
	if cam == null:
		return _camera_index
	if cam.has_method("snap_to_target"):
		cam.call("snap_to_target")
	cam.current = true
	return _camera_index




func recover_car() -> void:
	car.recover()
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("snap_to_target"):
		cam.call("snap_to_target")









func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var path: String = ScreenshotScript.capture(get_viewport())
	if path != "":
		print("[screenshot] saved %s" % path)




func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_menu.visible = paused
	
	
	car.set_engine_muted(paused)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)




func _on_world_ready(_osm_data: OSMParser.OSMData) -> void:
	
	
	
	var pose := traffic_manager.spawn_pose_near(car.global_position)
	if not pose.is_empty():
		car.teleport(pose["position"], pose["forward"])

	
	
	
	
	var spawn_xz := car.global_position
	var spawn_tiles := tile_manager.spawn_tiles_around(spawn_xz)
	var frame_start := Time.get_ticks_msec()
	for i: int in spawn_tiles.size():
		tile_manager.load_tile_now(spawn_tiles[i])
		var fraction := _TILE_PROGRESS_SHARE * float(i + 1) / spawn_tiles.size()
		if Time.get_ticks_msec() - frame_start >= _SPAWN_FRAME_BUDGET_MS:
			loading_progress.emit(fraction, "Building streets")
			await get_tree().process_frame
			frame_start = Time.get_ticks_msec()
	loading_progress.emit(_TILE_PROGRESS_SHARE, "Dropping the car")

	
	
	
	
	
	await get_tree().physics_frame
	var ground_y := tile_manager.get_terrain_height(spawn_xz)
	var hit_y := _raycast_ground_y(spawn_xz, ground_y)
	if not is_nan(hit_y):
		ground_y = hit_y

	const SPAWN_CLEARANCE := 1.0
	var t := car.global_transform
	t.origin.y = ground_y + SPAWN_CLEARANCE
	car.global_transform = t
	car.remember_safe_point()

	
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	await get_tree().physics_frame
	car.freeze = false

	for i: int in _WARMUP_FRAMES:
		var warm := float(i + 1) / _WARMUP_FRAMES
		loading_progress.emit(lerpf(_TILE_PROGRESS_SHARE, 1.0, warm), "Warming up")
		await get_tree().process_frame
	_is_world_ready = true
	street_banner.reset()
	delivery_manager.call("setup", car, traffic_manager)
	world_ready.emit()
	car.set_engine_muted(false)
	if _run != null:
		_run.road_network = traffic_manager.road_network()
		_run.begin()


func is_world_ready() -> bool:
	return _is_world_ready



func _on_run_abandoned() -> void:
	car.kudos_event.disconnect(_run.record_event)
	_run.queue_free()
	_run = null
	game_mode = RunSessionScript.Mode.FREE_DRIVE
	_update_mode_labels()


func _update_mode_labels() -> void:
	pause_eyebrow.text = "LITTLE RIDER  /  FREE DRIVE"
	_update_info_label()





func _raycast_ground_y(xz: Vector3, approx_y: float) -> float:
	var space := get_world_3d().direct_space_state
	var from := Vector3(xz.x, approx_y + 50.0, xz.z)
	var to := Vector3(xz.x, approx_y - 50.0, xz.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [car.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return hit.position.y

func _on_quit_pressed() -> void:
	get_tree().quit()



func _on_day_night_toggled(is_day: bool) -> void:
	sky_controller.set_day(is_day)
	_update_day_night_label(is_day)

func _update_day_night_label(is_day: bool) -> void:
	day_night_toggle.text = "Daytime" if is_day else "Nighttime"




func _on_day_night_changed(is_day: bool) -> void:
	headlights.set_on(not is_day)
	street_lamp_lights.set_on(not is_day)



func _on_debug_labels_toggled(enabled: bool) -> void:
	tile_manager.set_show_debug_labels(enabled)
	for label: Node in get_tree().get_nodes_in_group("debug_labels"):
		label.visible = enabled




func _on_wet_weather_toggled(wet: bool) -> void:
	weather_controller.set_wet(wet)




func _on_speed_blur_toggled(enabled: bool) -> void:
	speed_blur.enabled = enabled
	if not enabled:
		speed_blur.reset()


func _on_driving_assists_toggled(enabled: bool) -> void:
	car.set_driving_assists_enabled(enabled)


func _on_frame_tracer_toggled(enabled: bool) -> void:
	FrameTracerScript.set_enabled(enabled)
	print("[trace] frame tracing %s" % ("ON" if enabled else "OFF"))

func _on_car_speed_changed(speed_kmh: float) -> void:
	dial_cluster.set_speed(speed_kmh)

func _on_car_gear_changed(gear: int) -> void:
	dial_cluster.set_gear(gear)




func _on_car_kudos_changed(total: int, combo: float) -> void:
	kudos_label.text = "KUDOS   %06d" % total
	if combo > 1.01:
		combo_label.text = "x%.1f COMBO" % combo
	else:
		combo_label.text = ""




func _on_car_kudos_event(label: String, amount: int, is_penalty: bool) -> void:
	var sign_str := "+" if amount >= 0 else ""
	kudos_popup.text = "%s  %s%d" % [label, sign_str, amount]
	kudos_popup.add_theme_color_override(
		"font_color",
		Color("ff806b") if is_penalty else Color("d5f36b")
	)
	_play_kudos_popup()




func _play_kudos_popup() -> void:
	if _kudos_popup_tween != null and _kudos_popup_tween.is_valid():
		_kudos_popup_tween.kill()
	
	kudos_popup.pivot_offset = kudos_popup.size * 0.5
	kudos_popup.modulate.a = 1.0
	kudos_popup.scale = Vector2(1.3, 1.3)
	_kudos_popup_tween = create_tween()
	_kudos_popup_tween.set_parallel(true)
	_kudos_popup_tween.tween_property(kudos_popup, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_kudos_popup_tween.tween_property(kudos_popup, "modulate:a", 0.0, 0.9) \
		.set_delay(0.35)

func _on_tiles_changed(_tile_key: Vector2i) -> void:
	_update_info_label()

func _update_info_label() -> void:
	var speed_kmh := int(round(car.linear_velocity.length() * 3.6))
	info_label.text = "LITTLE RIDER  /  FREE DRIVE     %03d KM/H     %d TRAFFIC" % [
		speed_kmh, traffic_manager.car_count()
	]
