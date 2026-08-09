extends SceneTree
func _init() -> void:
	_run.call_deferred()

var _t := 0.0
var _authed := false
func _process(delta: float) -> bool:
	_t += delta
	if _t > 16.0:
		print("LOGIN_FLOW=HANG current_scene=", str(current_scene.name if current_scene else "null"))
		quit(1)
		return false
	if _t > 4.0 and not _authed and current_scene != null and current_scene.name == "LoginScreen":
		_authed = true
		var acc = root.get_node_or_null("AccountManager")
		var gm = root.get_node_or_null("GameManager")
		if not acc or not gm:
			print("LOGIN_FLOW=FAIL missing autoloads")
			quit(1)
			return false
		print("LOGIN_FLOW pre-auth state=", gm.game_state, " conns=", acc.get_signal_connection_list("authenticated").size())
		acc.authenticated.connect(func(s): print("LOGIN_FLOW signal fired"))
		acc.auth_guest()
	if current_scene != null and current_scene.name == "TitleScreen":
		print("LOGIN_FLOW=RESULT:PASS current_scene=", current_scene.name)
		quit(0)
		return false
	return false

func _run() -> void:
	change_scene_to_packed(load("res://scenes/ui/splash.tscn"))
	await process_frame
