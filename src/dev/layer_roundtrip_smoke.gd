extends SceneTree
## Loads every reality-layer scene headless (the same scenes LayerManager
## transitions to), verifies the world builds, then drives the actual
## transition chain Liminal -> Supraliminal -> Hyperliminal -> Liminal.
var _t := 0.0
var _phase := 0
var _check_at := 0.0
var _failures: Array[String] = []

func _run() -> void:
	change_scene_to_packed(load("res://scenes/layers/liminal.tscn"))
	await process_frame

func _process(delta: float) -> bool:
	_t += delta
	if _t > 300.0:
		print("LAYER_RT=HANG phase=", _phase, " scene=", str(current_scene.name if current_scene else "null"))
		quit(1)
		return false

	var lm = root.get_node_or_null("LayerManager")

	# Phase 0: liminal world build check (player spawn).
	if _phase == 0 and current_scene != null and "liminal" in str(current_scene.get_scene_file_path()).to_lower():
		if _check_player_spawned() == null:
			_failures.append("liminal: no player")
		else:
			print("LAYER_RT liminal player ok; children=", current_scene.get_child_count())
		_phase = 1
		_check_at = _t
		print("LAYER_RT liminal verified")

	if _phase == 1 and _t - _check_at > 2.0:
		lm.transition_to("supraliminal")
		_phase = 2
		_check_at = _t
		print("LAYER_RT transition -> supraliminal requested")

	if _phase == 2 and current_scene != null and "supraliminal" in str(current_scene.get_scene_file_path()).to_lower():
		if _t - _check_at > 30.0:
			if _check_player_spawned() == null:
				_failures.append("supraliminal: no player")
			else:
				print("LAYER_RT supraliminal player ok; children=", current_scene.get_child_count())
			lm.transition_to("hyperliminal")
			_phase = 3
			_check_at = _t

	if _phase == 3 and current_scene != null and "neon_imperium" in str(current_scene.get_scene_file_path()).to_lower():
		_check_at = _t
		print("LAYER_RT hyperliminal (catsino) reached")
		lm.transition_to("liminal")
		_phase = 4

	if _phase == 4 and current_scene != null and "liminal" in str(current_scene.get_scene_file_path()).to_lower():
		print("LAYER_RT=RESULT:", "PASS" if _failures.is_empty() else "FAIL",
			" roundtrip=liminal->supraliminal->hyperliminal->liminal complete",
			" failures=", _failures)
		quit(0 if _failures.is_empty() else 1)
		return false
	return false

func _check_player_spawned() -> Node:
	if current_scene == null:
		return null
	for c in current_scene.find_children("*", "CharacterBody3D", true, false):
		if c.get_script() != null and "third_person_controller" in c.get_script().resource_path:
			return c
	return null
