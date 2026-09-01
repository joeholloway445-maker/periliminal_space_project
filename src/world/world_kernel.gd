extends Node
const LAYERS := { "subliminal": "subliminal", "liminal": "liminal" }
var state := {}
func _ready() -> void:
	state = {
		"layer": "subliminal",
		"identity": { "race": "perihuman", "frame": "balanced", "mod": "none", "genome": "PH-40-00000" },
		"player": { "hp": 100, "maxHp": 100, "x": 4.0, "y": 2.0, "z": 8.0 },
		"discoveries": {},
		"apex_promotions": 0,
	}
func region_id(x: float, z: float) -> String:
	return "%d:%d" % [floor(x / 24.0), floor(z / 24.0)]
func set_layer(layer: String) -> void:
	if state["layer"] == layer:
		return
	state["layer"] = layer
func gravity_for(layer: String) -> float:
	return 12.0 if layer == "liminal" else 22.0
