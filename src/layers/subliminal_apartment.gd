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
	LayerManager.current_layer_id = "subliminal"
	_build_room()
	_build_camera()
	add_child(SensoriumAmbience.new())
	_build_panel()
	_build_mode_selector()
	SubliminalManager.apartment_updated.connect(_refresh_slots)
	_refresh_slots()

func _build_room() -> void:
	var grid: Vector2i = SubliminalManager.APARTMENT_GRID
	var w := grid.x * SLOT_SIZE
	var d := grid.y * SLOT_SIZE

	# ── Floor with subtle emissive glow ──
	var floor_mi := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(w + 2, 0.4, d + 2)
	floor_mi.mesh = floor_mesh
	floor_mi.position.y = -0.2
	var floor_mat: StandardMaterial3D = IdentityLens.world_material(Color(0.35, 0.3, 0.4))
	floor_mat.metallic = 0.15
	floor_mat.roughness = 0.6
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.15, 0.1, 0.25)
	floor_mat.emission_energy_multiplier = 0.25
	floor_mi.material_override = floor_mat
	add_child(floor_mi)

	# ── Walls with subtle rim glow ──
	for wall in [
		{size=Vector3(w + 2, 4.5, 0.4), pos=Vector3(0, 2.25, -d / 2 - 1)},
		{size=Vector3(w + 2, 4.5, 0.4), pos=Vector3(0, 2.25, d / 2 + 1)},
		{size=Vector3(0.4, 4.5, d + 2), pos=Vector3(-w / 2 - 1, 2.25, 0)},
		{size=Vector3(0.4, 4.5, d + 2), pos=Vector3(w / 2 + 1, 2.25, 0)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = wall.size
		mi.mesh = box
		mi.position = wall.pos
		var wall_mat: StandardMaterial3D = IdentityLens.world_material(Color(0.2, 0.18, 0.28), 0.5)
		wall_mat.metallic = 0.05
		wall_mat.roughness = 0.7
		wall_mat.emission_enabled = true
		wall_mat.emission = Color(0.05, 0.03, 0.12)
		wall_mat.emission_energy_multiplier = 0.15
		mi.material_override = wall_mat
		add_child(mi)

	# Slot markers
	for x in range(grid.x):
		for y in range(grid.y):
			var slot := _make_slot(Vector2i(x, y))
			_slots[Vector2i(x, y)] = slot

func _make_slot(gpos: Vector2i) -> MeshInstance3D:
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
	# Cinematic 3/4 view: show the room, the floor grid, AND the player
	cam.position = Vector3(4.5, 3.2, 5.5)
	cam.current = true
	cam.far = 30.0
	cam.near = 0.1
	add_child(cam)
	cam.look_at(Vector3(0, 0.8, 0))

func _build_panel() -> void:
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
		var code := SubliminalManager.send_invite()
		if code != "":
			_panel_status.text = "Code %s — invites left: %d / %d" % [
				code, SubliminalManager.invites_left(), SubliminalManager.invite_cap()])
	box.add_child(invite)

	if not SubliminalManager.is_creator():
		var sub := Button.new()
		sub.text = "Creator subscription (%d 🪙/30d)" % SubliminalManager.CREATOR_SUB_COINS
		sub.pressed.connect(func():
			if await SubliminalManager.buy_creator_subscription():
				_panel_status.text = "Creator active — invites left: %d / %d" % [SubliminalManager.invites_left(), SubliminalManager.invite_cap()]
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
				SubliminalManager.storage_used(), SubliminalManager.storage_capacity()])
	box.add_child(expand)

	# Ambient figures are creator-paywalled — nothing auto-spawns here.
	if SubliminalManager.is_creator():
		var amb := Button.new()
		amb.text = "Place ambient figure (%d / %d)" % [
			SubliminalManager.ambient_npcs.size(), SubliminalManager.MAX_CREATOR_AMBIENT]
		amb.pressed.connect(func():
			var placed := SubliminalManager.place_ambient_npc("reflection")
			if not placed.is_empty():
				amb.text = "Place ambient figure (%d / %d)" % [
					SubliminalManager.ambient_npcs.size(), SubliminalManager.MAX_CREATOR_AMBIENT])
		box.add_child(amb)
	else:
		var locked := Label.new()
		locked.text = "Ambient figures: locked (Creator sub)"
		locked.modulate = Color(0.65, 0.55, 0.55)
		box.add_child(locked)

	var leave := Button.new()
	leave.text = "⬅ Step out"
	leave.pressed.connect(func(): LayerManager.transition_to("hyperliminal"))
	box.add_child(leave)

## The mode selector — the Subliminal IS the start screen, every session.
## From your calm room you step into any of the six realities (entry rules
## enforced by LayerManager; the Periliminal shows but never opens — it
## takes you, you don't take it). The casino is one door of six.
func _show_saved_rooms_preview(box: VBoxContainer) -> void:
	## Show up to 3 saved rooms + an "Open Gallery" button.
	var rooms: Array = SubliminalManager.saved_rooms
	if rooms.is_empty():
		var empty := Label.new()
		empty.text = "No saved rooms yet — save one from any door."
		empty.modulate = Color(0.5, 0.5, 0.55)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(empty)
		return

	# Show up to 3 entries
	var count := mini(rooms.size(), 3)
	for i in range(count):
		var entry: Dictionary = rooms[i]
		var rid: String = str(entry.get("room_id", ""))
		var label: String = str(entry.get("label", "Room " + rid.left(6)))
		var author_rfm: Dictionary = entry.get("author_rfm", {})
		var alignment: String = str(author_rfm.get("alignment", "neutral"))

		var h := HBoxContainer.new()
		var color := Color(0.6, 0.6, 0.8)
		match alignment:
			"just":    color = Color(0.4, 0.7, 0.9)
			"wild":    color = Color(0.85, 0.5, 0.3)
			"void":    color = Color(0.6, 0.3, 0.8)
			"current": color = Color(0.3, 0.8, 0.7)
		var indicator := ColorRect.new()
		indicator.color = color
		indicator.custom_minimum_size = Vector2(8, 24)
		h.add_child(indicator)

		var name_lbl := Label.new()
		name_lbl.text = label
		name_lbl.custom_minimum_size = Vector2(120, 24)
		h.add_child(name_lbl)

		var enter_btn := Button.new()
		enter_btn.text = "Enter"
		enter_btn.pressed.connect(func(): SubliminalManager.enter_saved_room(rid))
		h.add_child(enter_btn)

		var remove_btn := Button.new()
		remove_btn.text = "X"
		remove_btn.modulate = Color(0.7, 0.3, 0.3)
		remove_btn.pressed.connect(func():
			SubliminalManager.remove_saved_room(rid)
			NotificationUI.notify_info("Room removed from saved list."))
		h.add_child(remove_btn)

		box.add_child(h)

	if rooms.size() > 3:
		var more := Label.new()
		more.text = "... +%d more saved rooms" % (rooms.size() - 3)
		more.modulate = Color(0.5, 0.5, 0.6)
		box.add_child(more)

func _build_mode_selector() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.position += Vector2(-360, 0)
	panel.custom_minimum_size = Vector2(340, 0)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 600)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	scroll.add_child(box)

	var title := Label.new()
	title.text = "%s's SUBLIMINAL" % PlayerProfile.username.to_upper()
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	# ── Play Mode ──────────────────────────────────────────────────────────
	var mode_lbl := Label.new()
	mode_lbl.text = "PLAY MODE (Superliminal rules)"
	mode_lbl.modulate = Color(0.7, 0.6, 0.9)
	box.add_child(mode_lbl)

	var creative_btn := Button.new()
	var has_creative_access := PlayerProfile.is_god_mode()
	creative_btn.text = "🎨 Creative / God Sandbox"
	creative_btn.tooltip_text = "Full creative access, no restrictions. Requires Creator Pack or testing mode."
	creative_btn.disabled = not has_creative_access
	creative_btn.pressed.connect(func(): _set_mode("creative"))
	box.add_child(creative_btn)

	var ai_aware := Button.new()
	ai_aware.text = "🤖 AI Aware Normal"
	ai_aware.tooltip_text = "Standard play: NPCs and systems recognize you as a player. The world knows you're here."
	ai_aware.pressed.connect(func(): _set_mode("ai_aware"))
	box.add_child(ai_aware)

	var ai_unaware := Button.new()
	ai_unaware.text = "👤 AI Unaware Normal"
	ai_unaware.tooltip_text = "Hardcore: the world treats you as part of the environment. No special treatment."
	ai_unaware.pressed.connect(func(): _set_mode("ai_unaware"))
	box.add_child(ai_unaware)

	# ── Travel ─────────────────────────────────────────────────────────────
	box.add_child(HSeparator.new())
	var travel_lbl := Label.new()
	travel_lbl.text = "TRAVEL"
	travel_lbl.modulate = Color(0.6, 0.7, 1.0)
	box.add_child(travel_lbl)

	for l in RealityLayers.LAYERS:
		if l.id == "subliminal":
			continue
		var btn := Button.new()
		btn.text = str(l.name)
		btn.tooltip_text = str(l.desc)
		var gate := LayerManager.can_enter(str(l.id))
		if not bool(gate.get("ok", true)):
			btn.disabled = true
			btn.text += "  (%s)" % str(gate.get("reason", "locked"))
		btn.pressed.connect(func(lid := l.id): LayerManager.transition_to(lid))
		box.add_child(btn)

	# ── Studio Utilities ───────────────────────────────────────────────────
	box.add_child(HSeparator.new())
	var util_lbl := Label.new()
	util_lbl.text = "STUDIO"
	util_lbl.modulate = Color(0.9, 0.75, 0.6)
	box.add_child(util_lbl)

	var wardrobe := Button.new()
	wardrobe.text = "👔 Wardrobe"
	wardrobe.tooltip_text = "Change your look: race, frame, outfit, accessories."
	wardrobe.pressed.connect(_open_wardrobe)
	box.add_child(wardrobe)

	var repair := Button.new()
	repair.text = "🔧 Repair Station"
	repair.tooltip_text = "Fix worn gear and equipment."
	repair.pressed.connect(_open_repair_station)
	box.add_child(repair)

	var storage := Button.new()
	storage.text = "📦 Storage Vault"
	storage.tooltip_text = "Store gear, weapons, and entities."
	storage.pressed.connect(_open_storage_vault)
	box.add_child(storage)

	var has_creator := has_creative_access or PlayerProfile.is_god_mode()
	var creation := Button.new()
	creation.text = "⚒️ Creation Station"
	creation.tooltip_text = "Build custom content. Requires Creator Pack."
	creation.disabled = not has_creator
	creation.pressed.connect(_open_creation_station)
	box.add_child(creation)

	box.add_child(HSeparator.new())

	var forge := Button.new()
	forge.text = "🛠️ Blueprint Forge (B)"
	forge.pressed.connect(func():
		if get_node_or_null("BlueprintForge") == null:
			var f := BlueprintForgeUI.new()
			f.name = "BlueprintForge"
			add_child(f))
	box.add_child(forge)

	# ── Tier shop ──────────────────────────────────────────────────────────
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
				get_tree().reload_current_scene())
		box.add_child(up)
	if cur.can_public:
		var pub := CheckButton.new()
		pub.text = "Open to the public"
		pub.button_pressed = SubliminalManager.is_public
		pub.toggled.connect(func(on): SubliminalManager.set_public(on))
		box.add_child(pub)

	# ── Saved room gallery ──────────────────────────────────────────────────
	box.add_child(HSeparator.new())
	var saved_label := Label.new()
	saved_label.text = "Saved Rooms (%d)" % SubliminalManager.saved_rooms.size()
	saved_label.modulate = Color(0.75, 0.6, 0.9)
	box.add_child(saved_label)
	_show_saved_rooms_preview(box)

func _set_mode(mode: String) -> void:
	## Set the current play mode for Superliminal rules.
	PlayerProfile.set_meta("play_mode", mode)
	NotificationUI.notify_info("Play mode set: " + mode.replace("_", " ").capitalize())
	PlayerProfile.profile_updated.emit()

func _open_wardrobe() -> void:
	## Open the wardrobe UI — change look, race, frame, outfit.
	NotificationUI.notify_info("Wardrobe — customize your look. (Full UI coming soon.)")

func _open_repair_station() -> void:
	## Open repair station for worn gear.
	NotificationUI.notify_info("Repair Station — fix your gear. (Full UI coming soon.)")

func _open_storage_vault() -> void:
	## Open storage vault — gear, weapons, entities.
	NotificationUI.notify_info("Storage Vault — store your gear and entities. (Full UI coming soon.)")

func _open_creation_station() -> void:
	## Open creation station for custom content (Creator Pack required).
	NotificationUI.notify_info("Creation Station — build custom content. (Full UI coming soon.)")
