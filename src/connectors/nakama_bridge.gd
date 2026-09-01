extends Node
## Presence stub. Real Nakama lives in the monorepo addon. This client only pings.

signal presence(ok: bool, body: Dictionary)

var last: Dictionary = {}

func heartbeat() -> void:
	HttpPost.send(self, ConnectorConfig.url(ConnectorConfig.nakama_path), {
		"player_id": Session.player_id,
		"layer": LayerRouter.current,
		"party": Party.bound.size(),
	}, func(ok: bool, d: Dictionary):
		last = d
		presence.emit(ok, d)
	)
