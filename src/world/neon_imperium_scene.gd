extends Node3D
class_name NeonImperiumScene
## The Hyperliminal — a walled casino city where the streets are never safe.
## Seven districts of vice, each building a safe interior you can walk into.
## Entry costs chips. Exit requires reaching a Liminal archway on the rim.
## Nothing teleports. Everything is walked.

# ─── City dimensions ──────────────────────────────────────────────────────────
const CITY_HALF := 140.0
const WALL_H := 10.0
const BLOCK := 28.0
const STREET := 12.0
const CELL := BLOCK + STREET  # 40.0

# ─── District definitions ─────────────────────────────────────────────────────
const DISTRICTS: Array[Dictionary] = [
	{name = "The Promenade",        center = Vector2(0, 2),     color = Color(0.9, 0.8, 0.3)},
	{name = "Card Hall",            center = Vector2(2, 1),     color = Color(0.2, 0.7, 0.3)},
	{name = "The Wheelhouse",       center = Vector2(1, 0),     color = Color(0.8, 0.3, 0.2)},
	{name = "Slot Alley",           center = Vector2(0, 1),     color = Color(0.9, 0.2, 0.8)},
	{name = "High Roller's Terrace",center = Vector2(2, 0),     color = Color(0.9, 0.7, 0.1)},
	{name = "The Pit",              center = Vector2(1, 2),     color = Color(0.7, 0.1, 0.1)},
	{name = "Neon Bazaar",          center = Vector2(0, 0),     color = Color(0.2, 0.6, 0.9)},
]

# Maps district name → list of {name, scene_path, pos_offset} casino interiors.
const CASINO_INTERIORS: Dictionary = {
	"The Promenade": [
		{name = "Chip Cage",       scene = "", pos = Vector3(0, 0, 4)},
		{name = "Low-Stakes Slots",scene = "res://scenes/games/slots/slot_machine.tscn", pos = Vector3(-6, 0, 4)},
		{name = "Scratch Kiosk",   scene = "res://scenes/games/arcade/scratch_card.tscn", pos = Vector3(6, 0, 4)},
	],
	"Card Hall": [
		{name = "Blackjack",       scene = "res://scenes/games/arcade/blackjack.tscn", pos = Vector3(-5, 0, -4)},
		{name = "Poker Room",      scene = "res://scenes/games/arcade/paw_poker.tscn", pos = Vector3(0, 0, -4)},
		{name = "Hold'em Lounge",  scene = "res://scenes/games/arcade/holdem.tscn", pos = Vector3(5, 0, -4)},
	],
	"The Wheelhouse": [
		{name = "Fortune Wheel",   scene = "res://scenes/games/arcade/fortune_wheel.tscn", pos = Vector3(-4, 0, 5)},
		{name = "Coin Pusher",     scene = "res://scenes/games/arcade/coin_pusher.tscn", pos = Vector3(4, 0, 5)},
	],
	"Slot Alley": [
		{name = "Slots Row A",     scene = "res://scenes/games/slots/slot_machine.tscn", pos = Vector3(-8, 0, -6)},
		{name = "Slots Row B",     scene = "res://scenes/games/slots/slot_machine.tscn", pos = Vector3(0, 0, -6)},
		{name = "Slots Row C",     scene = "res://scenes/games/slots/slot_machine.tscn", pos = Vector3(8, 0, -6)},
	],
	"High Roller's Terrace": [
		{name = "VIP Blackjack",   scene = "res://scenes/games/arcade/blackjack.tscn", pos = Vector3(-4, 0, 0)},
		{name = "VIP Poker",       scene = "res://scenes/games/arcade/holdem.tscn", pos = Vector3(4, 0, 0)},
	],
	"The Pit": [
		{name = "Combat Pit",      scene = "", pos = Vector3(0, 0, 0)},
	],
	"Neon Bazaar": [
		{name = "Trade Post",      scene = "", pos = Vector3(0, 0, -5)},
	],
}

# ─── Runtime state ────────────────────────────────────────────────────────────
var _safe_buildings: Array[Node3D] = []
var _entry_spawns: Array[Vector3] = []
var _exit_archways: Array[Area3D] = []
var _street_creatures: Array[Node3D] = []
var _player_in_safe_zone: bool = false

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	var LayerManager = AutoloadGate.get_node("LayerManager")
	LayerManager.current_layer_id = "hyperliminal"
	_build_ground()
	_build_city_walls()
	_build_street_grid()
	_place_district_buildings()
	_place_entry_spawns()
	_place_exit_archways()
	_spawn_street_creatures()
	_add_chip_cage_ui()
	_add_player_warning()

func _process(_delta: float) -> void:
	_update_safe_zone_check()
	var canvas := get_node_or_null("ImperiumHUD") as CanvasLayer
	if canvas == null:
		return
	var indicator := canvas.get_node_or_null("SafeIndicator") as Label
	if indicator == null:
		return
	indicator.visible = _player_in_safe_zone

# ─── Ground ───────────────────────────────────────────────────────────────────
func _build_ground() -> void:
	var terrain: Node = TerrainBridge.new()
	terrain.name = "Terrain"
	add_child(terrain)
	if terrain.has_method("ensure_built"):
		await terrain.ensure_built("hyperliminal")

	# Dark asphalt under the city
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CITY_HALF * 2.5, CITY_HALF * 2.5)
	ground.mesh = plane
	ground.position.y = 0.01
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.08, 0.08, 0.1)
	ground.material_override = gmat
	add_child(ground)

	# Ambient city light
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.01, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.2, 0.4)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)

	var dir_light := DirectionalLight3D.new()
	dir_light.position = Vector3(0, 30, 0)
	dir_light.light_color = Color(0.6, 0.5, 0.8)
	dir_light.light_energy = 0.4
	add_child(dir_light)

# ─── City walls ───────────────────────────────────────────────────────────────
func _build_city_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.15, 0.12, 0.18)
	var hw := CITY_HALF

	for wall in [
		{size = Vector3(hw * 2 + 4, WALL_H, 1.5), pos = Vector3(0, WALL_H / 2.0, -hw)},
		{size = Vector3(hw * 2 + 4, WALL_H, 1.5), pos = Vector3(0, WALL_H / 2.0, hw)},
		{size = Vector3(1.5, WALL_H, hw * 2 + 4), pos = Vector3(-hw, WALL_H / 2.0, 0)},
		{size = Vector3(1.5, WALL_H, hw * 2 + 4), pos = Vector3(hw, WALL_H / 2.0, 0)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = wall.size
		mi.mesh = box
		mi.position = wall.pos
		mi.material_override = wall_mat
		add_child(mi)

	# Wall-top neon — glows around the perimeter
	var neon_mat := StandardMaterial3D.new()
	neon_mat.albedo_color = Color(0.8, 0.2, 0.9)
	neon_mat.emission_enabled = true
	neon_mat.emission = Color(0.8, 0.2, 0.9)
	neon_mat.emission_energy_multiplier = 4.0
	for nz in [-hw, hw]:
		var n := MeshInstance3D.new()
		var nb := BoxMesh.new()
		nb.size = Vector3(hw * 2 + 2, 0.2, 0.2)
		n.mesh = nb
		n.position = Vector3(0, WALL_H - 0.1, nz)
		n.material_override = neon_mat
		add_child(n)

# ─── Street grid ──────────────────────────────────────────────────────────────
func _build_street_grid() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.06, 0.06, 0.08)
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.7, 0.7, 0.75)
	line_mat.emission_enabled = true
	line_mat.emission = Color(0.3, 0.3, 0.4)
	line_mat.emission_energy_multiplier = 1.5

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("neon_imperium_streets")
	var grid_radius := int(CITY_HALF / CELL)

	for gi in range(-grid_radius, grid_radius + 1):
		for gj in range(-grid_radius, grid_radius + 1):
			var cx := gi * CELL
			var cz := gj * CELL
			var bldg_w := BLOCK * (0.6 + rng.randf() * 0.35)
			var bldg_d := BLOCK * (0.6 + rng.randf() * 0.35)

			# Building pad — dark concrete
			var pad := MeshInstance3D.new()
			var pad_mesh := BoxMesh.new()
			pad_mesh.size = Vector3(bldg_w, 0.15, bldg_d)
			pad.mesh = pad_mesh
			pad.position = Vector3(cx, 0.08, cz)
			pad.material_override = road_mat
			add_child(pad)

			# Street lane markers — dashed lines between blocks
			if gi < grid_radius:
				var seg_count := int(bldg_d / 4.0)
				for s in range(seg_count):
					var lane := MeshInstance3D.new()
					var lb := BoxMesh.new()
					lb.size = Vector3(0.15, 0.02, 1.5)
					lane.mesh = lb
					lane.position = Vector3(cx + CELL / 2.0, 0.16, cz - bldg_d / 2.0 + s * 4.0 + 2.0)
					lane.material_override = line_mat
					add_child(lane)

	# Cross-street neon lamps at intersections
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.9, 0.3, 0.7)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(0.9, 0.3, 0.7)
	lamp_mat.emission_energy_multiplier = 3.0
	for gi in range(-grid_radius, grid_radius + 1):
		for gj in range(-grid_radius, grid_radius + 1):
			var lp := Vector3(gi * CELL + CELL / 2.0, 4.0, gj * CELL + CELL / 2.0)
			var post := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(0.2, 3.5, 0.2)
			post.mesh = pb
			post.position = Vector3(lp.x, 1.75, lp.z)
			post.material_override = lamp_mat
			add_child(post)
			var bulb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.35
			sphere.height = 0.7
			bulb.mesh = sphere
			bulb.position = Vector3(lp.x, 3.9, lp.z)
			bulb.material_override = lamp_mat
			add_child(bulb)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(lp.x, 3.8, lp.z)
			lamp.light_color = Color(0.9, 0.4, 0.8)
			lamp.light_energy = 2.0
			lamp.omni_range = 14.0
			add_child(lamp)

# ─── District buildings — casino interiors ─────────────────────────────────────
func _place_district_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("neon_imperium_districts")

	for dist in DISTRICTS:
		var name: String = dist.name
		var center: Vector2 = dist.center
		var interiors: Array = CASINO_INTERIORS.get(name, [])

		# Place buildings around the district center
		for i in range(interiors.size() + rng.randi_range(1, 3)):
			var angle := rng.randf() * TAU
			var dist_r := rng.randf_range(CELL * 0.6, CELL * 2.5)
			var bx := center.x * CELL + cos(angle) * dist_r
			var bz := center.y * CELL + sin(angle) * dist_r

			# Building shell
			var bh := rng.randf_range(6.0, 14.0)
			var bw := rng.randf_range(6.0, 14.0)
			var bd := rng.randf_range(6.0, 14.0)
			var shell := MeshInstance3D.new()
			var shell_mesh := BoxMesh.new()
			shell_mesh.size = Vector3(bw, bh, bd)
			shell.mesh = shell_mesh
			shell.position = Vector3(bx, bh / 2.0, bz)

			var shell_mat := StandardMaterial3D.new()
			shell_mat.albedo_color = Color(0.12, 0.1, 0.16)
			shell.material_override = shell_mat
			add_child(shell)

			# District-color neon strip at building top
			var neon := MeshInstance3D.new()
			var nb := BoxMesh.new()
			nb.size = Vector3(bw + 0.3, 0.15, 0.15)
			neon.mesh = nb
			neon.position = Vector3(bx, bh - 0.15, bz + bd / 2.0 + 0.15)
			var nmat := StandardMaterial3D.new()
			nmat.albedo_color = dist.color
			nmat.emission_enabled = true
			nmat.emission = dist.color
			nmat.emission_energy_multiplier = 3.0
			neon.material_override = nmat
			add_child(neon)

			# District label
			var lbl := Label3D.new()
			lbl.text = name
			lbl.position = Vector3(bx, bh + 1.2, bz)
			lbl.font_size = 20
			lbl.modulate = dist.color
			lbl.outline_size = 4
			add_child(lbl)

		# Place casino interior entrances (safe zones)
		for int_spec in interiors:
			var pos := Vector3(center.x * CELL + int_spec.pos.x, 0, center.y * CELL - int_spec.pos.z)
			# Entrance building — smaller, with a glowing door
			var ent := _build_safe_entrance(int_spec.name, pos, int_spec.scene, dist.color)
			_safe_buildings.append(ent)

# ─── Safe entrance builder ────────────────────────────────────────────────────
func _build_safe_entrance(name_str: String, world_pos: Vector3, scene_path: String, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name_str
	root.position = world_pos

	# Small building
	var bw := 6.0
	var bh := 5.0
	var bd := 6.0
	var shell := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(bw, bh, bd)
	shell.mesh = sm
	shell.position.y = bh / 2.0
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.08, 0.07, 0.12)
	shell.material_override = shell_mat
	root.add_child(shell)

	# Glowing door frame on the south face
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = accent
	frame_mat.emission_enabled = true
	frame_mat.emission = accent
	frame_mat.emission_energy_multiplier = 2.5
	for piece in [
		{size = Vector3(0.2, 3.0, 0.2), pos = Vector3(-1.0, 1.5, -bd / 2.0)},
		{size = Vector3(0.2, 3.0, 0.2), pos = Vector3(1.0, 1.5, -bd / 2.0)},
		{size = Vector3(2.4, 0.2, 0.2), pos = Vector3(0.0, 3.0, -bd / 2.0)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = piece.size
		mi.mesh = box
		mi.position = piece.pos
		mi.material_override = frame_mat
		root.add_child(mi)

	# Door glow plane
	var glow := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(2.0, 3.0)
	glow.mesh = gp
	glow.position = Vector3(0, 1.5, -bd / 2.0 + 0.15)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(accent.r, accent.g, accent.b, 0.25)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.emission_enabled = true
	gmat.emission = accent
	gmat.emission_energy_multiplier = 2.0
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.material_override = gmat
	root.add_child(glow)

	# Label
	var lbl := Label3D.new()
	lbl.text = name_str
	lbl.position = Vector3(0, 3.8, -bd / 2.0 - 0.2)
	lbl.font_size = 16
	lbl.modulate = accent
	lbl.outline_size = 3
	root.add_child(lbl)

	# Safe zone trigger — Area3D that marks this as safe
	var safe_area := Area3D.new()
	safe_area.name = "SafeZone"
	var cs := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(bw + 1, bh, bd + 1)
	cs.shape = cbox
	safe_area.add_child(cs)
	safe_area.position.y = bh / 2.0
	safe_area.body_entered.connect(_on_enter_safe_zone)
	safe_area.body_exited.connect(_on_exit_safe_zone)

	# Entrance trigger — smaller, for the actual door
	var door_area := Area3D.new()
	door_area.name = "DoorTrigger"
	var dcs := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(2.0, 3.0, 2.0)
	dcs.shape = dbox
	door_area.add_child(dcs)
	door_area.position = Vector3(0, 1.5, -bd / 2.0 - 1.5)
	door_area.body_entered.connect(func(body: Node3D):
		if body is ThirdPersonController and scene_path != "":
			if ResourceLoader.exists(scene_path):
				body.set_meta("neon_imperium_return_pos", body.global_position)
				get_tree().change_scene_to_file(scene_path)
	)
	root.add_child(door_area)

	root.add_child(safe_area)
	add_child(root)
	return root

func _on_enter_safe_zone(_body: Node3D) -> void:
	_player_in_safe_zone = true

func _on_exit_safe_zone(_body: Node3D) -> void:
	_player_in_safe_zone = false

func _update_safe_zone_check() -> void:
	# Refresh safe-zone state each frame — creatures check this
	pass

func is_player_in_safe_zone() -> bool:
	return _player_in_safe_zone

# ─── Entry spawns (from Liminal archways) ─────────────────────────────────────
func _place_entry_spawns() -> void:
	# Players arriving from Liminal spawn at one of these points on the
	# outer rim — deliberately far from any safe building.
	var hw := CITY_HALF - 10.0
	_entry_spawns = [
		Vector3(-hw, 0.5, -hw),
		Vector3(hw, 0.5, -hw),
		Vector3(-hw, 0.5, hw),
		Vector3(hw, 0.5, hw),
		Vector3(0, 0.5, -hw),
		Vector3(0, 0.5, hw),
		Vector3(-hw, 0.5, 0),
		Vector3(hw, 0.5, 0),
	]

	# Spawn the player at a random entry point
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	var spawn := _entry_spawns[rng.randi() % _entry_spawns.size()]
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.global_position = spawn
	else:
		# Fallback: find ThirdPersonController
		for c in get_tree().get_nodes_in_group("player"):
			if c is ThirdPersonController:
				c.global_position = spawn
				break

	# Spawn markers — glowing pillars visible from the streets
	for sp in _entry_spawns:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.4, 5.0, 0.4)
		pillar.mesh = pm
		pillar.position = sp + Vector3(0, 2.5, 0)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.3, 0.8, 0.9)
		pmat.emission_enabled = true
		pmat.emission = Color(0.3, 0.8, 0.9)
		pmat.emission_energy_multiplier = 2.0
		pillar.material_override = pmat
		add_child(pillar)

		var elbl := Label3D.new()
		elbl.text = "ENTRY"
		elbl.position = sp + Vector3(0, 5.5, 0)
		elbl.font_size = 14
		elbl.modulate = Color(0.3, 0.9, 1.0)
		add_child(elbl)

# ─── Exit archways (back to Liminal) ──────────────────────────────────────────
func _place_exit_archways() -> void:
	# Liminal archways on the outer wall — these are the ONLY way out.
	var hw := CITY_HALF + 1.0
	var exits := [
		Vector3(-hw, 0, 0),
		Vector3(hw, 0, 0),
		Vector3(0, 0, -hw),
		Vector3(0, 0, hw),
	]
	for ep in exits:
		var arch := LayerExitDoor.new()
		arch.target_layer = "liminal"
		arch.position = ep + Vector3(0, 0.5, 0)
		arch.blessing = false
		add_child(arch)

		# Label
		var al := Label3D.new()
		al.text = "RETURN TO LIMINAL"
		al.position = ep + Vector3(0, 4.5, 0)
		al.font_size = 16
		al.modulate = Color(0.5, 0.8, 1.0)
		al.outline_size = 4
		add_child(al)

# ─── Street creatures ─────────────────────────────────────────────────────────
func _spawn_street_creatures() -> void:
	# PVXC-style creatures roam the streets — they ignore safe zones.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("neon_imperium_creatures")
	for i in range(30):
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(20.0, CITY_HALF - 5.0)
		var cx := cos(angle) * dist
		var cz := sin(angle) * dist
		var creature := _make_street_creature(i, Vector3(cx, 0.5, cz), rng)
		add_child(creature)
		_street_creatures.append(creature)

func _make_street_creature(index: int, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "StreetCreature_%d" % index
	root.position = pos

	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	mi.mesh = capsule
	mi.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(rng.randf(), 0.7, 0.7)
	mat.emission_enabled = true
	mat.emission = Color.from_hsv(rng.randf(), 0.7, 0.7)
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	root.add_child(mi)

	var area := Area3D.new()
	area.name = "AggroZone"
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 8.0
	cs.shape = sphere
	area.add_child(cs)
	root.add_child(area)

	root.set_meta("hp", 60 + rng.randi() % 80)
	root.set_meta("damage", 5 + rng.randi() % 15)
	root.set_meta("aggro_range", 10.0 + rng.randf() * 8.0)
	return root

# ─── UI ────────────────────────────────────────────────────────────────────────
func _add_chip_cage_ui() -> void:
	var EconomyManager = AutoloadGate.get_node("EconomyManager")
	var NotificationUI = AutoloadGate.get_node("NotificationUI")
	var canvas := CanvasLayer.new()
	canvas.name = "ImperiumHUD"
	add_child(canvas)

	# Chip balance — top right
	var balance := Label.new()
	balance.name = "ChipBalance"
	balance.text = "Chips: %d" % EconomyManager.get_chips()
	balance.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	balance.offset_left = -200
	balance.offset_top = 10
	balance.offset_right = -10
	balance.add_theme_font_size_override("font_size", 20)
	balance.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	canvas.add_child(balance)

	# Buy chips button
	var buy := Button.new()
	buy.text = "Buy Chips"
	buy.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	buy.offset_left = -200
	buy.offset_top = 50
	buy.offset_right = -10
	buy.offset_bottom = 80
	buy.pressed.connect(func():
		var ok: bool = EconomyManager.buy_chips_local(100)
		if ok:
			NotificationUI.notify_info("Bought 100 chips.")
			balance.text = "Chips: %d" % EconomyManager.get_chips()
		else:
			NotificationUI.notify_error("Not enough coins.")
	)
	canvas.add_child(buy)

	# Safe zone indicator — shown when inside a casino building
	var safe_indicator := Label.new()
	safe_indicator.name = "SafeIndicator"
	safe_indicator.text = "SAFE ZONE"
	safe_indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	safe_indicator.offset_top = 10
	safe_indicator.add_theme_font_size_override("font_size", 16)
	safe_indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	safe_indicator.visible = false
	canvas.add_child(safe_indicator)

	# Back to Liminal — fallback button at the edge (costs extra)
	var flee := Button.new()
	flee.text = "Flee (50 chips)"
	flee.position = Vector2(10, 10)
	flee.pressed.connect(func():
		if EconomyManager.get_chips() < 50:
			NotificationUI.notify_error("Need 50 chips to flee.")
			return
		EconomyManager.spend_currency_local("chips", 50, "imperium_flee")
		var LayerManager = AutoloadGate.get_node("LayerManager")
		LayerManager.transition_to("liminal", true)
	)
	canvas.add_child(flee)

func _add_player_warning() -> void:
	var NotificationUI = AutoloadGate.get_node("NotificationUI")
	NotificationUI.notify_info("The streets are not safe. Find a casino door — they glow.")
