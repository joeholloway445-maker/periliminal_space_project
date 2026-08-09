extends SceneTree
func _init() -> void:
	# No casino skin files exist yet, so all cat-skin requests fall back to core art.
	# Hyperliminal PvE (no permission needed, just no skin file) -> fallback OK
	var hyper_pve: Texture2D = IdentityArt.portrait_for_layer("tabby", "hyperliminal", "m", "", "", false, false, false)
	print("hyperliminal pve fallback = " + ("OK" if hyper_pve != null else "null"))
	# Hyperliminal PvP -> must use core fighter sprite
	var hyper_pvp: Texture2D = IdentityArt.portrait_for_layer("tabby", "hyperliminal", "m", "", "", true, false, false)
	print("hyperliminal pvp = " + ("OK" if hyper_pvp != null else "null"))
	# Extraliminal with permission -> fallback (no skin file)
	var extra_perm: Texture2D = IdentityArt.portrait_for_layer("tabby", "extraliminal", "m", "", "", false, true, false)
	print("extraliminal with perm fallback = " + ("OK" if extra_perm != null else "null"))
	# Extraliminal without permission -> core
	var extra_no: Texture2D = IdentityArt.portrait_for_layer("tabby", "extraliminal", "m", "", "", false, false, false)
	print("extraliminal no perm = " + ("OK" if extra_no != null else "null"))
	print("SMOKE=PASS")
	quit(0)
