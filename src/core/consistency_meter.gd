extends Node
## Stance from deed variance. Consistent good or consistent bad is easy.

signal stance_changed(stance: String)

var good: int = 0
var bad: int = 0
var stance: String = "untested"

func record_deed(kind: String) -> void:
	match kind:
		"help", "witness":
			good += 1
		"attack", "stalker":
			bad += 1
	_recompute()
	if has_node("/root/Knoll"):
		Knoll.record(kind, stance)
	if has_node("/root/Hope"):
		Hope.on_deed(kind)

func _recompute() -> void:
	var total: int = good + bad
	var next := stance
	if total < 4:
		next = "untested"
	else:
		var ratio := float(good) / float(total)
		if ratio >= 0.75:
			next = "consistent_good"
		elif ratio <= 0.25:
			next = "consistent_bad"
		else:
			next = "fractured"
	if next != stance:
		stance = next
		stance_changed.emit(stance)

func difficulty_mod() -> float:
	match stance:
		"consistent_good", "consistent_bad":
			return 0.85
		"fractured":
			return 1.45
		_:
			return 1.0
