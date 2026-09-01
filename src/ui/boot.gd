extends Node
## Title → New Venture projector → world. Continue → Subliminal.

func _ready() -> void:
	_build()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.045, 0.06)
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	box.custom_minimum_size = Vector2(520, 600)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	var title := Label.new()
	title.text = "PERILIMINAL.SPACE"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Godot client · %d projector combos · gambling off-engine" % OmniDexTables.combo_count()
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(sub)
	var sex := _select(box, "Sex", OmniDexTables.SEXES, Session.sex)
	var race := _select(box, "Race", OmniDexTables.RACES, Session.race_id)
	var frame := _select(box, "Frame", OmniDexTables.FRAMES, Session.frame_id)
	var mod := _select(box, "Mod", OmniDexTables.MODS, Session.mod_id)
	var enter := Button.new()
	enter.text = "New Venture → Liminal"
	box.add_child(enter)
	var cont := Button.new()
	cont.text = "Continue → Subliminal"
	box.add_child(cont)
	var chips := Button.new()
	chips.text = "Buy 20 chips from coins"
	box.add_child(chips)
	enter.pressed.connect(func():
		Session.set_identity(_id(sex), _id(race), _id(frame), _id(mod))
		LayerRouter.prototype_mode = true
		LayerRouter.enter("liminal", "venture")
		_go_world()
	)
	cont.pressed.connect(func():
		LayerRouter.enter("subliminal", "continue")
		_go_world()
	)
	chips.pressed.connect(func():
		Wallet.coins_to_chips(20)
		Hope.say("Twenty chips reserved. Cabinets still settle outside the engine.")
	)

func _select(parent: Node, label: String, table: Dictionary, current: String) -> OptionButton:
	var l := Label.new()
	l.text = label
	parent.add_child(l)
	var ob := OptionButton.new()
	var i := 0
	var pick := 0
	for k in table.keys():
		ob.add_item(str(table[k].get("label", k)), i)
		ob.set_item_metadata(i, k)
		if str(k) == current:
			pick = i
		i += 1
	ob.select(pick)
	parent.add_child(ob)
	return ob

func _id(ob: OptionButton) -> String:
	return str(ob.get_item_metadata(ob.selected))

func _go_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")
