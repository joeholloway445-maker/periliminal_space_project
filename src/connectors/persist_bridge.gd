extends Node
## Wallet + identity snapshot. Local file is source of play; bridge is optional replica.

func push() -> void:
	HttpPost.send(self, ConnectorConfig.url(ConnectorConfig.persist_path), {
		"player_id": Session.player_id,
		"identity": Session.identity(),
		"wallet": Wallet.all(),
		"party": Party.bound,
		"stance": Consistency.stance,
		"layer": LayerRouter.current,
	})
