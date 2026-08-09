extends Control

func _ready() -> void:
	var tex: Texture2D = load("res://assets/entities/ashen_choir_f.jpg")
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(rect)
	var label := Label.new()
	label.text = "ashen_choir_f.jpg"
	label.add_theme_font_size_override("font_size", 24)
	label.position = Vector2(20, 20)
	add_child(label)
