extends Area3D
## Visible arch unless hidden. Hidden doors have ZERO visual tells.

var target_layer: String = "liminal"
var kind: String = "arch"
var hidden_door: bool = false

func setup(to_layer: String, door_kind: String, pos: Vector3, hidden: bool = false) -> void:
	target_layer = to_layer
	kind = door_kind
	hidden_door = hidden
	position = pos
	monitoring = true
	monitorable = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 3.0, 1.2)
	col.shape = box
	add_child(col)
	if not hidden:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 3.0, 0.35)
		mesh.mesh = bm
		add_child(mesh)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.62, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.35, 0.4)
		mesh.material_override = mat
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if not (body is CharacterBody3D):
		return
	if body.name != "Player":
		return
	var from := LayerRouter.current
	if LayerRouter.enter(target_layer, kind):
		DoorLog.log_door(from, target_layer, kind)
