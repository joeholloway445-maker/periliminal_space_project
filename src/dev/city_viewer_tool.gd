@tool
extends Node3D
## Editor tool: builds the full-scale Arlington OSM mega-city in the editor's
## 3D viewport so it can be inspected directly (the game builds the same city
## at runtime when a Factionless player enters the Arlington hub chunk).
##
## Open res://src/dev/arlington_city_view.tscn while this script is compiled.
var _built: bool = false
func _ready() -> void:
	if not Engine.is_editor_hint(): return
	if _built: return
	_built = true
	_build_preview()

func _build_preview() -> void:
	var MegaCB: GDScript = load("res://src/world/city/mega_city_builder.gd")
	var sky: Node = load("res://src/world/overworld/day_night_sky.gd").new()
	var city: Node3D = MegaCB.build("arlington", Vector3.ZERO, sky,
		func(x, z): return 0.0, null)
	city.name = "MegaCity_arlington"
	add_child(city)
	# Ground/plaza under the city so the viewport has a floor reference.
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = BoxMesh.new()
	var gb: BoxMesh = ground.mesh
	gb.size = Vector3(300, 0.4, 300)
	ground.position = Vector3(150, -0.3, -1771)
	add_child(ground)
	# A framing camera for the scene preview.
	var cam := Camera3D.new()
	cam.name = "CityCam"
	var eye := Vector3(190, 130, 140)
	cam.position = eye
	cam.look_at_from_position(eye, Vector3(150, 40, -1771))
	add_child(cam)
	print("CITY_TOOL: built arlington city, children=", city.get_child_count())
