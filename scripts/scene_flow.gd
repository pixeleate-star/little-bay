extends RefCounted










const RunSessionScript := preload("res://scripts/run_session.gd")

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const LOADING_SCENE := "res://scenes/loading_screen.tscn"




static func start_drive(
		tree: SceneTree,
		mode: RunSessionScript.Mode = RunSessionScript.Mode.FREE_DRIVE) -> void:
	tree.paused = false
	var loading: Node = (load(LOADING_SCENE) as PackedScene).instantiate()
	loading.set("game_mode", mode)
	_replace_current_scene(tree, loading)


static func go_to_title(tree: SceneTree) -> void:
	tree.paused = false
	tree.change_scene_to_file(TITLE_SCENE)




static func _replace_current_scene(tree: SceneTree, scene: Node) -> void:
	var old := tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if old != null:
		old.queue_free()
