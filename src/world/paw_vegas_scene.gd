extends Node3D

class_name PawsVegasScene

# ─── Casino room dimensions ────────────────────────────────────────────────────
const ROOM_W := 30.0
const ROOM_D := 22.0
const ROOM_H := 6.0
const WALL_THICK := 0.4

# ─── Configuration ─────────────────────────────────────────────────────────────
@export var npc_count: int = 15
@export var npc_wander_radius: float = 12.0

# ─── Child references ──────────────────────────────────────────────────────────
var npc_container: Node3D
var game_stations: Node3D
var _ui_layer: CanvasLayer
var _npcs: Array[Node3D] = []

# ─── Game station definitions ──────────────────────────────────────────────────
const STATIONS: Array[Dictionary] = [
	{name = "Blackjack Table",  scene = "res://scenes/games/arcade/blackjack.tscn",     pos = Vector3(-8, 0, -3),  icon = "🃏"},
	{name = "Poker Table",      scene = "res://scenes/games/arcade/paw_poker.tscn",      pos = Vector3(0, 0, -3),   icon = "♠️"},
	{name = "Texas Hold'em",    scene = "res://scenes/games/arcade/holdem.tscn",         pos = Vector3(8, 0, -3),   icon = "♦️"},
	{name = "Lucky Cat Slots",  scene = "res://scenes/games/slots/slot_machine.tscn",    pos = Vector3(-12, 0, 3),  icon = "🎰"},
	{name = "Fortune Wheel",    scene = "res://scenes/games/arcade/fortune_wheel.tscn",  pos = Vector3(12, 0, 3),   icon = "🎡"},
	{name = "Scratch Cards",    scene = "res://scenes/games/arcade/scratch_card.tscn",   pos = Vector3(12, 0, -3),  icon = "🎫"},
	{name = "Coin Pusher",      scene = "res://scenes/games/arcade/coin_pusher.tscn",    pos = Vector3(-12, 0, -3), icon = "🪙"},
	{name = "Cat Puzzle",       scene = "res://scenes/games/arcade/cat_puzzle.tscn",     pos = Vector3(0, 0, 6),    icon = "🧩"},
]

# ─── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_ensure_scene_tree()
	_build_casino_room()
	_build_game_stations()
	_spawn_npcs(npc_count)
	_add_back_button()
	_add_chip_cage_button()

func _process(_delta: float) -> void:
	_update_npc_wander()

func _ensure_scene_tree() -> void:
	npc_container = get_node_or_null("NPCContainer") as Node3D
	if npc_container == null:
		npc_container = Node3D.new()
		npc_container.name = "NPCContainer"
		add_child(npc_container)

	game_stations = get_node_or_null("GameStations") as Node3D
	if game_stations == null:
		game_stations = Node3D.new()
		game_stations.name = "GameStations"
		add_child(game_stations)

	_ui_layer = get_node_or_null("UILayer") as CanvasLayer
	if _ui_layer == null:
		_ui_layer = CanvasLayer.new()
		_ui_layer.name = "UILayer"
		add_child(_ui_layer)
	if _ui_layer.get_script() != null and _ui_layer.get_child_count() == 0:
		_ui_layer.set_script(null)

# ─── Casino room builder ────────────────────────────────────────────────────────
func _build_casino_room() -> void:
	# Floor
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.12, 0.06, 0.15)
	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(ROOM_W, 0.2, ROOM_D)
	floor.mesh = floor_mesh
	floor.position.y = -0.1
	floor.material_override = floor_mat
	add_child(floor)

	# Center aisle carpet
	var runner_mat := StandardMaterial3D.new()
	runner_mat.albedo_color = Color(0.6, 0.15, 0.2)
	var runner := MeshInstance3D.new()
	var runner_mesh := BoxMesh.new()
	runner_mesh.size = Vector3(3.0, 0.22, ROOM_D - 4.0)
	runner.mesh = runner_mesh
	runner.position = Vector3(0, 0.01, 0)
	runner.material_override = runner_mat
	add_child(runner)

	# Ceiling
	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.albedo_color = Color(0.08, 0.06, 0.12)
	var ceiling := MeshInstance3D.new()
	var ceil_mesh := BoxMesh.new()
	ceil_mesh.size = Vector3(ROOM_W, 0.2, ROOM_D)
	ceiling.mesh = ceil_mesh
	ceiling.position.y = ROOM_H
	ceiling.material_override = ceil_mat
	add_child(ceiling)

	# Walls
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.1, 0.08, 0.14)
	for wall_def in [
		{size = Vector3(ROOM_W, ROOM_H, WALL_THICK), pos = Vector3(0, ROOM_H / 2.0, -ROOM_D / 2.0)},
		{size = Vector3(ROOM_W, ROOM_H, WALL_THICK), pos = Vector3(0, ROOM_H / 2.0, ROOM_D / 2.0)},
		{size = Vector3(WALL_THICK, ROOM_H, ROOM_D), pos = Vector3(-ROOM_W / 2.0, ROOM_H / 2.0, 0)},
		{size = Vector3(WALL_THICK, ROOM_H, ROOM_D), pos = Vector3(ROOM_W / 2.0, ROOM_H / 2.0, 0)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = wall_def.size
		mi.mesh = box
		mi.position = wall_def.pos
		mi.material_override = wall_mat
		add_child(mi)

	# Neon trim along wall tops
	var neon_mat := StandardMaterial3D.new()
	neon_mat.albedo_color = Color(0.9, 0.25, 0.8)
	neon_mat.emission_enabled = true
	neon_mat.emission = Color(0.9, 0.3, 0.9)
	neon_mat.emission_energy_multiplier = 3.0
	for nz in [-ROOM_D / 2.0 + WALL_THICK / 2.0, ROOM_D / 2.0 - WALL_THICK / 2.0]:
		var n := MeshInstance3D.new()
		var nb := BoxMesh.new()
		nb.size = Vector3(ROOM_W - 2.0, 0.08, 0.08)
		n.mesh = nb
		n.position = Vector3(0, ROOM_H - 0.3, nz)
		n.material_override = neon_mat
		add_child(n)

	# Chandelier lights — warm yellow orbs
	var light_color := Color(0.95, 0.75, 0.45)
	for lx in [-8, 0, 8]:
		for lz in [-5, 0, 5]:
			var pos := Vector3(lx, ROOM_H - 0.8, lz)
			var lamp := OmniLight3D.new()
			lamp.position = pos
			lamp.light_color = light_color
			lamp.light_energy = 1.2
			lamp.omni_range = 8.0
			add_child(lamp)
			var orb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.15
			sphere.height = 0.3
			orb.mesh = sphere
			orb.position = pos
			var omat := StandardMaterial3D.new()
			omat.albedo_color = light_color
			omat.emission_enabled = true
			omat.emission = light_color
			omat.emission_energy_multiplier = 4.0
			orb.material_override = omat
			add_child(orb)

	# Ambient purple wash
	var ambient := OmniLight3D.new()
	ambient.name = "NeonAmbient"
	ambient.position = Vector3(0, ROOM_H / 2.0, 0)
	ambient.light_color = Color(0.7, 0.2, 1.0)
	ambient.light_energy = 0.8
	ambient.omni_range = ROOM_W
	add_child(ambient)

# ─── Game stations — interactable 3D tables / machines ─────────────────────────
func _build_game_stations() -> void:
	for spec in STATIONS:
		var station := _make_station(spec)
		game_stations.add_child(station)

func _make_station(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = spec.name
	root.position = spec.pos

	# Body
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.4, 0.8, 1.6)
	body.mesh = body_mesh
	body.position.y = 0.4
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.06, 0.12)
	body.material_override = body_mat
	root.add_child(body)

	# Green felt top
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.6, 0.06, 1.8)
	top.mesh = top_mesh
	top.position.y = 0.83
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.08, 0.35, 0.15)
	top.material_override = top_mat
	root.add_child(top)

	# Floating label
	var lbl := Label3D.new()
	lbl.text = "%s  %s" % [spec.icon, spec.name]
	lbl.position = Vector3(0, 1.3, 0)
	lbl.font_size = 18
	lbl.modulate = Color(0.9, 0.8, 1.0)
	lbl.outline_size = 3
	root.add_child(lbl)

	# Clickable trigger
	var area := Area3D.new()
	area.name = "ClickArea"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.5, 2.5)
	cs.shape = box
	area.add_child(cs)
	area.position.y = 0.75
	area.input_ray_pickable = true
	var scene_path: String = spec.scene
	area.input_event.connect(func(_cam, ev, _pos, _n, _i):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if ResourceLoader.exists(scene_path):
				get_tree().change_scene_to_file(scene_path)
	)
	root.add_child(area)

	return root

# ─── NPCs ───────────────────────────────────────────────────────────────────────
func _spawn_npcs(count: int) -> void:
	for npc in _npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	_npcs.clear()
	if npc_container == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("paw_vegas_npcs")
	for i in range(count):
		var npc := _create_npc_node(i, rng)
		npc_container.add_child(npc)
		_npcs.append(npc)

func _create_npc_node(index: int, rng: RandomNumberGenerator) -> Node3D:
	var npc := Node3D.new()
	npc.name = "NPC_%d" % index
	var angle: float = rng.randf() * TAU
	var dist: float = rng.randf_range(2.0, npc_wander_radius)
	npc.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.5
	mi.mesh = capsule
	mi.position.y = 0.75
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(rng.randf(), 0.5, 0.8)
	mi.material_override = mat
	npc.add_child(mi)

	var nav := NavigationAgent3D.new()
	nav.name = "NavAgent"
	nav.path_desired_distance = 0.5
	nav.target_desired_distance = 0.8
	npc.add_child(nav)
	npc.set_meta("wander_timer", rng.randf_range(2.0, 8.0))
	npc.set_meta("wander_elapsed", 0.0)
	return npc

func _update_npc_wander() -> void:
	var dt: float = get_process_delta_time()
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		var elapsed: float = npc.get_meta("wander_elapsed", 0.0) + dt
		var timer: float = npc.get_meta("wander_timer", 5.0)
		npc.set_meta("wander_elapsed", elapsed)
		var nav: NavigationAgent3D = npc.get_node_or_null("NavAgent")
		if nav == null:
			continue
		if elapsed >= timer or nav.is_navigation_finished():
			var angle: float = randf() * TAU
			var dist: float = randf_range(1.0, npc_wander_radius)
			nav.target_position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			npc.set_meta("wander_elapsed", 0.0)
			npc.set_meta("wander_timer", randf_range(3.0, 9.0))
		elif not nav.is_navigation_finished():
			var next_pos: Vector3 = nav.get_next_path_position()
			var direction: Vector3 = (next_pos - npc.global_position).normalized()
			npc.global_position += direction * 1.5 * dt
			if direction.length_squared() > 0.001:
				npc.look_at(npc.global_position + direction, Vector3.UP)

# ─── UI ─────────────────────────────────────────────────────────────────────────
func _add_back_button() -> void:
	if _ui_layer == null:
		return
	var back := Button.new()
	back.name = "BackToMenu"
	back.text = "⬅ Leave Casino"
	back.position = Vector2(16, 16)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	_ui_layer.add_child(back)

func _add_chip_cage_button() -> void:
	if _ui_layer == null:
		return
	var EconomyManager = AutoloadGate.get_node("EconomyManager")
	var NotificationUI = AutoloadGate.get_node("NotificationUI")
	var panel := PanelContainer.new()
	panel.name = "ChipCage"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -260
	panel.offset_top = 10
	panel.offset_right = -10
	panel.offset_bottom = 120
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	_ui_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "💎 CHIP CAGE"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var chips_lbl := Label.new()
	chips_lbl.text = "Chips: %d" % EconomyManager.get_chips()
	chips_lbl.name = "ChipsLabel"
	vbox.add_child(chips_lbl)

	var buy := Button.new()
	buy.text = "Buy 100 chips (115 🪙)"
	buy.pressed.connect(func():
		var ok: bool = EconomyManager.buy_chips_local(100)
		if ok:
			NotificationUI.notify_info("Bought 100 chips.")
			chips_lbl.text = "Chips: %d" % EconomyManager.get_chips()
		else:
			NotificationUI.notify_error("Not enough coins.")
	)
	vbox.add_child(buy)

	var cash := Button.new()
	cash.text = "Cash out 100 → 85 Ex-Coins"
	cash.pressed.connect(func():
		var ok: bool = EconomyManager.cashout_chips_to_ex_local(100)
		if ok:
			NotificationUI.notify_info("Cashed out.")
			chips_lbl.text = "Chips: %d" % EconomyManager.get_chips()
		else:
			NotificationUI.notify_error("Not enough chips.")
	)
	vbox.add_child(cash)
