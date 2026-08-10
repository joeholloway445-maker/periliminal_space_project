extends SceneTree
## Headless smoke for the Blueprint Forge PRESETS catalog (build-order
## step 7 content: blueprint presets). Verifies every kind has curated
## starters, each preset stamps only valid params/audio keys, and a
## preset-derived blueprint survives clamp_params (share-code round-trip)
## so seeded designs can never corrupt the library.
## Run: godot --headless --path . -s res://src/dev/blueprint_presets_smoke.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[blueprint_presets_smoke] start")
	await process_frame
	var ok := true

	for kind in BlueprintData.KINDS:
		var names: Array[String] = BlueprintData.preset_names(kind)
		if names.is_empty():
			ok = false
			print("[blueprint_presets_smoke] %s has no presets FAIL" % kind)
			continue
		for n in names:
			var bp: Dictionary = BlueprintData.preset_bp(kind, n, n)
			if bp.is_empty():
				ok = false
				print("[blueprint_presets_smoke] preset_bp(%s,%s) empty FAIL" % [kind, n])
				continue
			if str(bp.kind) != kind:
				ok = false
				print("[blueprint_presets_smoke] %s/%s wrong kind FAIL" % [kind, n])
			# Only valid defs keys may have been stamped.
			var valid: Dictionary = {}
			for d in BlueprintData.defs_for(kind):
				valid[d.key] = true
			for k in bp.params:
				if not valid.has(k):
					ok = false
					print("[blueprint_presets_smoke] %s/%s unknown param '%s' FAIL" % [kind, n, k])
			# Round-trip: a clamped preset must survive (share-code safety).
			var clamped: Dictionary = BlueprintData.clamp_params(bp)
			if clamped.is_empty() or str(clamped.name) != n:
				ok = false
				print("[blueprint_presets_smoke] %s/%s clamp round-trip FAIL" % [kind, n])

	# BlueprintManager must create from a named preset.
	var BlueprintManager = AutoloadGate.get_node("BlueprintManager")
	var created: Dictionary = BlueprintManager.create("weapon", "custom", "Ember Fang", "Ember Fang")
	if created.is_empty():
		ok = false
		print("[blueprint_presets_smoke] manager create(preset) empty FAIL")
	elif str(created.params.get("silhouette", "")) != "claw":
		ok = false
		print("[blueprint_presets_smoke] preset weapon params not stamped FAIL")
	else:
		print("[blueprint_presets_smoke] manager create(preset) stamped ok")

	# Unknown preset must fall back to a blank template, not fail.
	var blank: Dictionary = BlueprintManager.create("skill", "custom", "New Skill", "NoSuchPreset")
	if blank.is_empty():
		ok = false
		print("[blueprint_presets_smoke] unknown-preset fallback empty FAIL")

	if ok:
		print("[blueprint_presets_smoke] RESULT=PASS")
	else:
		print("[blueprint_presets_smoke] RESULT=FAIL")
	quit(0 if ok else 1)
