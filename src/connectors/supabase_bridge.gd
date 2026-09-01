extends Node
## Currency + telemetry replica stub. Failures stay local.

signal synced(ok: bool)

func sync_wallet() -> void:
	HttpPost.send(self, ConnectorConfig.url(ConnectorConfig.supabase_path), {
		"player_id": Session.player_id,
		"wallet": Wallet.all(),
		"bond": Hope.bond,
		"stance": Consistency.stance,
	}, func(ok: bool, _d: Dictionary):
		synced.emit(ok)
	)
