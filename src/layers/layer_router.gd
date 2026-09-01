extends Node
## Six layers. Invariants from AGENTS.md.

signal layer_changed(from_id: String, to_id: String)

const LAYERS := {
	"subliminal": {"name": "Subliminal", "persist": "personal", "currency": "charges", "pvp": false, "entry": "invite"},
	"liminal": {"name": "Liminal", "persist": "ephemeral", "currency": "tokens", "pvp": true, "entry": "always"},
	"supraliminal": {"name": "Superliminal", "persist": "chunked", "currency": "tokens", "pvp": "outside_hubs", "entry": "always"},
	"hyperliminal": {"name": "Hyperliminal", "persist": "static", "currency": "chips", "pvp": true, "entry": "always"},
	"extraliminal": {"name": "Extraliminal", "persist": "landmark", "currency": "charges", "pvp": "guild_wars", "entry": "always"},
	"periliminal": {"name": "Periliminal", "persist": "generated_then_static", "currency": "fragments", "pvp": false, "entry": "liminal_wander"},
}

var current: String = "subliminal"
var wander_s: float = 0.0
var pull_threshold: float = 0.0
var prototype_mode: bool = true

func _ready() -> void:
	_roll_pull()

func _process(delta: float) -> void:
	if current == "liminal":
		wander_s += delta
		if wander_s >= pull_threshold:
			enter("periliminal", "pull")

func info() -> Dictionary:
	return LAYERS.get(current, {})

func gravity() -> float:
	match current:
		"liminal":
			return 6.4
		"periliminal":
			return 14.0
		"hyperliminal":
			return 9.2
		_:
			return 9.8

func fog() -> Color:
	match current:
		"liminal":
			return Color(0.15, 0.22, 0.24)
		"periliminal":
			return Color(0.08, 0.04, 0.05)
		"hyperliminal":
			return Color(0.12, 0.04, 0.16)
		"extraliminal":
			return Color(0.06, 0.12, 0.08)
		"supraliminal":
			return Color(0.18, 0.17, 0.16)
		_:
			return Color(0.10, 0.10, 0.12)

func enter(layer_id: String, reason: String = "door") -> bool:
	if not LAYERS.has(layer_id):
		return false
	if layer_id == "periliminal" and reason != "pull" and reason != "dev":
		return false
	var from := current
	current = layer_id
	if layer_id == "liminal":
		wander_s = 0.0
		_roll_pull()
	layer_changed.emit(from, layer_id)
	if has_node("/root/Hope"):
		Hope.on_layer(layer_id)
	if has_node("/root/Knoll"):
		Knoll.record("layer", "%s->%s:%s" % [from, layer_id, reason])
	return true

func recall_to_subliminal() -> void:
	enter("subliminal", "recall")

func blessing_exit() -> void:
	enter("subliminal", "blessing")
	if has_node("/root/Wallet"):
		Wallet.add("prestige", 1)
		Wallet.add("fragments", 8)

func _roll_pull() -> void:
	if prototype_mode:
		pull_threshold = 18.0
	else:
		pull_threshold = randf_range(420.0, 900.0)
