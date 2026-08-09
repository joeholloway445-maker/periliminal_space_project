extends SceneTree
## Full spine: splash -> login -> guest auth -> title -> New Venture wizard
## -> confirm race/frame/mod/customize/name -> Liminal world with player spawn.
## RESULT=PASS means every link in the boot->gameplay chain works.

var _t := 0.0
var _phase := 0
var _authed := false
var _wizard: Node = null
var _wiz_frames := 0
var _verify_start := 0.0

func _run() -> void:
	change_scene_to_packed(load("res://scenes/ui/splash.tscn"))
	await process_frame

func _process(delta: float) -> bool:
	_t += delta
	if _t > 150.0:
		print("FULL_SPINE=HANG phase=", _phase, " scene=", str(current_scene.name if current_scene else "null"))
		quit(1)
		return false

	var acc = root.get_node_or_null("AccountManager")
	var gm = root.get_node_or_null("GameManager")

	if _phase == 0 and _t > 4.0:
		acc.auth_guest()
		_phase = 1
		print("FULL_SPINE auth triggered")

	if _phase == 1 and current_scene != null and current_scene.name == "TitleScreen":
		print("FULL_SPINE title screen reached")
		change_scene_to_packed(load("res://scenes/ui/venture_wizard.tscn"))
		_phase = 2

	if _phase == 2 and current_scene != null and current_scene.name == "VentureWizard":
		_wizard = current_scene
		_phase = 3
		print("FULL_SPINE wizard loaded, driving confirms")

	if _phase == 3 and _wizard != null and is_instance_valid(_wizard):
		_wiz_frames += 1
		if _wiz_frames == 10:
			_wizard._confirm_step()
		elif _wiz_frames == 20:
			_wizard._confirm_step()
		elif _wiz_frames == 30:
			_wizard._confirm_step()
		elif _wiz_frames == 40:
			_wizard._confirm_step()
		elif _wiz_frames == 50:
			_wizard._name_edit.text = "SpineCat"
			_wizard._confirm_step()
			_phase = 4
			_verify_start = _t
			print("FULL_SPINE venture launched; picked=", _wizard._picked)
	elif _phase == 3 and (_wizard == null or not is_instance_valid(_wizard)):
		# Wizard already transitioned and got freed; go straight to verify.
		_phase = 4
		_verify_start = _t
		print("FULL_SPINE wizard freed (already transitioning)")

	if _phase == 4:
		if current_scene != null and "liminal" in str(current_scene.get_scene_file_path()).to_lower():
			var lm = root.get_node_or_null("LayerManager")
			var player: Node = null
			for c in current_scene.find_children("*", "CharacterBody3D", true, false):
				if c.get_script() != null and "third_person_controller" in c.get_script().resource_path:
					player = c
					break
			if player != null:
				print("FULL_SPINE=RESULT:PASS layer=", str(lm.current_layer_id if lm else "null"),
					" scene=", current_scene.get_scene_file_path(),
					" player=", player.name)
				quit(0)
				return false
			elif _t - _verify_start > 40.0:
				print("FULL_SPINE=FAIL no player spawn after 40s in Liminal; scene=", current_scene.get_scene_file_path())
				quit(1)
				return false
	return false
