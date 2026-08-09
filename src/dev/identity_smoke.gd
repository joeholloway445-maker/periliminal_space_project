extends SceneTree
## Headless smoke for the identity/portrait chain: casino skins exist,
## frame/mod resolve differently from base, sex differs, layer rules work.
## Run: godot --headless --path . -s res://src/dev/identity_smoke.gd

func _init() -> void:
	var failures: Array[String] = []
	const IA = preload("res://src/data/identity_art.gd")
	var all_races := ["tabby","siamese","maine_coon","persian","bengal","russian_blue","sphynx","ragdoll","scottish_fold","abyssinian","burmese","turkish_angora","norwegian_forest","birman","tonkinese","devon_rex","oriental","somali","manx","savannah"]
	for rid in all_races:
		for s in ["m", "f"]:
			if not IA.has_casino_skin(rid, s):
				failures.append("missing casino skin %s_%s" % [rid, s])
	var base: Texture2D = IA.portrait("lumenari", "m")
	var framed: Texture2D = IA.portrait("lumenari", "m", "bastion")
	if base == null or framed == null:
		failures.append("portrait null base=%s framed=%s" % [base == null, framed == null])
	elif base == framed:
		failures.append("frame portrait equals base portrait")
	# Mod art (slug_m_<mod>.jpg) must now win over frame art when both are
	# requested — the old walk let the always-present frame shadow the mod.
	var modded: Texture2D = IA.portrait("lumenari", "m", "bastion", "towering")
	if modded == null:
		failures.append("mod portrait null")
	elif modded == framed:
		failures.append("mod portrait equals frame portrait")
	var fm: Texture2D = IA.portrait("lumenari", "m")
	var ff: Texture2D = IA.portrait("lumenari", "f")
	if fm != null and ff != null and fm == ff:
		failures.append("male portrait equals female portrait")
	var cat: Texture2D = IA.portrait_for_layer("tabby", "hyperliminal", "m", "", "", false, false, false)
	var human: Texture2D = IA.portrait_for_layer("tabby", "hyperliminal", "m", "", "", true, false, false)
	if cat == null or cat == human:
		failures.append("hyperliminal PvE does not resolve a cat skin")
	if failures.is_empty():
		print("IDENTITY_SMOKE=RESULT:PASS")
	else:
		for f_ in failures:
			print("IDENTITY_SMOKE=FAIL: ", f_)
	quit()
