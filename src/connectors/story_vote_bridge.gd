extends Node
## One vote per ballot per server day. Soft cap only.

signal voted(ok: bool, body: Dictionary)

func cast(ballot_id: String, choice: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, _h, body):
		http.queue_free()
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		var d: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		voted.emit(result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, d)
	)
	var payload := {
		"player_id": Session.player_id,
		"ballot": ballot_id,
		"choice": choice,
	}
	http.request(ConnectorConfig.url(ConnectorConfig.vote_path), PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
