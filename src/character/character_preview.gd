extends Node3D
## Hosts a PeriHuman/MetaHuman 3D model preview for the VentureWizard
## character creator. Tries the shipped PeriHuman GLB first (realistic
## humanoid body); falls back to procedural CharacterRig when assets are
## absent (headless / no model files). Race color tints and frame scaling
## (light vs. heavy) are applied on top of whichever body loads.

@onready var _rig: Node3D = $CharacterRig
var _model: Node3D = null
var race_id: String = ""
var frame_id: String = ""
var mod_id: String = ""

func _ready() -> void:
	refresh()

func refresh() -> void:
	# Clear previous model instance (queue_free, then remove immediately
	# so further add_child works without waiting for idle frame).
	if _model != null:
		remove_child(_model)
		_model.queue_free()
		_model = null
	_rig.visible = false

	# Try the PeriHuman GLB first.  Because MetahumanCharacter.build_player()
	# reads from PlayerProfile (which is NOT changing during wizard cycling),
	# we bypass it and load the GLB directly so we control the instance.
	# Fallback slot order: peri_human_player -> metahuman_player -> player_human
	_model = AssetLibrary.instance("peri_human_player")
	if _model == null:
		_model = AssetLibrary.instance("metahuman_player")
	if _model == null:
		_model = AssetLibrary.instance("player_human")
	if _model == null:
		# No GLB assets at all — fall back to procedural CharacterRig.
		var loadout := CharacterCreatorLogic.build_loadout(race_id, frame_id, mod_id)
		_rig.visible = true
		_rig.build_from_loadout(loadout.race, loadout.frame, loadout.mod)
		return
	# GLB mesh is centered at Y=0 (feet at Y≈-0.89, head at Y≈0.89),
	# so position at Y=0 to stand on the ground plane at Y=-0.05.
	_model.position = Vector3(0, 0, 0)
	add_child(_model)
	_tint_model(_model)
	_apply_frame_scale()

func preview(new_race_id: String, new_frame_id: String, new_mod_id: String = "") -> void:
	race_id = new_race_id
	frame_id = new_frame_id
	mod_id = new_mod_id
	refresh()

func _apply_frame_scale() -> void:
	## Heavier frames get bulkier scale, lighter frames stay lean.
	## This makes race+frame selections look distinct even with the same GLB.
	if frame_id.is_empty():
		return
	const FrameData = preload("res://hdv_lore/src/data/frame_data.gd")
	var f := FrameData.by_id(frame_id)
	if f.is_empty():
		return
	var s := 1.0
	match str(f.get("frame_type", "")):
		"heavy": s = 1.12
		"light": s = 0.92
		_: s = 1.0
	_model.scale = Vector3(s, s, s)

func _tint_model(root: Node3D) -> void:
	## Apply race primary_color tint to the PeriHuman model by tainting
	## each surface material's albedo toward the race color and adding
	## a subtle emission glow. The GLB has 7 surfaces: Skin, Eyes, Pants,
	## Shirt, Hair, Shoes — we tint all of them with the race color.
	var tint: Color = Color(1.0, 0.95, 0.9)  # warm default
	if not race_id.is_empty():
		var race := RaceDataCharacter.get_race(race_id)
		if not race.is_empty() and race.has("primary_color"):
			tint = Color(race.primary_color)
	for mesh in _find_meshes(root):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i)
			if mat == null:
				continue
			var dup := mat.duplicate()
			if not (dup is StandardMaterial3D):
				continue
			var mat3d: StandardMaterial3D = dup
			mat3d.albedo_color = mat3d.albedo_color.lerp(tint, 0.4)
			mat3d.emission = tint
			mat3d.emission_energy_multiplier = 0.12
			mesh.set_surface_override_material(i, mat3d)

static func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for c in node.find_children("*", "MeshInstance3D", true):
		if c is MeshInstance3D:
			meshes.append(c)
	return meshes
