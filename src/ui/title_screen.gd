extends Control
## Title screen — atmospheric 2D hub. The 3D room version is in
## title_screen_3d.gd; this simpler Control is the live fallback while
## the 3D version gets lighting / camera / autoload ordering sorted.

func _ready() -> void:
	var MusicManager = AutoloadGate.get_node("MusicManager")
	if MusicManager:
		MusicManager.play_context("theme")
	_build_ui()

func _build_ui() -> void:
	# Dark atmospheric background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Logo / title
	if ResourceLoader.exists("res://assets/ui/logo.png"):
		var logo := TextureRect.new()
		logo.texture = load("res://assets/ui/logo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(200, 200)
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(logo)
	else:
		var title := Label.new()
		title.text = "PERILIMINAL.SPACE"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 42)
		title.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
		vbox.add_child(title)

	var tagline := Label.new()
	tagline.text = "Six realities. One of you."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 16)
	tagline.modulate = Color(0.6, 0.5, 0.85)
	vbox.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Main action buttons
	const BTN_W := 260.0
	const BTN_H := 56.0

	var new_venture := _make_button("⚔️  NEW VENTURE", Color(0.22, 0.48, 0.32), BTN_W, BTN_H)
	new_venture.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/venture_wizard.tscn"))
	vbox.add_child(new_venture)

	var continue_btn := _make_button("🌀  CONTINUE", Color(0.18, 0.32, 0.52), BTN_W, BTN_H)
	continue_btn.pressed.connect(_continue_expedition)
	var PlayerProfile = AutoloadGate.get_node("PlayerProfile")
	if PlayerProfile and not PlayerProfile.has_expedition:
		continue_btn.disabled = true
	vbox.add_child(continue_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer2)

	# App grid row
	var app_row := HBoxContainer.new()
	app_row.alignment = BoxContainer.ALIGNMENT_CENTER
	app_row.add_theme_constant_override("separation", 10)
	vbox.add_child(app_row)

	var apps: Array[Dictionary] = [
		{emoji = "📖", label = "OmniDex"},
		{emoji = "🎁", label = "Daily"},
		{emoji = "📜", label = "Quests"},
		{emoji = "🏆", label = "Board"},
		{emoji = "🛒", label = "Shop"},
		{emoji = "🏰", label = "Guild"},
		{emoji = "💛", label = "Hope"},
		{emoji = "⚙️", label = "Settings"},
	]
	for app in apps:
		var btn := Button.new()
		btn.text = "%s  %s" % [app.emoji, app.label]
		btn.custom_minimum_size = Vector2(90, 38)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func(): _notify("Coming soon: " + app.label))
		app_row.add_child(btn)

func _make_button(text_str: String, color: Color, width: float, height: float) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(width, height)
	btn.add_theme_font_size_override("font_size", 20)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn

func _continue_expedition() -> void:
	var LayerManager = AutoloadGate.get_node("LayerManager")
	if LayerManager and LayerManager.transition_to("subliminal"):
		return
	get_tree().change_scene_to_file("res://scenes/layers/subliminal.tscn")

func _notify(msg: String) -> void:
	var NotificationUI = AutoloadGate.get_node("NotificationUI")
	if NotificationUI:
		NotificationUI.notify_info(msg)
