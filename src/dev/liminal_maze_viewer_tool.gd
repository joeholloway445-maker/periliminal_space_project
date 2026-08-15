@tool
extends Node3D
## Editor tool: builds the Liminal's procedural maze in the editor's 3D
## viewport so it can be inspected directly. The game builds the same maze
## at runtime in layer_world._ready() — the .tscn is a bare root on purpose.
var _built: bool = false
func _ready() -> void:
	if not Engine.is_editor_hint(): return
	if _built: return
	_built = true
	_build()

func _build() -> void:
	var maze := LiminalHallwayBuilder.build(12345, 24, 4.0, 3.5, false)
	add_child(maze)
	var cam := Camera3D.new()
	cam.name = "MazeCam"
	var eye := Vector3(30, 3.0, 26)
	cam.position = eye
	cam.look_at_from_position(eye, Vector3(-8, 1.2, -6))
	add_child(cam)
	print("MAZE_TOOL: built liminal maze, children=", maze.get_child_count())
