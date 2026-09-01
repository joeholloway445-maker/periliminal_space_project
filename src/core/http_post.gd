class_name HttpPost
extends RefCounted
## Shared fire-and-forget POST. Callers own result handling when they pass a callback.

static func send(host: Node, url: String, payload: Dictionary, cb: Callable = Callable()) -> void:
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		var d: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		if not ok:
			d["error"] = "http %s" % str(code)
			d["result"] = result
		if cb.is_valid():
			cb.call(ok, d)
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		if cb.is_valid():
			cb.call_deferred(false, {"error": "request err %s" % err})
