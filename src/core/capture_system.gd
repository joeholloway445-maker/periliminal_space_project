extends Node
## Capture only by defeat. No catch-without-fight path.

func try_capture(entity_id: String, entity_name: String, hp_ratio: float) -> bool:
	if not has_node("/root/Party"):
		return false
	if Party.slots_free() <= 0:
		if has_node("/root/Hope"):
			Hope.say("Party full. Release one first.")
		return false
	var chance := 0.18 + clampf(1.0 - hp_ratio, 0.0, 1.0) * 0.22
	if has_node("/root/Hope"):
		chance += Hope.bond * 0.12
	if has_node("/root/LayerRouter") and LayerRouter.current == "periliminal":
		if has_node("/root/Knoll"):
			chance /= maxf(1.0, Knoll.difficulty_mod())
	if randf() > chance:
		if has_node("/root/Hope"):
			Hope.say("It slipped the bond.")
		return false
	Party.bind(entity_id, entity_name)
	if has_node("/root/Hope"):
		Hope.say("Bound. Three is the ceiling.")
	if has_node("/root/Knoll"):
		Knoll.record("capture", entity_id)
	return true
