extends Node
## Door tracking. Hidden doors stay unlabeled.

signal used(from_layer: String, to_layer: String, kind: String)

var history: Array = []

func log_door(from_layer: String, to_layer: String, kind: String) -> void:
	var entry := {
		"t": Time.get_unix_time_from_system(),
		"from": from_layer,
		"to": to_layer,
		"kind": kind,
	}
	history.append(entry)
	if history.size() > 48:
		history.pop_front()
	used.emit(from_layer, to_layer, kind)
	if has_node("/root/Knoll"):
		Knoll.record("door", "%s:%s:%s" % [from_layer, to_layer, kind])
	_save()

func _save() -> void:
	var f := FileAccess.open("user://doors.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(history))
