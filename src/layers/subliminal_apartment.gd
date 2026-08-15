extends Node3D
## The Subliminal apartment — every player's start screen AND their UGC
## studio, a studio-flat-sized interior (SubliminalManager.APARTMENT_GRID
## slots on the floor). Walls close, lights low, the theme song playing:
## this is the one calm room in the whole cosmology.
##
## - Click a floor slot to cycle it through your unlocked entities as
##   placed BLUEPRINTS (EntityBlueprint forks — remix then submit later).
## - The side panel handles invites (3 outstanding max, creator sub
##   raises it) and shows your build's rarity line.

const SLOT_SIZE := 2.0

var _slots: Dictionary = {} # Vector2i -> MeshInstance3D
var _panel_status: Label

func _ready() -> void:
	var LayerManager = AutoloadGate.get_node("LayerManager")
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	LayerManager.current_layer_id = "subliminal"
	_build_room()
	_build_furniture()
	_build_camera()
	add_child(SensoriumAmbience.new())
	_build_panel()
	_build_door()
	SubliminalManager.apartment_updated.connect(_refresh_slots)
	_refresh_slots()

func _build_room() -> void:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var IdentityLens = AutoloadGate.get_node("IdentityLens")
	var grid: Vector2i = SubliminalManager.APARTMENT_GRID
	var w := grid.x * SLOT_SIZE
	var d := grid.y * SLOT_SIZE

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.6)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Floor — hard mesh, so even your own apartment is made of your race.
	var floor_mi := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(w + 2, 0.4, d + 2)
	floor_mi.mesh = floor_mesh
	floor_mi.position.y = -0.2
	floor_mi.material_override = IdentityLens.world_material(Color(0.35, 0.3, 0.4))
	add_child(floor_mi)

	# Walls — front, left, right. Back wall built in two pieces flanking
	# the exit door so the doorway is actually passable.
	var back_z := d / 2.0 + 1.0
	var door_w := 2.0
	var gap_half := door_w / 2.0 + 0.2  # frame clearance
	for wall in [
		{size=Vector3(w + 2, 4, 0.3), pos=Vector3(0, 2, -d / 2 - 1)},
		{size=Vector3(0.3, 4, d + 2), pos=Vector3(-w / 2 - 1, 2, 0)},
		{size=Vector3(0.3, 4, d + 2), pos=Vector3(w / 2 + 1, 2, 0)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = wall.size
		mi.mesh = box
		mi.position = wall.pos
		mi.material_override = IdentityLens.world_material(Color(0.25, 0.22, 0.3), 0.5)
		add_child(mi)

	# Back wall segments flanking the door
	var seg_w := (w + 2 - gap_half * 2.0) / 2.0
	for seg in [
		{size=Vector3(seg_w, 4, 0.3), pos=Vector3(-(gap_half + seg_w / 2.0), 2, back_z)},
		{size=Vector3(seg_w, 4, 0.3), pos=Vector3(+(gap_half + seg_w / 2.0), 2, back_z)},
	]:
		var mi2 := MeshInstance3D.new()
		var box2 := BoxMesh.new()
		box2.size = seg.size
		mi2.mesh = box2
		mi2.position = seg.pos
		mi2.material_override = IdentityLens.world_material(Color(0.25, 0.22, 0.3), 0.5)
		add_child(mi2)

	# One warm lamp — the calm room.
	var lamp := OmniLight3D.new()
	lamp.light_color = IdentityLens.sensorium().light
	lamp.light_energy = 1.4
	lamp.position = Vector3(0, 3.2, 0)
	add_child(lamp)

func _build_furniture() -> void:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var IdentityLens = AutoloadGate.get_node("IdentityLens")
	var grid: Vector2i = SubliminalManager.APARTMENT_GRID
	var w := grid.x * SLOT_SIZE
	var d := grid.y * SLOT_SIZE

	# ---- Rug — warm felt under the center of the room ----
	var rug := MeshInstance3D.new()
	var rug_mesh := PlaneMesh.new()
	rug_mesh.size = Vector2(w * 0.5, d * 0.4)
	rug.mesh = rug_mesh
	rug.position = Vector3(0, 0.03, 0)
	var rug_mat := StandardMaterial3D.new()
	rug_mat.albedo_color = Color(0.6, 0.35, 0.25)
	rug_mat.roughness = 0.9
	rug.material_override = rug_mat
	add_child(rug)

	# ---- Side table (left wall) ----
	var table_h := 1.2
	var table_x := -w / 2.0 + 1.8
	var table_z := -d / 2.0 + 1.5
	for part in [
		{size = Vector3(1.2, 0.08, 0.9), pos = Vector3(0, table_h, 0)},

		{size = Vector3(0.08, table_h, 0.08), pos = Vector3(-0.5, table_h / 2.0, -0.35)},
		{size = Vector3(0.08, table_h, 0.08), pos = Vector3(0.5, table_h / 2.0, -0.35)},
		{size = Vector3(0.08, table_h, 0.08), pos = Vector3(-0.5, table_h / 2.0, 0.35)},
		{size = Vector3(0.08, table_h, 0.08), pos = Vector3(0.5, table_h / 2.0, 0.35)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part.size
		mi.mesh = box
		mi.position = Vector3(table_x, 0, table_z) + part.pos
		mi.material_override = IdentityLens.world_material(Color(0.45, 0.35, 0.3), 0.3)
		add_child(mi)

	# ---- Small lamp on the table ----
	var table_lamp := OmniLight3D.new()
	table_lamp.light_color = Color(1.0, 0.8, 0.5)
	table_lamp.light_energy = 0.5
	table_lamp.omni_range = 4.0
	table_lamp.position = Vector3(table_x, table_h + 0.15, table_z)
	add_child(table_lamp)

	# ---- Wall art frame (right wall, a simple dark rectangle) ----
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.4, 0.9, 0.05)
	frame.mesh = frame_mesh
	frame.position = Vector3(w / 2.0 + 1.05, 1.8, d / 2.0 - 2.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.15, 0.12, 0.2)
	fmat.metallic = 0.6
	frame.material_override = fmat
	add_child(frame)

	# ---- Cushion / seating near the rug (simple box with warm fabric) ----
	var cushion := MeshInstance3D.new()
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(1.5, 0.35, 1.0)
	cushion.mesh = c_mesh
	cushion.position = Vector3(0, 0.2, d / 2.0 - 1.8)
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.5, 0.3, 0.4)
	c_mat.roughness = 0.85
	cushion.material_override = c_mat
	add_child(cushion)

	# Slot markers
	for x in range(grid.x):
		for y in range(grid.y):
			var slot := _make_slot(Vector2i(x, y), w, d)
			_slots[Vector2i(x, y)] = slot

func _make_slot(gpos: Vector2i, w: float, d: float) -> MeshInstance3D:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var grid: Vector2i = SubliminalManager.APARTMENT_GRID
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SLOT_SIZE * 0.85, SLOT_SIZE * 0.85)
	mi.mesh = plane
	mi.position = Vector3(
		(gpos.x - grid.x / 2.0 + 0.5) * SLOT_SIZE, 0.02,
		(gpos.y - grid.y / 2.0 + 0.5) * SLOT_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.55, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat

	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SLOT_SIZE * 0.85, 0.5, SLOT_SIZE * 0.85)
	cs.shape = box
	area.add_child(cs)
	area.input_ray_pickable = true
	area.input_event.connect(func(_cam, ev, _pos, _n, _i):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_cycle_slot(gpos))
	mi.add_child(area)
	add_child(mi)
	return mi

## Click cycles the slot: empty -> next unlocked entity blueprint -> empty.
func _cycle_slot(gpos: Vector2i) -> void:
	var CompanionSystem = AutoloadGate.get_node("CompanionSystem")
	var NotificationUI = AutoloadGate.get_node("NotificationUI")
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var key := "%d,%d" % [gpos.x, gpos.y]
	var unlocked: Array[String] = []
	for c in CompanionSystem.roster:
		if c.is_unlocked:
			unlocked.append(str(c.id))
	if unlocked.is_empty():
		NotificationUI.notify_info("Unlock entities first — every one of them is a blueprint waiting.")
		return
	var current: String = SubliminalManager.apartment_slots.get(key, {}).get("blueprint_id", "")
	var idx := unlocked.find(current)
	if idx == unlocked.size() - 1:
		SubliminalManager.clear_apartment_slot(gpos)
	else:
		SubliminalManager.place_in_apartment(gpos, unlocked[idx + 1])

func _refresh_slots() -> void:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var IdentityLens = AutoloadGate.get_node("IdentityLens")
	for gpos in _slots.keys():
		var slot: MeshInstance3D = _slots[gpos]
		for child in slot.get_children():
			if child.name == "Placed":
				child.queue_free()
		var key := "%d,%d" % [gpos.x, gpos.y]
		var placed: Dictionary = SubliminalManager.apartment_slots.get(key, {})
		if placed.is_empty():
			continue
		var bp := EntityBlueprint.fork(str(placed.get("blueprint_id", "")))
		var mi := MeshInstance3D.new()
		mi.name = "Placed"
		var caps := CapsuleMesh.new()
		caps.radius = 0.3
		caps.height = 1.0
		mi.mesh = caps
		mi.position.y = 0.6
		var ent := CompanionRegistry.get_by_id(str(placed.get("blueprint_id", "")))
		var profile := {"level": 1, "faction": ent.get("faction", ""), "alignment": "neutral",
			"stats": {"pow": ent.get("pow", 10)}}
		mi.material_override = IdentityLens.perceive_being(profile, Color(0.6, 0.6, 0.8)).material
		mi.set_meta("blueprint", bp)
		slot.add_child(mi)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 9, 11)
	cam.rotation_degrees = Vector3(-42, 0, 0)
	cam.current = true
	add_child(cam)

func _build_panel() -> void:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var IdentityLens = AutoloadGate.get_node("IdentityLens")
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(10, 10)
	box.custom_minimum_size = Vector2(320, 0)
	layer.add_child(box)

	var title := Label.new()
	title.text = "🚪 THE APARTMENT"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var rarity := Label.new()
	rarity.text = IdentityLens.rarity_text()
	rarity.modulate = Color(1.0, 0.85, 0.4)
	box.add_child(rarity)

	var hint := Label.new()
	hint.text = "Click floor slots to place your entities as blueprints."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.7, 0.7, 0.8)
	box.add_child(hint)

	_panel_status = Label.new()
	_panel_status.text = "Invites left: %d / %d" % [SubliminalManager.invites_left(), SubliminalManager.invite_cap()]
	box.add_child(_panel_status)

	var invite := Button.new()
	invite.text = "Send invite ✉️"
	invite.pressed.connect(func():
		var code = SubliminalManager.send_invite()
		if code != "":
			_panel_status.text = "Code %s — invites left: %d / %d" % [
				code, SubliminalManager.invites_left(), SubliminalManager.invite_cap()]
	)
	box.add_child(invite)

	if not SubliminalManager.is_creator():
		var sub := Button.new()
		sub.text = "Creator subscription (%d 🪙/30d)" % SubliminalManager.CREATOR_SUB_COINS
		sub.pressed.connect(func():
			if await SubliminalManager.buy_creator_subscription():
				_panel_status.text = "Creator active — invites left: %d / %d" % [
					SubliminalManager.invites_left(), SubliminalManager.invite_cap()]
				get_tree().reload_current_scene()
		)
		box.add_child(sub)

	var storage := Label.new()
	storage.text = "Locker: %d / %d" % [SubliminalManager.storage_used(), SubliminalManager.storage_capacity()]
	storage.modulate = Color(0.75, 0.85, 0.95)
	box.add_child(storage)
	var expand := Button.new()
	expand.text = "Expand locker (+%d for %d 🪙)" % [
		SubliminalManager.STORAGE_EXPANSION_SLOTS, SubliminalManager.STORAGE_EXPANSION_COINS]
	expand.pressed.connect(func():
		if await SubliminalManager.buy_storage_expansion():
			storage.text = "Locker: %d / %d" % [
				SubliminalManager.storage_used(), SubliminalManager.storage_capacity()]
	)
	box.add_child(expand)

	# Ambient figures are creator-paywalled — nothing auto-spawns here.
	if SubliminalManager.is_creator():
		var amb := Button.new()
		amb.text = "Place ambient figure (%d / %d)" % [
			SubliminalManager.ambient_npcs.size(), SubliminalManager.MAX_CREATOR_AMBIENT]
		amb.pressed.connect(func():
			var placed = SubliminalManager.place_ambient_npc("reflection")
			if not placed.is_empty():
				amb.text = "Place ambient figure (%d / %d)" % [
					SubliminalManager.ambient_npcs.size(), SubliminalManager.MAX_CREATOR_AMBIENT])
		box.add_child(amb)
	else:
		var locked := Label.new()
		locked.text = "Ambient figures: locked (Creator sub)"
		locked.modulate = Color(0.65, 0.55, 0.55)
		box.add_child(locked)

	# The door replaces "Step out" — walk through to the Metroplex.
	box.add_child(HSeparator.new())

	var forge := Button.new()
	forge.text = "🛠️ Blueprint Forge (B)"
	forge.pressed.connect(func():
		if get_node_or_null("BlueprintForge") == null:
			var f := BlueprintForgeUI.new()
			f.name = "BlueprintForge"
			add_child(f))
	box.add_child(forge)

	box.add_child(HSeparator.new())
	var tier_lbl := Label.new()
	var cur: Dictionary = SubliminalManager.current_tier()
	tier_lbl.text = "Space: %s (%d guests%s)" % [cur.name, cur.capacity,
		", public-capable" if cur.can_public else ""]
	tier_lbl.modulate = Color(0.8, 0.75, 1.0)
	box.add_child(tier_lbl)
	for t in SubliminalManager.TIERS:
		if t.id == cur.id or int(t.price) <= int(cur.price):
			continue
		var up := Button.new()
		up.text = "Upgrade: %s — %d 🪙 (%d guests)" % [t.name, t.price, t.capacity]
		up.tooltip_text = str(t.desc)
		up.pressed.connect(func():
			if await SubliminalManager.buy_tier(str(t.id)):
				get_tree().reload_current_scene()
		)
		box.add_child(up)
	if cur.can_public:
		var pub := CheckButton.new()
		pub.text = "Open to the public"
		pub.button_pressed = SubliminalManager.is_public
		pub.toggled.connect(func(on): SubliminalManager.set_public(on))
		box.add_child(pub)

## The one physical exit from the Subliminal: a door on the back wall that
## opens onto the DFW Metroplex. No menu, no layer picker — walk through it.
func _build_door() -> void:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var IdentityLens = AutoloadGate.get_node("IdentityLens")
	var grid: Vector2i = SubliminalManager.APARTMENT_GRID
	var d := grid.y * SLOT_SIZE
	var wall_z := d / 2.0 + 1.0
	var door_w := 2.0
	var door_h := 3.0

	# Door frame — two posts + header on the back wall.
	var frame_mat: Material = IdentityLens.world_material(Color(0.5, 0.42, 0.35), 0.7)
	for piece in [
		{size = Vector3(0.18, door_h, 0.3), pos = Vector3(-door_w / 2.0, door_h / 2.0, wall_z)},
		{size = Vector3(0.18, door_h, 0.3), pos = Vector3(door_w / 2.0, door_h / 2.0, wall_z)},
		{size = Vector3(door_w + 0.36, 0.18, 0.3), pos = Vector3(0.0, door_h, wall_z)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = piece.size
		mi.mesh = box
		mi.position = piece.pos
		mi.material_override = frame_mat
		add_child(mi)

	# Threshold glow — the luminous plane you step through.
	var threshold := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(door_w, door_h)
	threshold.mesh = plane
	threshold.position = Vector3(0.0, door_h / 2.0, wall_z - 0.1)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.6, 0.8, 1.0, 0.25)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.emission_enabled = true
	tmat.emission = Color(0.4, 0.6, 1.0)
	tmat.emission_energy_multiplier = 2.5
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	threshold.material_override = tmat
	add_child(threshold)

	# Label
	var lbl := Label3D.new()
	lbl.text = "THE METROPLEX"
	lbl.position = Vector3(0.0, door_h + 0.6, wall_z)
	lbl.font_size = 28
	lbl.modulate = Color(0.7, 0.8, 1.0)
	lbl.outline_size = 4
	add_child(lbl)

	# Walk-through trigger.
	var area := Area3D.new()
	area.name = "ExitDoor"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(door_w, door_h, 1.5)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(0.0, door_h / 2.0, wall_z)
	area.body_entered.connect(_on_door_entered)
	add_child(area)

func _on_door_entered(body: Node3D) -> void:
	if body is ThirdPersonController:
		var LayerManager = AutoloadGate.get_node("LayerManager")
		var NotificationUI = AutoloadGate.get_node("NotificationUI")
		NotificationUI.notify_info("The door opens onto the DFW Metroplex.")
		LayerManager.transition_to("supraliminal")
