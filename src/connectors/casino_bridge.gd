extends Node
## Closed API. No in-engine chip RNG. Cabinet opens a ticket; web settles.

signal ticket_ready(ticket: Dictionary)
signal settled(result: Dictionary)
signal failed(reason: String)

var last_ticket: Dictionary = {}

func request_ticket(game_id: String, wager: int) -> void:
	if not Wallet.spend("chips", wager):
		failed.emit("not enough chips")
		return
	var payload := {
		"player_id": Session.player_id,
		"game": game_id,
		"wager": wager,
		"layer": LayerRouter.current,
	}
	_post(ConnectorConfig.url(ConnectorConfig.casino_ticket_path), payload, "_on_ticket")

func apply_settle(result: Dictionary) -> void:
	var payout := int(result.get("payout", 0))
	if payout > 0:
		Wallet.add("chips", payout)
	last_ticket = result
	settled.emit(result)
	Hope.say("Cabinet closed. The house kept the math.")

func _on_ticket(ok: bool, data: Dictionary) -> void:
	if not ok:
		Wallet.add("chips", int(data.get("wager", 0)))
		failed.emit(str(data.get("error", "ticket failed")))
		return
	last_ticket = data
	ticket_ready.emit(data)
	var play_url := str(data.get("play_url", ConnectorConfig.bridge_base + "/casino"))
	OS.shell_open(play_url)

func _post(url: String, payload: Dictionary, cb: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		var d: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			d["error"] = "http %s" % str(code)
			d["wager"] = payload.get("wager", 0)
			call(cb, false, d)
		else:
			call(cb, true, d)
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		call_deferred(cb, false, {"error": "request err %s" % err, "wager": payload.get("wager", 0)})
