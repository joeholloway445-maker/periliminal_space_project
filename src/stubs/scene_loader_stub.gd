extends Node
class_name SceneLoader
## Lightweight scene loader used until/unless maaacks_menus_template is enabled.
## When the plugin is enabled it registers its own SceneLoader autoload — disable
## or delete this stub then (see docs/ADDONS.md).

static var _loading_progress: float = 1.0
static var _loading_status: String = ""

static func load_scene(path: String, _loading_screen: bool = false) -> void:
	if path.is_empty():
		push_warning("SceneLoader: empty path")
		return
	if not ResourceLoader.exists(path):
		push_error("SceneLoader: missing scene %s" % path)
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("SceneLoader: no SceneTree")
		return
	var err := tree.change_scene_to_file(path)
	if err != OK:
		push_error("SceneLoader: change_scene_to_file(%s) failed (%d)" % [path, err])

static func get_progress() -> float:
	return _loading_progress

static func get_status() -> String:
	return _loading_status

static func change_scene_to_resource(res: Resource) -> void:
	var path := res.resource_path
	if not path.is_empty():
		load_scene(path)

static func reload_current_scene() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.reload_current_scene()

static func is_loading_scene() -> bool:
	return false

static func change_scene_to_loading_screen(_path: String) -> void:
	load_scene(_path, true)
