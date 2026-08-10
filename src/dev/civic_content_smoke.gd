extends SceneTree
## Headless smoke for build-order step 7 civic content (dialogue + audio):
##  - 6 civic venue dialogue blocks (banker/armorer/blacksmith/market/
##    stockyard/wager-hall) load through WorldLoader.get_dialogue — the same
##    path npc_dialogue_ui uses — and each is referenced by exactly 4 city
##    NPCs (arlington/dallas/fort_worth/denton).
##  - the 3 new civic one-shots (bank_coin/forge_clank/market_haggle) exist
##    under assets/audio/ as valid AudioStreamWAV and AssetLibrary serves
##    them by slot name.
## Run: godot --headless --path . -s res://src/dev/civic_content_smoke.gd

const DIALOGS := [
	"banker_dialogue", "armorer_dialogue", "blacksmith_dialogue",
	"market_trader_dialogue", "stockyard_herder_dialogue", "wager_hall_dialogue",
]
const SOUNDS := ["bank_coin", "forge_clank", "market_haggle"]
const CITIES := ["arlington", "dallas", "fort_worth", "denton"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[civic_content_smoke] start")
	await process_frame
	var ok := true

	var WorldLoader = AutoloadGate.get_node("WorldLoader")
	# Dialogues load synchronously in WorldLoader._ready from dialogue.json;
	# skip the one-shot world_loaded signal (already emitted) and just wait
	# a couple frames so autoloads finish wiring.
	await process_frame
	await process_frame

	# --- A. dialogue blocks reachable through the real runtime lookup ---
	for did in DIALOGS:
		var d: Dictionary = WorldLoader.get_dialogue(did)
		if d.is_empty():
			ok = false
			print("[civic_content_smoke] %s not reachable via WorldLoader FAIL" % did)
			continue
		if str(d.get("start_node", "")) != "greeting" or not (d.get("nodes", []) is Array):
			ok = false
			print("[civic_content_smoke] %s malformed FAIL" % did)
			continue
		# every node has id + text; every option a next_node
		for nd in d.nodes:
			if str(nd.get("id", "")) == "" or str(nd.get("text", "")) == "":
				ok = false
				print("[civic_content_smoke] %s node missing id/text FAIL" % did)
			for op in nd.get("options", []):
				if str(op.get("next_node", "")) == "":
					ok = false
					print("[civic_content_smoke] %s option missing next_node FAIL" % did)

	# --- B. each civic venue referenced by one NPC per city ---
	var npc_path := "res://world_data/npcs.json"
	if not ResourceLoader.exists(npc_path):
		print("[civic_content_smoke] npcs.json missing FAIL")
		ok = false
	else:
		var raw := FileAccess.get_file_as_string(npc_path)
		var parsed = JSON.parse_string(raw)
		if not parsed is Dictionary:
			ok = false
			print("[civic_content_smoke] npcs.json parse FAIL")
		else:
			var npcs: Array = parsed.get("npcs", [])
			for did in DIALOGS:
				var per_city := {}
				for e in npcs:
					if str(e.get("dialogue_id", "")) == did:
						per_city[str(e.get("district", ""))] = true
				for c in CITIES:
					if not per_city.has(c):
						ok = false
						print("[civic_content_smoke] %s has no NPC in %s FAIL" % [did, c])

	# --- C. civic audio slots exist and resolve ---
	for slot in SOUNDS:
		var path := "res://assets/audio/%s.wav" % slot
		if not ResourceLoader.exists(path):
			ok = false
			print("[civic_content_smoke] missing asset %s FAIL" % path)
			continue
		var res := load(path)
		if not res is AudioStreamWAV:
			ok = false
			print("[civic_content_smoke] %s not AudioStreamWAV FAIL" % path)
			continue
		# AssetLibrary.sound() must serve it by slot name (post-import).
		var served := AssetLibrary.sound(slot)
		if served == null and not AssetLibrary.has_sound(slot):
			print("[civic_content_smoke] %s loads but AssetLibrary.sound() null (import pending)" % slot)

	if ok:
		print("[civic_content_smoke] RESULT=PASS")
	else:
		print("[civic_content_smoke] RESULT=FAIL")
	quit(0 if ok else 1)
