extends Node3D
class_name TitleScreen
## Atmospheric 3D title screen — your Subliminal apartment from a cinematic
## angle. The flat phone home screen has been replaced; the door to the
## Metroplex stands across the room, your PeriHuman waits beside it, and
## two clear choices float in-world: New Venture or Continue Expedition.
##
## The phone lives on as a 3D prop — click it for OmniDex, Daily, and the
## rest of the app grid.

var _phone_prop: Node3D
var _peri_human: Node3D

func _ready() -> void:
	var MusicManager = AutoloadGate.get_node("MusicManager")
	if MusicManager:
		MusicManager.play_context("theme")
	# Always show the overlay UI even if 3D fails
	_build_overlay_ui()
	_build_room()
	_build_camera()
	_build_door()
	_build_peri_human()
	_build_phone_prop()

func _build_room() -> void:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var IdentityLens = AutoloadGate.get_node("IdentityLens")
	var grid: Vector2i = SubliminalManager.APARTMENT_GRID
	const SLOT_SIZE := 2.0
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

	# Floor
	var floor_mi := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(w + 2, 0.4, d + 2)
	floor_mi.mesh = floor_mesh
	floor_mi.position.y = -0.2
	floor_mi.material_override = IdentityLens.world_material(Color(0.35, 0.3, 0.4))
	add_child(floor_mi)

	# Walls — front, left, right only (back wall gets the door)
	for wall in [
		{size = Vector3(w + 2, 4, 0.3), pos = Vector3(0, 2, -d / 2.0 - 1.0)},
		{size = Vector3(0.3, 4, d + 2), pos = Vector3(-w / 2.0 - 1.0, 2, 0)},
		{size = Vector3(0.3, 4, d + 2), pos = Vector3(w / 2.0 + 1.0, 2, 0)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = wall.size
		mi.mesh = box
		mi.position = wall.pos
		mi.material_override = IdentityLens.world_material(Color(0.25, 0.22, 0.3), 0.5)
		add_child(mi)

	# Back wall — built in two pieces flanking the doorway
	var wall_thick := 0.3
	var wall_h := 4.0
	var wall_z := d / 2.0 + 1.0
	var gap_center := 0.0
	var gap_half := 1.36  # doorway half-width + frame
	for wall_half in [
		{size = Vector3(w / 2.0 - gap_half, wall_h, wall_thick), pos = Vector3(-w / 4.0 - gap_half / 2.0, 2, wall_z)},
		{size = Vector3(w / 2.0 - gap_half, wall_h, wall_thick), pos = Vector3(w / 4.0 + gap_half / 2.0, 2, wall_z)},
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = wall_half.size
		mi.mesh = box
		mi.position = wall_half.pos
		mi.material_override = IdentityLens.world_material(Color(0.25, 0.22, 0.3), 0.5)
		add_child(mi)

	# Warm lamp
	var lamp := OmniLight3D.new()
	lamp.light_color = IdentityLens.sensorium().light
	lamp.light_energy = 1.4
	lamp.position = Vector3(0, 3.2, 0)
	add_child(lamp)

func _build_camera() -> void:
	var cam := Camera3D.new()
	# Cinematic wide angle — facing the back wall door, PeriHuman in frame.
	cam.position = Vector3(-2.5, 2.8, -5.5)
	cam.look_at(Vector3(0.0, 1.5, 3.0))
	cam.current = true
	add_child(cam)

func _build_door() -> void:
	var SubliminalManager = AutoloadGate.get_node("SubliminalManager")
	var IdentityLens = AutoloadGate.get_node("IdentityLens")
	var grid: Vector2i = SubliminalManager.APARTMENT_GRID
	const SLOT_SIZE := 2.0
	var d := grid.y * SLOT_SIZE
	var wall_z := d / 2.0 + 1.0
	var door_w := 2.0
	var door_h := 3.0

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

	# Threshold glow
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

	var lbl := Label3D.new()
	lbl.text = "THE METROPLEX"
	lbl.position = Vector3(0.0, door_h + 0.6, wall_z)
	lbl.font_size = 24
	lbl.modulate = Color(0.7, 0.8, 1.0)
	lbl.outline_size = 4
	add_child(lbl)

func _build_peri_human() -> void:
	_peri_human = Node3D.new()
	_peri_human.name = "PeriHuman"
	_peri_human.position = Vector3(0.0, 0.0, 1.5)
	var path := "res://assets/models/peri_human_player.glb"
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			inst.name = "Model"
			_peri_human.add_child(inst)
	add_child(_peri_human)

	# Slow idle rotation — alive, waiting.
	var tween := create_tween().set_loops()
	tween.tween_callback(func():
		if is_instance_valid(_peri_human):
			_peri_human.rotation.y += 0.004
	).set_delay(0.05)

func _build_phone_prop() -> void:
	_phone_prop = Node3D.new()
	_phone_prop.name = "PhoneProp"
	_phone_prop.position = Vector3(3.0, 0.7, -2.0)
	_phone_prop.rotation_degrees = Vector3(0, -25, 75)  # leaning against something

	var screen_mi := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.15, 0.28, 0.01)
	screen_mi.mesh = screen_mesh
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.1, 0.12, 0.2)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.08, 0.1, 0.3)
	screen_mat.emission_energy_multiplier = 0.6
	screen_mi.material_override = screen_mat
	_phone_prop.add_child(screen_mi)

	var area := Area3D.new()
	area.name = "PhoneClickArea"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.25, 0.38, 0.15)
	cs.shape = box
	area.add_child(cs)
	area.input_ray_pickable = true
	area.input_event.connect(_on_phone_clicked)
	_phone_prop.add_child(area)

	add_child(_phone_prop)

func _on_phone_clicked(_cam: Camera3D, ev: InputEvent, _pos: Vector3, _n: Vector3, _i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_open_app_grid()

func _open_app_grid() -> void:
	if get_node_or_null("AppGrid") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "AppGrid"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", style)

	var canvas := CanvasLayer.new()
	canvas.name = "PhoneCanvas"
	add_child(canvas)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = "📱"
	title.add_theme_font_size_override("font_size", 22)
	top.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func():
		panel.queue_free()
		canvas.queue_free())
	top.add_child(close)
	vbox.add_child(top)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	var apps: Array[Dictionary] = [
		{emoji = "📖", label = "OmniDex", fn = func(): _launch_omni_dex()},
		{emoji = "🎁", label = "Daily", fn = func(): _launch_daily()},
		{emoji = "📜", label = "Quests", fn = func(): _launch_quests()},
		{emoji = "🏆", label = "Board", fn = func(): _launch_leaderboard()},
		{emoji = "🛒", label = "Shop", fn = func(): _launch_shop()},
		{emoji = "🏰", label = "Guild", fn = func(): _launch_guild()},
		{emoji = "💛", label = "Hope", fn = func(): _launch_hope()},
		{emoji = "⚙️", label = "Settings", fn = func(): _launch_settings()},
	]
	for app in apps:
		var btn := Button.new()
		btn.text = "%s\n%s" % [app.emoji, app.label]
		btn.custom_minimum_size = Vector2(88, 72)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(app.fn)
		grid.add_child(btn)

func _build_overlay_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "TitleOverlay"
	add_child(canvas)

	# Brand panel — top center
	var brand := PanelContainer.new()
	brand.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	brand.offset_top = 20
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.08, 0.07, 0.14, 0.8)
	bstyle.corner_radius_top_left = 16
	bstyle.corner_radius_top_right = 16
	bstyle.corner_radius_bottom_left = 16
	bstyle.corner_radius_bottom_right = 16
	brand.add_theme_stylebox_override("panel", bstyle)
	canvas.add_child(brand)

	var brand_box := VBoxContainer.new()
	brand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_box.add_theme_constant_override("separation", 4)
	brand.add_child(brand_box)

	var emblem := LogoEmblem.new()
	emblem.custom_minimum_size = Vector2(48, 48)
	brand_box.add_child(emblem)

	var name_lbl := Label.new()
	name_lbl.text = "PERILIMINAL.SPACE"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	brand_box.add_child(name_lbl)

	var tag := Label.new()
	tag.text = "Six realities. One of you."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.modulate = Color(0.65, 0.55, 0.9)
	tag.add_theme_font_size_override("font_size", 13)
	brand_box.add_child(tag)

	# Bottom bar — New Venture + Continue
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_bottom = -30
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	canvas.add_child(bar)

	for spec in [
		{label = "⚔️  NEW VENTURE", color = Color(0.22, 0.48, 0.32), fn = func(): get_tree().change_scene_to_file("res://scenes/ui/venture_wizard.tscn")},
		{label = "🌀  CONTINUE", color = Color(0.18, 0.32, 0.52), fn = _continue_expedition},
	]:
		var btn := Button.new()
		btn.text = spec.label
		btn.custom_minimum_size = Vector2(200, 52)
		btn.add_theme_font_size_override("font_size", 18)
		var s := StyleBoxFlat.new()
		s.bg_color = spec.color
		s.corner_radius_top_left = 14
		s.corner_radius_top_right = 14
		s.corner_radius_bottom_left = 14
		s.corner_radius_bottom_right = 14
		btn.add_theme_stylebox_override("normal", s)
		var hover := s.duplicate()
		hover.bg_color = spec.color.lightened(0.15)
		btn.add_theme_stylebox_override("hover", hover)
		btn.pressed.connect(spec.fn)
		bar.add_child(btn)

	# Disable Continue if no expedition
	var PlayerProfile = AutoloadGate.get_node("PlayerProfile")
	if not PlayerProfile.has_expedition:
		bar.get_child(1).disabled = true

	# Phone hint — small text bottom-right
	var hint := Label.new()
	hint.text = "Click the phone →"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -180
	hint.offset_bottom = -10
	hint.modulate = Color(0.5, 0.5, 0.6, 0.7)
	hint.add_theme_font_size_override("font_size", 12)
	canvas.add_child(hint)

func _continue_expedition() -> void:
	var LayerManager = AutoloadGate.get_node("LayerManager")
	if not LayerManager.transition_to("subliminal"):
		get_tree().change_scene_to_file("res://scenes/layers/subliminal.tscn")

# -- App launchers (reuse existing UI components) --

func _launch_omni_dex() -> void:
	if get_node_or_null("OmniDex") != null: return
	var dex := OmniDexUI.new()
	dex.name = "OmniDex"
	add_child(dex)

func _launch_daily() -> void:
	var daily := DailyRewardPopup.new()
	daily.name = "DailyRewardApp"
	add_child(daily)

func _launch_quests() -> void:
	var qu: Node = null
	var packed: PackedScene = load("res://scenes/ui/quest.tscn") as PackedScene
	if packed != null:
		qu = packed.instantiate()
		qu.name = "QuestsApp"
		add_child(qu)

func _launch_leaderboard() -> void:
	var lb: Node = null
	var packed: PackedScene = load("res://scenes/ui/leaderboard.tscn") as PackedScene
	if packed != null:
		lb = packed.instantiate()
		lb.name = "LeaderboardApp"
		add_child(lb)

func _launch_shop() -> void:
	var shop := ShopUI.new()
	shop.name = "ShopApp"
	add_child(shop)

func _launch_guild() -> void:
	# Trimmed down guild panel reusing the old title_screen pattern.
	var panel := PanelContainer.new()
	panel.name = "GuildPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", style)

	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	var tl := Label.new()
	tl.text = "🏰 Guild"
	tl.add_theme_font_size_override("font_size", 20)
	top.add_child(tl)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): panel.queue_free(); canvas.queue_free())
	top.add_child(close)
	vbox.add_child(top)

	var info := Label.new()
	info.text = "Guild features load on Continue."
	info.modulate = Color(0.7, 0.7, 0.75)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

func _launch_hope() -> void:
	var panel := PanelContainer.new()
	panel.name = "HopePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", style)

	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	var tl := Label.new()
	tl.text = "💛 Hope"
	tl.add_theme_font_size_override("font_size", 20)
	top.add_child(tl)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): panel.queue_free(); canvas.queue_free())
	top.add_child(close)
	vbox.add_child(top)

	var Hope = AutoloadGate.get_node("Hope")
	if Hope != null:
		var stage = Hope.stage()
		var sl := Label.new()
		sl.text = "%s (bond %d)" % [stage.get("name", "Flicker"), Hope.bond]
		sl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(sl)
		var axes := Label.new()
		axes.text = "Agg %.0f%% · Cau %.0f%% · Cur %.0f%% · Grd %.0f%%" % [
			Hope.profile.aggression * 100, Hope.profile.caution * 100,
			Hope.profile.curiosity * 100, Hope.profile.greed * 100]
		axes.modulate = Color(0.7, 0.75, 0.85)
		vbox.add_child(axes)
	else:
		var offline := Label.new()
		offline.text = "Hope awakens on Continue."
		offline.modulate = Color(0.65, 0.65, 0.75)
		vbox.add_child(offline)

func _launch_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")
