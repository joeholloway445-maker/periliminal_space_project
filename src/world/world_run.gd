extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: Label = $HUD/Status
@onready var hope_lbl: Label = $HUD/HopeLine
@onready var env: WorldEnvironment = $WorldEnvironment

var spawned: Array = []
const ARCHETYPES := ["barista", "archivist", "authority", "lover", "reflection"]
const CITIES := ["dallas", "fort_worth", "denton", "arlington"]
var city_id: String = "dallas"

func _ready() -> void:
	Hope.spoke.connect(func(t): hope_lbl.text = "HOPE  " + t)
	hope_lbl.text = "HOPE  " + Hope.last_line
	LayerRouter.layer_changed.connect(func(_f, _t): _paint(); _rebuild_layer())
	CasinoBridge.ticket_ready.connect(func(t): Hope.say("Ticket %s opened." % str(t.get("ticket_id", ""))))
	CasinoBridge.settled.connect(func(r): Hope.say("Payout %s" % str(r.get("payout", 0))))
	VoteBridge.voted.connect(func(ok, _d): Hope.say("Vote stacked." if ok else "Vote bridge quiet."))
	_paint()
	_rebuild_layer()
	NakamaBridge.heartbeat()
	PersistBridge.push()

func _process(_d: float) -> void:
	var lens := OmniDexTables.compose(Session.sex, Session.race_id, Session.frame_id, Session.mod_id)
	hud.text = "%s/%s  |  %s  |  %s  |  coins %d chips %d frag %d tok %d chg %d pr %d  |  party %d/3  |  wander %.0f/%.0f" % [
		str(LayerRouter.info().get("name", LayerRouter.current)),
		city_id,
		lens.get("label", ""),
		Consistency.stance,
		Wallet.coins, Wallet.chips, Wallet.fragments, Wallet.tokens, Wallet.charges, Wallet.prestige,
		Party.bound.size(),
		LayerRouter.wander_s, LayerRouter.pull_threshold,
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_use()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				LayerRouter.enter("subliminal", "dev")
			KEY_2:
				LayerRouter.enter("liminal", "dev")
			KEY_3:
				LayerRouter.enter("supraliminal", "dev")
			KEY_4:
				LayerRouter.enter("hyperliminal", "dev")
			KEY_5:
				LayerRouter.enter("extraliminal", "dev")
			KEY_6:
				LayerRouter.enter("periliminal", "dev")
			KEY_H:
				Consistency.record_deed("help")
			KEY_G:
				Consistency.record_deed("attack")
			KEY_C:
				_casino()
			KEY_V:
				VoteBridge.cast("toe_spine_01", "sovereign_crown")
			KEY_N:
				city_id = CITIES[(CITIES.find(city_id) + 1) % CITIES.size()]
				if LayerRouter.current == "supraliminal":
					_rebuild_layer()
			KEY_P:
				PersistBridge.push()
				SupabaseBridge.sync_wallet()
				Hope.say("Snapshot sent.")

func _use() -> void:
	match LayerRouter.current:
		"subliminal":
			_go("liminal", "door")
		"liminal":
			_go("supraliminal", "arch")
		"supraliminal":
			_go("liminal", "hidden")
		"hyperliminal":
			_casino()
		"extraliminal":
			_go("liminal", "guild_door")
		"periliminal":
			LayerRouter.blessing_exit()
			DoorLog.log_door("periliminal", "subliminal", "blessing")
			PersistBridge.push()

func _go(layer_id: String, reason: String) -> void:
	var from := LayerRouter.current
	if LayerRouter.enter(layer_id, reason):
		DoorLog.log_door(from, layer_id, reason)

func _casino() -> void:
	if LayerRouter.current != "hyperliminal":
		LayerRouter.enter("hyperliminal", "dev")
	if Wallet.chips < 5:
		Wallet.coins_to_chips(20)
	CasinoBridge.request_ticket("slots", 5)

func _paint() -> void:
	var sky := env.environment
	if sky:
		sky.background_mode = Environment.BG_COLOR
		sky.background_color = LayerRouter.fog()
		sky.ambient_light_color = LayerRouter.fog().lightened(0.2)
		sky.fog_enabled = true
		sky.fog_light_color = LayerRouter.fog()

func _rebuild_layer() -> void:
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()
	_spawn_props()
	_spawn_population()
	_spawn_doors()

func _spawn_props() -> void:
	for i in range(8):
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 2.2, 1.4)
		mesh.mesh = box
		mesh.position = Vector3(sin(float(i) * 0.9) * 10.0, 1.1, cos(float(i) * 0.9) * 10.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = LayerRouter.fog().lightened(0.35)
		mesh.material_override = mat
		add_child(mesh)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.4, 2.2, 1.4)
		col.shape = shape
		body.add_child(col)
		mesh.add_child(body)
		spawned.append(mesh)

func _spawn_population() -> void:
	var crowd := 2
	match LayerRouter.current:
		"subliminal":
			crowd = 1
		"liminal":
			crowd = 2
		"supraliminal":
			crowd = 4
		"hyperliminal":
			crowd = 3
		"extraliminal":
			crowd = 3
		"periliminal":
			crowd = 1
	for i in range(crowd):
		var npc := CharacterBody3D.new()
		npc.set_script(load("res://src/world/ambient_npc.gd"))
		var arch: String = ARCHETYPES[i % ARCHETYPES.size()]
		add_child(npc)
		npc.call("setup", "npc_%s_%d" % [LayerRouter.current, i], arch, Vector3(4.0 + i * 1.6, 0.9, -3.0 + i))
		spawned.append(npc)
	var wild_n := 2 if LayerRouter.current != "subliminal" else 0
	if LayerRouter.current == "periliminal":
		wild_n = 3
	for i in range(wild_n):
		var ent := CharacterBody3D.new()
		ent.set_script(load("res://src/world/wild_entity.gd"))
		add_child(ent)
		var hp := 22
		if LayerRouter.current == "periliminal":
			hp = int(round(28.0 * Knoll.difficulty_mod()))
		ent.call("setup", "wild_%s_%d" % [LayerRouter.current, i], "Bound Shade", Vector3(-6.0 - i * 1.4, 0.6, 2.0 + i), hp)
		spawned.append(ent)

func _spawn_doors() -> void:
	var door_script = load("res://src/world/layer_door.gd")
	match LayerRouter.current:
		"subliminal":
			_add_door(door_script, "liminal", "door", Vector3(0, 1.5, -10), false)
		"liminal":
			_add_door(door_script, "supraliminal", "arch", Vector3(8, 1.5, -8), false)
			_add_door(door_script, "hyperliminal", "arch", Vector3(-8, 1.5, -8), false)
			_add_door(door_script, "extraliminal", "arch", Vector3(0, 1.5, 12), false)
		"supraliminal":
			_add_door(door_script, "liminal", "hidden", Vector3(-12, 1.5, 4), true)
		"hyperliminal":
			_add_door(door_script, "liminal", "ui", Vector3(0, 1.5, 12), false)
		"extraliminal":
			_add_door(door_script, "liminal", "guild_door", Vector3(0, 1.5, 12), false)
		"periliminal":
			_add_door(door_script, "subliminal", "blessing", Vector3(0, 1.5, -12), false)

func _add_door(script, to_layer: String, kind: String, pos: Vector3, hidden: bool) -> void:
	var d = Area3D.new()
	d.set_script(script)
	add_child(d)
	d.call("setup", to_layer, kind, pos, hidden)
	spawned.append(d)
