extends Node
## KNOLL is the necessary other face of HOPE.
## Silent. Never player-facing speech. Never a spawn hill.

signal audited(entry: Dictionary)

var log: Array = []

func record(kind: String, detail: String = "") -> void:
	var entry := {
		"t": Time.get_unix_time_from_system(),
		"kind": kind,
		"detail": detail,
	}
	log.append(entry)
	if log.size() > 64:
		log.pop_front()
	audited.emit(entry)

func difficulty_mod() -> float:
	if has_node("/root/Consistency"):
		return Consistency.difficulty_mod()
	return 1.0
