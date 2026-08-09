class_name RemotePlayer
extends Node3D
## Another player (or offline ghost) in the world. Default presentation is
## the casino house cat; PVXC PvP phase swaps to a perceived CharacterRig
## (race/frame silhouette) so fights happen as yourselves.

var peer_id := ""
var profile: Dictionary = {}
## "cat" or "identity" — mirrors ThirdPersonController.visual_mode.
var visual_mode := "identity"
var _body_root: Node3D
var _plate: Label3D

func setup(id: String, p: Dictionary, mode: String = "identity") -> void:
	peer_id = id
	profile = p
	set_visual_mode(mode)

func set_visual_mode(mode: String) -> void:
	if mode != "cat" and mode != "identity":
		mode = "cat"
	visual_mode = mode
	if _body_root != null and is_instance_valid(_body_root):
		_body_root.queue_free()
	_body_root = null
	if _plate != null and is_instance_valid(_plate):
		_plate.queue_free()
	_plate = null
	_rebuild_body()

func _rebuild_body() -> void:
	var seen: Dictionary = IdentityLens.perceive_being(profile, Color(0.7, 0.6, 0.5))
	var race_id := str(profile.get("race_id", ""))
	# Seeded RNG so remotes get upright variant pools, not the broken ship slots.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("remote_body_" + peer_id + "_" + race_id)
	var body := MetahumanCharacter.build_npc(visual_mode, race_id, rng)
	if body is MeshInstance3D:
		body.material_override = seen.material
	_body_root = body
	add_child(body)
	# Clamp perception scale so lens never recreates "giant" bots.
	var s := clampf(float(seen.view.get("apparent_scale", 1.0)), 0.7, 1.5)
	scale = Vector3.ONE * s

	_plate = Label3D.new()
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.position.y = 2.2
	_plate.font_size = 48
	_plate.outline_size = 8
	if seen.view.get("loadout_visible", true):
		_plate.text = peer_id.trim_prefix("ghost_").replace("_", " ")
		_plate.modulate = seen.view.get("aura_color", Color.WHITE)
	else:
		_plate.text = "???" # outclassed: you don't get their name either
		_plate.modulate = Color(0.4, 0.4, 0.45)
	add_child(_plate)
	# Upright pass must run after the body is in-tree so global transforms resolve.
	_force_upright_remote.call_deferred(body)

func _force_upright_remote(root: Node3D) -> void:
	if root == null or not root.is_inside_tree():
		return
	root.rotation = Vector3.ZERO
	var aabb := _compute_mesh_aabb(root)
	if aabb.size == Vector3.ZERO:
		return
	var tallest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if aabb.size.y < tallest * 0.55:
		if aabb.size.z >= aabb.size.x:
			root.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		else:
			root.rotate_object_local(Vector3.FORWARD, PI * 0.5)
		aabb = _compute_mesh_aabb(root)
	if aabb.size.y > 2.5:
		root.scale *= 1.80 / maxf(aabb.size.y, 0.01)
		aabb.size.y = 1.80
	if absf(aabb.position.y) > 0.02:
		root.position.y -= aabb.position.y

func _compute_mesh_aabb(root: Node3D) -> AABB:
	var aabb := AABB()
	var any := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			# Use local AABB corners transformed up to root's parent space so this
			# works even if root itself has not been added to the tree yet.
			var xf := Transform3D.IDENTITY
			var cur: Node = mi
			while cur != null and cur != root:
				if cur is Node3D:
					xf = (cur as Node3D).transform * xf
				cur = cur.get_parent()
			var local_aabb := mi.get_aabb()
			var corners: Array[Vector3] = [
				local_aabb.position,
				local_aabb.position + Vector3(local_aabb.size.x, 0, 0),
				local_aabb.position + Vector3(0, local_aabb.size.y, 0),
				local_aabb.position + Vector3(0, 0, local_aabb.size.z),
				local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0),
				local_aabb.position + Vector3(local_aabb.size.x, 0, local_aabb.size.z),
				local_aabb.position + Vector3(0, local_aabb.size.y, local_aabb.size.z),
				local_aabb.position + local_aabb.size,
			]
			for c in corners:
				var p: Vector3 = xf * c
				if not any:
					aabb = AABB(p, Vector3.ZERO)
					any = true
				else:
					aabb = aabb.expand(p)
		for c in n.get_children():
			stack.append(c)
	return aabb if any else AABB()

func move_to(pos: Vector3, terrain = null) -> void:
	var target := pos
	if terrain != null and terrain.has_method("height_at"):
		target.y = terrain.height_at(pos.x, pos.z) + 0.1
	# Smooth toward the reported position.
	global_position = global_position.lerp(target, 0.2)
