extends Node
## HOPE is permanent. 0–3 bindable entities. Capture only by defeat.

signal party_changed

var bound: Array = []

func slots_free() -> int:
	return maxi(0, 3 - bound.size())

func bind(entity_id: String, name: String) -> bool:
	if slots_free() <= 0:
		return false
	for e in bound:
		if str(e.get("id", "")) == entity_id:
			return false
	bound.append({"id": entity_id, "name": name})
	party_changed.emit()
	return true

func release(entity_id: String) -> void:
	bound = bound.filter(func(e): return str(e.get("id", "")) != entity_id)
	party_changed.emit()
