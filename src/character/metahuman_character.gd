class_name MetahumanCharacter
extends RefCounted
## PeriHuman visual resolver — characters/NPCs that ship in the build.
## Players never install Unreal, MakeHuman, or any DCC tool. Bodies are
## GLBs under assets/models/; this class just picks the best slot.
##
## Priority (first hit wins):
##   1. Race-specific — peri_human_<race> / metahuman_<race>
##   2. Shipped PeriHuman — peri_human_player|npc / metahuman_player|npc
##   3. Interim humanoid — player_human / npc_human
##   4. House-cat GLB — player_cat / npc_cat (Catsino skin only)
##   5. CharacterRig procedural humanoid (last resort)
##
## Studio-only upgrades (optional): replace those GLBs with MakeHuman /
## MetaHuman / CC4 exports via docs/VISUAL_DIRECTION_ESO.md. Same slots;
## players still just download the game. Skin/eye/hair look-dev shaders
## live under assets/shaders/metahuman/.

const PERI_PLAYER := "peri_human_player"
const PERI_NPC := "peri_human_npc"
const META_PLAYER := "metahuman_player"
const META_NPC := "metahuman_npc"
const HUMAN_PLAYER := "player_human"
const HUMAN_NPC := "npc_human"
const CAT_PLAYER := "player_cat"
const CAT_NPC := "npc_cat"

## Build the local player's body for the given visual mode. `sex` and
## `appearance` default to PlayerProfile so every spawn reflects the build
## the player created (race → frame → mod → sex → sliders).
static func build_player(visual_mode: String = "identity", sex: String = "",
		appearance: Dictionary = {}) -> Node3D:
	var PlayerProfile = AutoloadGate.get_node("PlayerProfile")
	if sex == "":
		sex = str(PlayerProfile.sex) if PlayerProfile else "m"
	if appearance.is_empty() and PlayerProfile != null:
		appearance = PlayerProfile.appearance.duplicate()
	if visual_mode == "cat":
		var cat: Node3D = AssetLibrary.instance(CAT_PLAYER)
		if cat != null:
			return _as_root(cat)
		# No cat mesh — fall through to PeriHuman (ESO bar wins).
	var race_id := ""
	if PlayerProfile:
		race_id = str(PlayerProfile.selected_race_id)
	var frame_id := str(PlayerProfile.selected_frame) if PlayerProfile else ""
	var mod_id := str(PlayerProfile.selected_mod) if PlayerProfile else ""
	var meta: Node3D = null
	# Female body slots first when the build is female; a dropped-in
	# peri_human_player_f.glb / metahuman_player_f.glb upgrades every
	# female character with zero code.
	if sex == "f":
		meta = _try_slots(["peri_human_player_f", "metahuman_player_f", "player_human_f"])
	if meta == null:
		meta = _try_slots([
			"peri_human_%s" % race_id if not race_id.is_empty() else "",
			"metahuman_%s" % race_id if not race_id.is_empty() else "",
			PERI_PLAYER,
			META_PLAYER,
			HUMAN_PLAYER,
		])
	if meta != null:
		_try_apply_metahuman_materials(meta)
		scan_morphs(meta)
		apply_build_visuals(meta, race_id, frame_id, mod_id, sex, appearance)
		return meta
	return _rig_from_profile(false, sex, appearance)

## Build a remote / NPC body.
static func build_npc(visual_mode: String = "identity", race_id: String = "",
		rng: RandomNumberGenerator = null) -> Node3D:
	if visual_mode == "cat":
		var cat: Node3D = AssetLibrary.instance(CAT_NPC)
		if cat != null:
			return _as_root(cat)
	# Prefer variant pools so NPCs don't all clone the same outfit.
	if rng != null:
		for slot in [PERI_NPC, META_NPC, HUMAN_NPC]:
			var variant := AssetLibrary.instance_variant(slot, rng)
			if variant != null:
				_try_apply_metahuman_materials(variant)
				return _as_root(variant)
	var meta := _try_slots([
		"peri_human_%s" % race_id if not race_id.is_empty() else "",
		"metahuman_%s" % race_id if not race_id.is_empty() else "",
		PERI_NPC,
		META_NPC,
		HUMAN_NPC,
		HUMAN_PLAYER,
	])
	if meta != null:
		_try_apply_metahuman_materials(meta)
		return meta
	return _rig_from_profile(true)

static func _try_slots(slots: Array) -> Node3D:
	for s in slots:
		var slot := str(s)
		if slot.is_empty():
			continue
		var n := AssetLibrary.instance(slot)
		if n != null:
			return _as_root(n)
	return null

static func _as_root(n: Node) -> Node3D:
	var root: Node3D
	if n is Node3D:
		root = n as Node3D
	else:
		root = Node3D.new()
		root.add_child(n)
	# Guard against bad MPFB/glTF bakes (Z-up + cm-scale → giant/sideways).
	_normalize_humanoid_pose(root)
	return root

## Apply the full build to any loaded body: frame scale (light/heavy),
## morph-rig mod scale, sex proportions, slider height/build, and
## skin/hair/eye/outfit albedo + race glow. Shared by the wizard preview
## and the in-game avatar so what you picked is what you see.
static func apply_build_visuals(root: Node3D, race_id: String, frame_id: String,
		mod_id: String, sex: String, appearance: Dictionary) -> void:
	var s := Vector3.ONE
	if not frame_id.is_empty():
		const FrameData = preload("res://hdv_lore/src/data/frame_data.gd")
		var f := FrameData.by_id(frame_id)
		if not f.is_empty():
			match str(f.get("frame_type", "")):
				"heavy": s *= 1.16
				"light": s *= 0.88
	if not mod_id.is_empty():
		match mod_id:
			"towering", "colossus": s.y *= 1.35
			"compact": s.y *= 0.8
			"elastic", "serpentine": s.y *= 1.15
	if sex == "f":
		s *= Vector3(0.96, 0.985, 0.96)
	var height: float = clampf(float(appearance.get("height", 1.0)), 0.85, 1.2)
	var build: float = clampf(float(appearance.get("build", 1.0)), 0.8, 1.3)
	s.y *= height
	s.x *= build
	s.z *= build
	root.scale = s
	_tint_surfaces(root, race_id, appearance)
	apply_face_morphs(root, appearance)

## Recolor GLB surfaces by their semantic name (Skin / Hair / eye.L /
## eye.R / Pants / Shirt / Shoes) using the appearance sliders, with the
## race primary color as the fallback tint + glow.
static func _tint_surfaces(root: Node3D, race_id: String, appearance: Dictionary) -> void:
	var tint: Color = Color(1.0, 0.95, 0.9)
	if not race_id.is_empty():
		var race := RaceDataCharacter.get_race(race_id)
		if not race.is_empty() and race.has("primary_color"):
			tint = Color(race.primary_color)
	var skin := Color(appearance.get("skin", "#d9a066"))
	var hair := Color(appearance.get("hair", "#2b1d12"))
	var eye := Color(appearance.get("eye", "#6b4c2a"))
	var outfit := Color(appearance.get("outfit", "#3a4a6a"))
	var glow: float = clampf(float(appearance.get("glow", 0.0)), 0.0, 1.0)
	for mi in root.find_children("*", "MeshInstance3D", true):
		if not (mi is MeshInstance3D):
			continue
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var mat := (mi as MeshInstance3D).get_active_material(si)
			if mat == null:
				continue
			var dup: Material = mat.duplicate()
			if not (dup is StandardMaterial3D):
				continue
			var m3 := dup as StandardMaterial3D
			var sname := _surface_name(mi as MeshInstance3D, si).to_lower()
			# Eyes FIRST: shipped eye surfaces are named
			# "GEO-body_male_realistic.eye.L/R" — they contain "body" and
			# would wrongly take the skin color in the skin/body test below.
			if sname.contains("eye"):
				m3.albedo_color = eye
			elif sname.contains("skin") or sname.contains("body") or sname.contains("face"):
				m3.albedo_color = skin
			elif sname.contains("hair") or sname.contains("brow") or sname.contains("lash") or sname.contains("scalp"):
				m3.albedo_color = hair
			elif sname.contains("cloth") or sname.contains("shirt") or sname.contains("pant") \
					or sname.contains("shoe") or sname.contains("boot") or sname.contains("outfit") \
					or sname.contains("dress") or sname.contains("jacket"):
				m3.albedo_color = outfit
			else:
				m3.albedo_color = m3.albedo_color.lerp(tint, 0.4)
			if glow > 0.0:
				m3.emission = tint
				m3.emission_energy_multiplier = glow
			(mi as MeshInstance3D).set_surface_override_material(si, m3)

## Record any blend-shape targets on the body (ARKit/Mixamo/MetaHuman-style
## names: jawOpen, eyeBlink, mouthSmile, …) so appearance sliders can drive
## them the moment such a mesh lands. Ships GLBs have none — this is the
## future-proof hook, not a promise on today's mesh.
static func scan_morphs(root: Node3D) -> void:
	var morph_map: Dictionary = {}
	for mi in root.find_children("*", "MeshInstance3D", true):
		if not (mi is MeshInstance3D):
			continue
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null or not (mesh is ArrayMesh):
			continue
		var am := mesh as ArrayMesh
		var count := am.get_blend_shape_count()
		if count == 0:
			continue
		for i in count:
			var n := am.get_blend_shape_name(i).to_lower().replace(" ", "").replace("_", "")
			morph_map[n] = {"mi": mi as MeshInstance3D, "idx": i}
	root.set_meta("morph_map", morph_map)

## Drive recognized blend shapes from appearance values (range 0..1).
## No-op on bodies without morph targets.
static func apply_face_morphs(root: Node3D, appearance: Dictionary) -> void:
	if root == null or not root.has_meta("morph_map"):
		return
	var morph_map: Dictionary = root.get_meta("morph_map")
	if morph_map.is_empty():
		return
	for key in appearance.keys():
		var norm := str(key).to_lower().replace(" ", "").replace("_", "")
		if morph_map.has(norm):
			var entry: Dictionary = morph_map[norm]
			var mi := entry.get("mi") as MeshInstance3D
			if mi != null:
				mi.set_blend_shape_value(int(entry.get("idx", 0)), clampf(float(appearance[key]), 0.0, 1.0))

## If a humanoid mesh is lying on its side/back or absurdly large, upright it
## and scale to ~1.8 m. Correct Y-up variants (~1.6–1.9 m) are left alone.
static func _normalize_humanoid_pose(root: Node3D) -> void:
	var aabb := _mesh_aabb_local(root)
	if aabb.size == Vector3.ZERO:
		return
	var sx := aabb.size.x
	var sy := aabb.size.y
	var sz := aabb.size.z
	var tallest := maxf(sx, maxf(sy, sz))
	if tallest < 0.4:
		return
	# Height should be on +Y. If Z or X dominates, the bake double-rotated.
	var upright_needed := sy < tallest * 0.55
	var oversized := tallest > 3.5
	if not upright_needed and not oversized:
		return
	if upright_needed:
		# Height along -Z (common MPFB+glTF double convert) → stand on +Y.
		if sz >= sx and sz >= sy:
			root.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		elif sx >= sy and sx >= sz:
			root.rotate_object_local(Vector3.FORWARD, PI * 0.5)
		aabb = _mesh_aabb_local(root)
		tallest = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if tallest > 2.4:
		var target := 1.80
		var s := target / maxf(aabb.size.y, 0.01)
		root.scale *= s
		aabb = _mesh_aabb_local(root)
	# Plant feet on the ground plane of the CharacterBody.
	if aabb.position.y < -0.01 or aabb.position.y > 0.05:
		root.position.y -= aabb.position.y

static func _mesh_aabb_local(root: Node3D) -> AABB:
	var merged := AABB()
	var any := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				var local := mi.get_aabb()
				# Build transform from mi up to root (works before add_child).
				var xf := Transform3D.IDENTITY
				var cur: Node = mi
				while cur != null and cur != root:
					if cur is Node3D:
						xf = (cur as Node3D).transform * xf
					cur = cur.get_parent()
				var corners: Array[Vector3] = [
					local.position,
					local.position + Vector3(local.size.x, 0, 0),
					local.position + Vector3(0, local.size.y, 0),
					local.position + Vector3(0, 0, local.size.z),
					local.position + Vector3(local.size.x, local.size.y, 0),
					local.position + Vector3(local.size.x, 0, local.size.z),
					local.position + Vector3(0, local.size.y, local.size.z),
					local.position + local.size,
				]
				for c in corners:
					var p: Vector3 = xf * c
					if not any:
						merged = AABB(p, Vector3.ZERO)
						any = true
					else:
						merged = merged.expand(p)
		for child in node.get_children():
			stack.append(child)
	return merged

static func _rig_from_profile(perceived: bool, sex: String = "", appearance: Dictionary = {}) -> Node3D:
	var PlayerProfile = AutoloadGate.get_node("PlayerProfile")
	var rig := CharacterRig.new()
	rig.perceived = perceived
	var race_id := "KETH"
	var frame_id := "VEIL"
	var mod_id := "CATALYST"
	if PlayerProfile:
		if str(PlayerProfile.selected_race_id) != "":
			race_id = str(PlayerProfile.selected_race_id)
		if str(PlayerProfile.selected_frame) != "":
			frame_id = str(PlayerProfile.selected_frame)
		if str(PlayerProfile.selected_mod) != "":
			mod_id = str(PlayerProfile.selected_mod)
	var loadout := CharacterCreatorLogic.build_loadout(race_id, frame_id, mod_id)
	rig.build_from_loadout(loadout.get("race", {}), loadout.get("frame", {}), loadout.get("mod", {}))
	rig.appearance = appearance.duplicate() if not appearance.is_empty() else {}
	rig.sex = sex
	rig.apply_appearance()
	return rig

## Look-dev pass for shipped PeriHumans / future MetaHuman exports.
## On Forward+: try MetaHumanGodot skin shader on Skin* surfaces.
## Everywhere: tune StandardMaterial3D skin/cloth/hair toward soft SSS-like
## reads (lower roughness, slight subsurface / rim) so Blender Studio bases
## don't look plastic under HDRI.
static func _try_apply_metahuman_materials(root: Node3D) -> void:
	root.set_meta("peri_human", true)
	var shader_path := "res://assets/shaders/metahuman/skin_shader_local.gdshader"
	var skin_shader: Shader = null
	if ResourceLoader.exists(shader_path):
		skin_shader = load(shader_path) as Shader
		root.set_meta("metahuman_shader_ready", true)
	_tune_meshes(root, skin_shader)

static func _tune_meshes(node: Node, skin_shader: Shader) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for si in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(si)
				if mat == null:
					continue
				var sname := _surface_name(mi, si).to_lower()
				var tuned := _tune_surface_material(mat, sname, skin_shader)
				if tuned != null:
					mi.set_surface_override_material(si, tuned)
	for child in node.get_children():
		_tune_meshes(child, skin_shader)

static func _surface_name(mi: MeshInstance3D, si: int) -> String:
	var mesh := mi.mesh
	if mesh != null and mesh is ArrayMesh:
		var am := mesh as ArrayMesh
		var n := am.surface_get_name(si)
		if not n.is_empty():
			return n
	var mat := mi.get_active_material(si)
	if mat != null and not mat.resource_name.is_empty():
		return mat.resource_name
	return mi.name

static func _tune_surface_material(mat: Material, sname: String, skin_shader: Shader) -> Material:
	var is_skin := (
		sname.contains("skin") or sname.contains("body") or sname.contains("head")
		or sname.contains("face") or sname.contains("arm") or sname.contains("leg")
	)
	var is_eye := sname.contains("eye") or sname.contains("cornea") or sname.contains("sclera")
	var is_hair := (
		sname.contains("hair") or sname.contains("brow") or sname.contains("lash")
		or sname.contains("scalp")
	)
	var is_cloth := (
		sname.contains("cloth") or sname.contains("shirt") or sname.contains("pant")
		or sname.contains("shoe") or sname.contains("boot") or sname.contains("outfit")
		or sname.contains("dress") or sname.contains("jacket")
	)
	# Forward+ only: full skin shader (too heavy / incomplete on compat).
	if is_skin and skin_shader != null and not RenderCaps.is_compatibility():
		var sm := ShaderMaterial.new()
		sm.shader = skin_shader
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			sm.set_shader_parameter("albedo", bm.albedo_color)
			if bm.albedo_texture != null:
				sm.set_shader_parameter("texture_albedo", bm.albedo_texture)
			sm.set_shader_parameter("roughness", clampf(bm.roughness * 0.85, 0.25, 0.65))
		else:
			sm.set_shader_parameter("albedo", Color(0.82, 0.62, 0.52))
			sm.set_shader_parameter("roughness", 0.45)
		return sm
	if mat is StandardMaterial3D:
		var std := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		if is_skin:
			std.roughness = clampf(std.roughness * 0.75, 0.28, 0.62)
			std.metallic = 0.0
			if "metallic_specular" in std:
				std.metallic_specular = 0.45
			if not RenderCaps.is_compatibility():
				# Property names differ slightly across 4.x — set only if present.
				if "subsurf_scatter_enabled" in std:
					std.subsurf_scatter_enabled = true
					std.subsurf_scatter_strength = 0.35
				if "rim_enabled" in std:
					std.rim_enabled = true
					std.rim = 0.08
					std.rim_tint = 0.6
		elif is_eye:
			std.roughness = 0.08
			std.metallic = 0.0
			if "metallic_specular" in std:
				std.metallic_specular = 0.7
		elif is_hair:
			std.roughness = clampf(std.roughness, 0.35, 0.7)
			if "metallic_specular" in std:
				std.metallic_specular = 0.55
		elif is_cloth:
			std.roughness = maxf(std.roughness, 0.7)
			std.metallic = minf(std.metallic, 0.05)
		else:
			# Generic body/cloth on Blender Studio bake — soft matte.
			std.roughness = clampf(std.roughness, 0.4, 0.85)
		return std
	return null

## Which visual tier would win for the local player right now?
## Returns one of: peri_human_race | peri_human_player | metahuman_race |
## metahuman_player | player_human | player_cat | procedural_rig
static func resolve_tier(visual_mode: String = "identity") -> String:
	var PlayerProfile = AutoloadGate.get_node("PlayerProfile")
	if visual_mode == "cat" and AssetLibrary.has_asset("player_cat"):
		return "player_cat"
	var race_id := ""
	if PlayerProfile:
		race_id = str(PlayerProfile.selected_race_id)
	if not race_id.is_empty() and AssetLibrary.has_asset("peri_human_%s" % race_id):
		return "peri_human_race"
	if not race_id.is_empty() and AssetLibrary.has_asset("metahuman_%s" % race_id):
		return "metahuman_race"
	if AssetLibrary.has_asset(PERI_PLAYER) or AssetLibrary.has_asset(META_PLAYER):
		return "peri_human_player"
	if AssetLibrary.has_asset(HUMAN_PLAYER):
		return "player_human"
	return "procedural_rig"
