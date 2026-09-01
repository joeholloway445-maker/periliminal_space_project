extends Node
## POST HOPE lines + bond. Failures stay local.

func post_line(text: String) -> void:
	_post(ConnectorConfig.url(ConnectorConfig.hope_path), {
		"player_id": Session.player_id,
		"layer": LayerRouter.current,
		"text": text,
		"bond": Hope.bond,
		"stance": Consistency.stance,
	})

func _post(url: String, payload: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	http.request(url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
