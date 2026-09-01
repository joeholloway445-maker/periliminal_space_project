extends Node
## Endpoint map. Override at runtime with --bridge=https://host or user://bridge.json.

var bridge_base: String = "https://periliminal-rebuild-slice.vercel.app"
var casino_ticket_path: String = "/api/casino/ticket"
var casino_settle_path: String = "/api/casino/settle"
var hope_path: String = "/api/hope"
var vote_path: String = "/api/vote"
var secret_path: String = "/api/secret"
var persist_path: String = "/api/persist"
var nakama_path: String = "/api/nakama"
var supabase_path: String = "/api/supabase"
var health_path: String = "/api/health"

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--bridge="):
			bridge_base = arg.substr("--bridge=".length()).rstrip("/")
	var cfg := "user://bridge.json"
	if FileAccess.file_exists(cfg):
		var raw := FileAccess.get_file_as_string(cfg)
		var parsed: Variant = JSON.parse_string(raw)
		if typeof(parsed) == TYPE_DICTIONARY:
			var d: Dictionary = parsed
			bridge_base = str(d.get("bridge_base", bridge_base))

func url(path: String) -> String:
	return bridge_base.rstrip("/") + path
