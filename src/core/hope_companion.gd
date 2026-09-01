extends Node
## HOPE stays with the player on every layer. Speaks. Observes deeds.

signal spoke(text: String)

var last_line: String = "I am with you. The apartment is yours until you open a door."
var bond: float = 0.2

func _ready() -> void:
	spoke.emit(last_line)

func say(text: String) -> void:
	last_line = text
	spoke.emit(text)
	if has_node("/root/HopeBridge"):
		HopeBridge.post_line(text)

func on_layer(layer_id: String) -> void:
	match layer_id:
		"subliminal":
			say("Private space. Build here. The door to Liminal is obvious on purpose.")
		"liminal":
			say("Do not linger. Chunks die behind you. I will keep the door log.")
		"supraliminal":
			say("Metroplex dirt is shared. Hidden doors have no tell.")
		"hyperliminal":
			say("The cabinet is a window. Chips leave the engine before they spin.")
		"extraliminal":
			say("Landmarks only. Guild wars open a Liminal door. I stay.")
		"periliminal":
			say("No countdown was owed to you. Consistency is the only mercy.")
		_:
			say("I am still here.")

func on_deed(kind: String) -> void:
	match kind:
		"help":
			bond = clampf(bond + 0.04, 0.0, 1.0)
			say("That held.")
		"witness":
			say("Seen. Stored.")
		"attack":
			say("I logged the strike. KNOLL will too.")
		"stalker":
			say("Inconsistent gait. The gauntlet will notice later.")
		_:
			say("Noted.")
