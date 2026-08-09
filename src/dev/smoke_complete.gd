extends SceneTree
func _init() -> void:
	var missing: Array[String] = []
	var total := 0
	for race in ["crownless","lumenari","veilstriders","coldmarrow","pulseborn","thorned","mirekin","dreamflesh","starfall","deepborne","echoes","chronarchs","gutterkin","glassborn","rotweavers","ashen_choir","nullborn","hollowed","riftspawn","sunspun"]:
		for sex in ["m", "f"]:
			for frame in ["skirmisher","strider","skybound","flicker","marshal","bloom","rewind","conduit","shade","fabricator","bastion","juggernaut","gravemind","riftbreaker","sovereign","worldroot","epoch","overlord","obscura","architect"]:
				for mod in ["heavy_siege","swiftburner","multi_limbed","towering","compact","elastic","floating_core","split_form","inverted_spine","modular","armored","lithe","tendril","rooted","hover_strider","centroid","shardform","quadruped","serpentine","colossus"]:
					total += 1
					var tex: Texture2D = IdentityArt.portrait(race, sex, frame, mod)
					if tex == null:
						missing.append(race + "_" + sex + "_" + frame + "_" + mod)
	print("total checked: " + str(total))
	print("missing: " + str(missing.size()))
	if missing.size() > 0:
		print("first 10 missing: " + ", ".join(missing.slice(0, 10)))
	print("SMOKE=" + ("PASS" if missing.is_empty() else "FAIL"))
	quit(0)
