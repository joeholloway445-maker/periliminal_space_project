extends CharacterBody3D
## Meat only. Stats come from OmniDex compose.

var yaw := 0.0
var pitch := 0.15
var crouched := false
@onready var cam: Camera3D = $Camera3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var lens := OmniDexTables.compose(Session.sex, Session.race_id, Session.frame_id, Session.mod_id)
	var speed := float(lens.get("speed", 8.0))
	if crouched:
		speed *= 0.55
	var wish := Vector3(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back")
	)
	wish = (Basis(Vector3.UP, yaw) * wish)
	if wish.length() > 1.0:
		wish = wish.normalized()
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if not is_on_floor():
		velocity.y -= LayerRouter.gravity() * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = 7.4
	move_and_slide()
	if cam:
		cam.rotation.x = -pitch
		cam.position.y = 0.9 if crouched else 1.4
		rotation.y = yaw
	var back := wish.z > 0.15
	Proprioception.feed(global_position, yaw, back, crouched, delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0024
		pitch = clampf(pitch + event.relative.y * 0.002, -1.2, 0.6)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventKey and event.pressed and event.keycode == KEY_CTRL:
		crouched = not crouched
	if event.is_action_pressed("attack"):
		_strike()

func _strike() -> void:
	Consistency.record_deed("attack")
	var nearest: Node = null
	var best := 3.2
	for n in get_parent().get_children():
		if n == self:
			continue
		if n.has_method("hit") and n.get("alive") == true:
			var d := global_position.distance_to(n.global_position)
			if d < best:
				best = d
				nearest = n
	if nearest:
		nearest.call("hit", 10, 0.7)
	else:
		var talk: Node = null
		best = 2.4
		for n in get_parent().get_children():
			if n.has_method("talk"):
				var d := global_position.distance_to(n.global_position)
				if d < best:
					best = d
					talk = n
		if talk:
			talk.call("talk")
