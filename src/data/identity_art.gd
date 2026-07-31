class_name IdentityArt
## Resolves a character build — race, sex, frame, mod — to its generated
## illustration in assets/entities/.
##
## Self-contained on purpose: the sprites are named by their Omni Dex id
## (crownless, lumenari, …), but the creator selects a race by breed id
## (tabby, …) or canon name (Keth, …). This carries the canon → Omni Dex map
## itself, so it works with the CanonRaces this repo already has and needs no
## other data file ported alongside it.
##
## Filenames (see the CATSINO.CASINO prompt pipeline that produced them):
##   crownless_m.png                 race + sex        (the base body)
##   crownless_m_bastion.png         + frame           (gear layer)
##   crownless_m_bastion_towering    + mod             (full stack)
##   crownless_f_swiftburner.png     race + sex + mod
##
## Lookup walks most-specific to least, so a build always resolves to the
## closest art that exists — the mod layer is ~95% generated, so a build
## whose exact mod is missing still shows the right race, sex and frame.

const DIR := "res://assets/entities/%s.png"

## canon race name (CanonRaces) -> Omni Dex id the sprites are filed under.
const CANON_TO_OMNIDEX := {
	"Keth": "crownless", "Lumari": "lumenari", "Vex": "veilstriders",
	"Kryos": "coldmarrow", "Volt": "pulseborn", "Sylva": "thorned",
	"Myco": "mirekin", "Chimera": "dreamflesh", "Astra": "starfall",
	"Aquis": "deepborne", "Geara": "echoes", "Azhul": "chronarchs",
	"Ferox": "gutterkin", "Petra": "glassborn", "Sanguis": "rotweavers",
	"Igni": "ashen_choir", "Nyx": "nullborn", "Etherea": "hollowed",
	"Ferros": "riftspawn", "Glyphe": "sunspun",
}

static var _cache: Dictionary = {}

## Best available illustration for the build, or null. `race_id` may be a
## breed id, a canon name, or the Omni Dex id itself. `sex` is "male"/"female"
## (or "m"/"f"); anything else means "no preference", trying male then plain.
static func portrait(race_id: String, sex: String = "", frame_id: String = "",
		mod_id: String = "") -> Texture2D:
	var slug := _omnidex_id(race_id)
	if slug.is_empty():
		return null

	var key := "%s|%s|%s|%s" % [slug, sex, frame_id, mod_id]
	if _cache.has(key):
		return _cache[key]

	# Sex letters to try, in order. An unspecified sex prefers male art then
	# the sexless base, so the creator is never blank while a preference is
	# still unset.
	var sexes: Array = []
	var sl := sex.substr(0, 1).to_lower()
	if sl == "m" or sl == "f":
		sexes = [sl, "", ("f" if sl == "m" else "m")]
	else:
		sexes = ["", "m", "f"]

	for s in sexes:
		var suffix := "_" + str(s) if str(s) != "" else ""
		var f := "_" + frame_id if not frame_id.is_empty() else ""
		var m := "_" + mod_id if not mod_id.is_empty() else ""
		for candidate in [slug + suffix + f + m, slug + suffix + f,
				slug + suffix + m, slug + suffix]:
			var path := DIR % candidate
			if ResourceLoader.exists(path):
				var tex := load(path)
				if tex is Texture2D:
					_cache[key] = tex
					return tex
	_cache[key] = null
	return null

static func has_portrait(race_id: String) -> bool:
	return portrait(race_id) != null

## Drop-in TextureRect for a build, or null when no art exists so a caller
## can keep whatever it drew before.
static func portrait_rect(race_id: String, sex: String = "", frame_id: String = "",
		mod_id: String = "", min_size := Vector2(240, 240)) -> TextureRect:
	var tex := portrait(race_id, sex, frame_id, mod_id)
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = min_size
	return rect

## Resolve any race id form to the Omni Dex slug the sprites use.
static func _omnidex_id(race_id: String) -> String:
	if race_id.is_empty():
		return ""
	# Already an Omni Dex id? (a sprite file exists for it directly)
	if ResourceLoader.exists(DIR % race_id.to_lower()):
		return race_id.to_lower()
	# A canon name (Keth) maps straight across.
	if CANON_TO_OMNIDEX.has(race_id):
		return str(CANON_TO_OMNIDEX[race_id])
	# A breed id (tabby): breed -> canon -> Omni Dex.
	if CanonRaces:
		var canon := CanonRaces.canon_for_id(race_id)
		if CANON_TO_OMNIDEX.has(canon):
			return str(CANON_TO_OMNIDEX[canon])
	return ""
