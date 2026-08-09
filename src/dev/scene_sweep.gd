extends SceneTree
## Loads every .tscn in res://scenes/ via change_scene_to_packed, runs up to
## 60 frames each, and reports runtime errors. Catches "_ready() crashes".
func _init() -> void:
	_run.call_deferred()

var _queue: Array[String] = []
var _idx := 0
var _budget := 0
var _failures: Array[String] = []
var _scanned := 0
const MAX_FRAMES := 60

func _run() -> void:
	await process_frame
	var dir := DirAccess.open("res://scenes")
	if dir == null:
		print("SCENE_SWEEP=FAIL cannot open res://scenes")
		quit(1)
		return
	_collect(dir, "res://scenes")
	_next()

func _collect(dir: DirAccess, base: String) -> void:
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			_queue.append(base + "/" + f)
	for d in dir.get_directories():
		if d.begins_with("."):
			continue
		var sub := dir.open(base + "/" + d)
		if sub != null:
			_collect(sub, base + "/" + d)

func _next() -> void:
	if _idx >= _queue.size():
		print("SCENE_SWEEP=RESULT:", "FAIL" if not _failures.is_empty() else "PASS",
			" scanned=", _scanned, " of ", _queue.size())
		for fn in _failures:
			print("  FAILED ", fn)
		quit(0 if _failures.is_empty() else 1)
		return
	var path: String = _queue[_idx]
	var ps: PackedScene = load(path)
	if ps == null:
		_failures.append(path + " (load failed)")
		_idx += 1
		_next()
		return
	_budget = 0
	printerr("SWEEP loading: ", path)
	change_scene_to_packed(ps)

func _process(_delta: float) -> bool:
	if _queue.is_empty():
		return false
	_budget += 1
	if _budget >= MAX_FRAMES:
		var path: String = _queue[_idx]
		# If current_scene is still null or not this path, it probably crashed.
		_scanned += 1
		_idx += 1
		_next()
	return false
