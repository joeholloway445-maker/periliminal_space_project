extends Node
## First-ever Recall Walk (and later unlabeled secrets) POST to /api/secret.

func report(kind: String) -> void:
	HttpPost.send(self, ConnectorConfig.url(ConnectorConfig.secret_path), {
		"player_id": Session.player_id,
		"kind": kind,
		"layer": LayerRouter.current,
		"t": Time.get_unix_time_from_system(),
	})
