extends CharacterBody3D
## Capture-by-defeat only.

signal died(entity_id: String, hp_ratio: float)

var entity_id: String = ""
var display_name: String = "Shade"
var hp: int = 28
var max_hp: int = 28
var alive: bool = true

func setup(id: String, nam: String, pos: Vector3, start_hp: int) -> void:
	entity_id = id
	display_name = nam
	hp = start_hp
	max_hp = start_hp
	position = pos
	var mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.45
	sph.height = 0.9
	mesh.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.55, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.22, 0.16)
	mesh.material_override = mat
	add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	col.shape = shape
	add_child(col)

func hit(amount: int, player_hp_ratio: float) -> void:
	if not alive:
		return
	hp -= amount
	Consistency.record_deed("attack")
	if hp <= 0:
		alive = false
		died.emit(entity_id, player_hp_ratio)
		CaptureSystem.try_capture(entity_id, display_name, player_hp_ratio)
		Wallet.add("fragments", 1)
		queue_free()
