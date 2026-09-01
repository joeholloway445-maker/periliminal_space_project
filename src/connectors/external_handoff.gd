extends Node
## THE-HDV-CORE <-> this client. Parses --player-id and --return-to.

var incoming_player_id: String = ""
var return_to_world_id: String = ""

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--player-id="):
			incoming_player_id = arg.substr("--player-id=".length())
		elif arg.begins_with("--return-to="):
			return_to_world_id = arg.substr("--return-to=".length())
	if not incoming_player_id.is_empty():
		Session.player_id = incoming_player_id

func has_incoming() -> bool:
	return not incoming_player_id.is_empty()
