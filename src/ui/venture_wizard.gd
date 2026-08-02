class_name VentureWizard
extends Control
## "Start New Venture" — old-school Mortal Kombat select-screen energy:
## a scrollable roster of portrait tiles, arrow keys or clicks to move the
## cursor, a big VS-style panel on the right showing whoever's highlighted,
## ENTER/click to lock it in and advance to the next roster (Race ->
## Faction -> Frame -> Mod -> name your fighter -> FIGHT, into the
## Liminal).

signal venture_started()

const STEPS := ["race", "frame", "mod", "name"]

var _step := 0
var _cursor := 0
var _picked: Dictionary = {}

var _title: Label
var _roster_row: HBoxContainer
var _roster_scroll: ScrollContainer
var _preview_viewport: SubViewportContainer
var _preview_subviewport: SubViewport
var _art: TextureRect  # generated race/frame/mod sprite over the 3D preview
var _preview_instance: Node3D
var _portrait: ColorRect  # fallback when viewport isn't ready
var _portrait_label: Label
var _detail: RichTextLabel
var _name_edit: LineEdit
var _confirm_btn: Button
var _back_btn: Button
var _tiles: Array[Button] = []
var _entries: Array = []

func _ready() -> void:
	MusicManager.play_context("theme")
	_build_ui()
	_render_step()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	root.add_child(_title)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 20)
	root.add_child(mid)

	# ---- big VS-style portrait panel ----
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	mid.add_child(left)

	# 3D PeriHuman preview via SubViewport (falls back to flat color rect).
	_preview_viewport = SubViewportContainer.new()
	_preview_viewport.custom_minimum_size = Vector2(340, 340)
	_preview_viewport.size = Vector2(340, 340)
	_preview_viewport.stretch = true
	_preview_viewport.stretch_shrink = 1
	left.add_child(_preview_viewport)

	_preview_subviewport = SubViewport.new()
	_preview_subviewport.size = Vector2(340, 340)
	_preview_subviewport.transparent_bg = true
	_preview_subviewport.msaa_3d = Viewport.MSAA_2X
	_preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_viewport.add_child(_preview_subviewport)

	# Generated identity art layered over the 3D preview. When a sprite exists
	# for the current race/frame/mod it fills this; otherwise it hides and the
	# procedural PeriHuman preview shows through.
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.visible = false
	_preview_viewport.add_child(_art)

	# Character preview scene as fallback-ready 3D model display.
	var preview_scene := load("res://scenes/character/character_preview.tscn")
	_preview_instance = preview_scene.instantiate()
	_preview_subviewport.add_child(_preview_instance)

	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(340, 24)
	_portrait.size = Vector2(340, 24)
	_portrait.visible = true  # accent bar below the 3D viewport
	left.add_child(_portrait)

	_portrait_label = Label.new()
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.add_theme_font_size_override("font_size", 26)
	left.add_child(_portrait_label)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(340, 200)
	left.add_child(_detail)

	# ---- roster strip ----
	_roster_scroll = ScrollContainer.new()
	_roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_roster_scroll)
	_roster_row = HBoxContainer.new()
	_roster_row.add_theme_constant_override("separation", 10)
	_roster_scroll.add_child(_roster_row)

	# ---- bottom controls ----
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	root.add_child(controls)

	_back_btn = Button.new()
	_back_btn.text = "◀ Back"
	_back_btn.pressed.connect(_go_back)
	controls.add_child(_back_btn)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name your fighter"
	_name_edit.custom_minimum_size = Vector2(260, 40)
	_name_edit.visible = false
	controls.add_child(_name_edit)

	_confirm_btn = Button.new()
	_confirm_btn.text = "SELECT ▶"
	_confirm_btn.custom_minimum_size = Vector2(160, 44)
	_confirm_btn.pressed.connect(_confirm_step)
	controls.add_child(_confirm_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	root.add_child(spacer)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_move_cursor(-1)
			KEY_RIGHT, KEY_D:
				_move_cursor(1)
			KEY_ENTER, KEY_SPACE:
				if not _name_edit.visible:
					_confirm_step()

func _move_cursor(dir: int) -> void:
	if _entries.is_empty():
		return
	_cursor = wrapi(_cursor + dir, 0, _entries.size())
	_update_portrait()
	for i in _tiles.size():
		_tiles[i].modulate = Color.WHITE if i == _cursor else Color(0.6, 0.6, 0.65)

# ---------------------------------------------------------------- steps

func _render_step() -> void:
	var step: String = STEPS[_step]
	_back_btn.visible = _step > 0
	_name_edit.visible = step == "name"
	_confirm_btn.text = "FIGHT ⚔️" if step == "name" else "SELECT ▶"
	_roster_scroll.visible = step != "name"
	_portrait.visible = true

	match step:
		"race":
			_title.text = "CHOOSE YOUR RACE"
			_entries = RaceDataCharacter.RACES.map(func(r): return {
				"id": r.id, "name": OmniDexRegistry.race_display_name(str(r.id)), "color": r.primary_color,
				"blurb": RaceLore.get_lore(OmniDexRegistry.race_display_name(str(r.id))).get("description", r.lore),
				"stats": "POW %d  RES %d  SPD %d  LCK %d  STY %d" % [r.pow, r.res, r.spd, r.lck, r.sty],
			})
		"frame":
			_title.text = "CHOOSE YOUR FRAME"
			# Periliminal identity frames from hdv_lore — 20 frames (10 light
			# + 10 heavy). Each has a unique combat role and exclusive stat.
			# The full description comes from role + mobility + combat_style.
			const FrameData = preload("res://hdv_lore/src/data/frame_data.gd")
			_entries = FrameData.FRAMES.map(func(f): return {
				"id": f.id,
				"name": f.name,
				"color": _hash_color(f.id),
				"type": f.frame_type,
				"role": f.get("role", ""),
				"blurb": "%s\n%s\n\n%s" % [
					f.get("role", ""), f.get("mobility", ""), f.get("combat_style", "")],
				"stats": "AGI %d  POW %d  RES %d  FREQ %d" % [
					f.stats.get("agility", 5), f.stats.get("power", 5),
					f.stats.get("resonance", 5), f.stats.get("frequency", 5)],
				"exclusive": "%s: %s" % [f.get("exclusive_stat_name", ""), f.get("exclusive_stat_effect", "")],
			})
		"mod":
			_title.text = "CHOOSE YOUR MORPH RIG"
			# Morph Rig mods from hdv_lore — 20 body plans with rich visual
			# descriptions, gameplay bonuses, and drawbacks.
			_entries = MorphRigData.RIGS.map(func(r): return {
				"id": r.id, "name": OmniDexRegistry.mod_display_name(str(r.id)), "color": _hash_color(r.id),
				"blurb": r.desc if not r.desc.is_empty() else "%s / %s" % [r.bonus, r.drawback],
				"stats": "%s / %s" % [r.bonus, r.drawback],
			})
		"name":
			_title.text = "NAME YOUR FIGHTER"
			_render_final_preview()
			return
	_cursor = 0
	_build_roster()
	_update_portrait()

func _hash_color(seed_str: String) -> Color:
	var h := hash(seed_str)
	return Color.from_hsv(float(h % 360) / 360.0, 0.55, 0.85)

func _build_roster() -> void:
	for c in _roster_row.get_children():
		c.queue_free()
	_tiles.clear()
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(96, 96)
		tile.text = str(e.name)
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var mat := StyleBoxFlat.new()
		mat.bg_color = e.color
		mat.set_corner_radius_all(6)
		tile.add_theme_stylebox_override("normal", mat)
		tile.pressed.connect(func():
			_cursor = i
			_update_portrait()
			for t in _tiles: t.modulate = Color(0.6, 0.6, 0.65)
			tile.modulate = Color.WHITE)
		_roster_row.add_child(tile)
		_tiles.append(tile)
	if not _tiles.is_empty():
		_tiles[0].modulate = Color.WHITE

func _update_portrait() -> void:
	if _entries.is_empty():
		return
	var e: Dictionary = _entries[_cursor]
	_portrait.color = e.color
	_portrait_label.text = str(e.name).to_upper()
	var extra := ""
	if e.has("type") and not e.get("type", "").is_empty():
		extra = "[%s] " % e.type.to_upper()
	if e.has("exclusive") and not e.get("exclusive", "").is_empty():
		extra += "★ %s" % e.exclusive
	_detail.text = "%s\n\n[color=#ffd88a]%s[/color]" % [e.get("blurb", ""), e.get("stats", "")]
	if not extra.is_empty():
		_detail.text += "\n\n" + extra

	# Update the 3D preview with the currently selected race/frame.
	var step: String = STEPS[_step]
	var cur_race := _picked.get("race", "")
	var cur_frame := _picked.get("frame", "")
	var cur_mod := _picked.get("mod", "")
	match step:
		"race": cur_race = str(e.id)
		"frame": cur_frame = str(e.id)
		"mod": cur_mod = str(e.id)
	_preview_instance.preview(cur_race, cur_frame, cur_mod)
	_show_identity_art(str(cur_race), str(cur_frame), str(cur_mod))

func _render_final_preview() -> void:
	var stats := CharacterCreatorLogic.build_starting_stats(_picked.race, "Factionless", _picked.frame)
	var canon_name := OmniDexRegistry.race_display_name(str(_picked.race))
	_portrait.color = RaceDataCharacter.get_race(_picked.race).get("primary_color", Color.WHITE)
	_portrait_label.text = canon_name.to_upper()
	var lore_desc := RaceLore.get_lore(canon_name).get("description", "")
	var frame_name: String = str(_picked.get("frame_name", "?"))
	var frame_desc := ""
	var frame_exclusive := ""
	const FrameData = preload("res://hdv_lore/src/data/frame_data.gd")
	var hdv_frame := FrameData.by_id(str(_picked.frame))
	if not hdv_frame.is_empty():
		frame_name = str(hdv_frame.get("name", frame_name))
		var role := str(hdv_frame.get("role", ""))
		var mobility := str(hdv_frame.get("mobility", ""))
		var combat := str(hdv_frame.get("combat_style", ""))
		frame_desc = "%s\n%s\n%s" % [role, mobility, combat]
		var excl_name := str(hdv_frame.get("exclusive_stat_name", ""))
		var excl_eff := str(hdv_frame.get("exclusive_stat_effect", ""))
		if not excl_name.is_empty():
			frame_exclusive = "★ %s: %s" % [excl_name, excl_eff]
	_detail.text = "[b]%s[/b] — Factionless — [b]%s[/b]\n\n%s\n\nPOW %d  RES %d  SPD %d  LCK %d  STY %d" % [
		canon_name, frame_name,
		lore_desc,
		stats.pow, stats.res, stats.spd, stats.lck, stats.sty,
	]
	if not frame_desc.is_empty():
		_detail.text += "\n\n[i]%s[/i]" % frame_desc
	if not frame_exclusive.is_empty():
		_detail.text += "\n" + frame_exclusive
	# Show mod stats at the bottom if one is picked.
	if _picked.has("mod") and not str(_picked.get("mod", "")).is_empty():
		var mod_id := str(_picked.mod)
		var mod_data := MorphRigData.by_id(mod_id)
		if not mod_data.is_empty():
			_detail.text += "\n\nMod: %s (%s / %s)" % [
				str(mod_data.get("name", mod_id)),
				str(mod_data.get("bonus", "")),
				str(mod_data.get("drawback", "")),
			]
	# Final 3D preview with all selections applied.
	_preview_instance.preview(_picked.get("race", ""), _picked.get("frame", ""), _picked.get("mod", ""))

func _confirm_step() -> void:
	var step: String = STEPS[_step]
	if step == "name":
		var cat_name := _name_edit.text.strip_edges()
		if not CharacterCreatorLogic.validate_name(cat_name):
			_detail.text += "\n\n[color=#ff6666]⚠️ Enter a valid name (2-20 letters/numbers, no spaces).[/color]"
			return
		# All players begin Factionless — they join a faction later by
		# visiting one of the main faction cities.
		CharacterCreatorLogic.apply_creation(_picked.race, "Factionless", _picked.frame, cat_name)
		PlayerProfile.set_mod(_picked.mod)
		venture_started.emit()
		# A new venture starts in the wilds, not the safety of the Subliminal.
		# Use a deferred one-shot to avoid destroying the wizard while its
		# call stack is still alive, AND catch the Nakama socket error that
		# happens when PresenceManager.join_layer fires from the signal.
		call_deferred("_do_transition_to_liminal")
		return

	if _entries.is_empty():
		return
	var e: Dictionary = _entries[_cursor]
	match step:
		"race":
			_picked["race"] = e.id
			_picked["race_name"] = e.name
		"frame":
			_picked["frame"] = e.id
			_picked["frame_name"] = e.name
		"mod":
			_picked["mod"] = e.id
	_step += 1
	_render_step()

func _go_back() -> void:
	if _step <= 0:
		return
	_step -= 1
	_render_step()

func _do_transition_to_liminal() -> void:
	## Deferred one-shot that catches the Nakama socket error (no server in
	## headless/dev) so the scene transition still completes.  PresenceManager
	## fires join_layer() from the layer_changed signal inside transition_to.
	var err := LayerManager.transition_to("liminal", true)
	if not err:
		push_error("VentureWizard: transition_to(liminal) failed")

## Shows the generated identity sprite for this build over the 3D preview,
## or hides it so the procedural preview shows through. Sex is unspecified in
## this wizard, so IdentityArt falls back male -> base on its own.
func _show_identity_art(race_id: String, frame_id: String, mod_id: String) -> void:
	if _art == null:
		return
	var tex := IdentityArt.portrait(race_id, "", frame_id, mod_id)
	_art.texture = tex
	_art.visible = tex != null
