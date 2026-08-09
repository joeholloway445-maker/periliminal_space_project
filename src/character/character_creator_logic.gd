class_name CharacterCreatorLogic
# Pure logic for the character creator — no UI dependency
# Autoload access via AutoloadGate (class_name scripts must not bare-ref Autoloads).

## Maps hdv lore frame stats (agility/power/resonance/frequency) to gameplay
## stats (spd/pow/res/lck/sty) so the Periliminal identity frames work with
## the existing combat/racing stat system.  Derived from FrameData.FRAMES.
const HDV_FRAME_STAT_MAP: Dictionary = {
	"skirmisher":  {"spd": 6, "pow": 0, "res": -2, "lck": 5, "sty": 2},
	"strider":     {"spd": 8, "pow": -4, "res": -2, "lck": 5, "sty": 4},
	"skybound":    {"spd": 6, "pow": -2, "res": 0, "lck": 5, "sty": 2},
	"flicker":     {"spd": 8, "pow": -2, "res": 2, "lck": 5, "sty": 0},
	"marshal":     {"spd": 2, "pow": 0, "res": 4, "lck": 5, "sty": 0},
	"bloom":       {"spd": 4, "pow": -2, "res": 2, "lck": 5, "sty": 2},
	"rewind":      {"spd": 4, "pow": -4, "res": 6, "lck": 5, "sty": 2},
	"conduit":     {"spd": 2, "pow": -2, "res": 4, "lck": 5, "sty": 4},
	"shade":       {"spd": 6, "pow": 2, "res": -2, "lck": 5, "sty": -2},
	"fabricator":  {"spd": 2, "pow": -2, "res": 0, "lck": 5, "sty": 6},
	"bastion":     {"spd": -6, "pow": 8, "res": -2, "lck": 5, "sty": -4},
	"juggernaut":  {"spd": -4, "pow": 8, "res": -4, "lck": 5, "sty": -4},
	"gravemind":   {"spd": -6, "pow": 4, "res": 2, "lck": 5, "sty": -4},
	"riftbreaker": {"spd": -6, "pow": 4, "res": 4, "lck": 5, "sty": -4},
	"sovereign":   {"spd": -6, "pow": 4, "res": 6, "lck": 5, "sty": -6},
	"worldroot":   {"spd": -6, "pow": 6, "res": 0, "lck": 5, "sty": -2},
	"epoch":       {"spd": -6, "pow": 2, "res": 8, "lck": 5, "sty": -4},
	"overlord":    {"spd": -8, "pow": 8, "res": 2, "lck": 5, "sty": -6},
	"obscura":     {"spd": -6, "pow": 2, "res": 6, "lck": 5, "sty": -4},
	"architect":   {"spd": -8, "pow": 6, "res": -2, "lck": 5, "sty": 2},
}

static func build_starting_stats(race_id: String, faction: String, frame_id: String, mod_id: String = "") -> Dictionary:
	var base := {pow=10, res=10, spd=10, lck=10, sty=10}
	var race_bonuses := RaceDataCharacter.get_stat_bonuses(race_id)
	for stat in race_bonuses.keys():
		base[stat] = base.get(stat, 0) + race_bonuses[stat]
	var faction_bonuses: Dictionary = {}
	var factions := AutoloadGate.get_node("FactionSystem")
	if factions and factions.has_method("get_stat_bonuses"):
		faction_bonuses = factions.call("get_stat_bonuses", faction)
	for stat in faction_bonuses.keys():
		base[stat] = base.get(stat, 0) + faction_bonuses.get(stat, 0)
	# Frame bonuses: try HDV lore frames first (Periliminal identity set),
	# then fall back to legacy FrameModData (Hyperliminal sensorium).
	if HDV_FRAME_STAT_MAP.has(frame_id):
		for stat in HDV_FRAME_STAT_MAP[frame_id].keys():
			base[stat] = base.get(stat, 0) + HDV_FRAME_STAT_MAP[frame_id][stat]
	else:
		base = FrameModData.apply_frame_stats(frame_id, base)
	if not mod_id.is_empty():
		base = FrameModData.apply_mod_stats(mod_id, base)
	return base

static func validate_name(player_name: String) -> bool:
	var trimmed := player_name.strip_edges()
	if trimmed.length() < 2 or trimmed.length() > 20:
		return false
	# Allow spaces between words; reject control / punctuation noise.
	var cleaned := trimmed.replace(" ", "")
	return cleaned.is_valid_identifier()

static func get_starter_companions(faction: String) -> Array[String]:
	match faction:
		"SovereignCrown": return ["SC001", "SC002"]
		"WildlandsAscendant": return ["WA001", "WA002"]
		"VeiledCurrent": return ["VC001", "VC002"]
		_: return ["FL001", "FL002"]

static func build_loadout(race_id: String, frame_id: String, mod_id: String = "") -> Dictionary:
	var frame_data: Dictionary = {}
	var hdv_frame: Dictionary = {}
	if HDV_FRAME_STAT_MAP.has(frame_id):
		const FrameData = preload("res://hdv_lore/src/data/frame_data.gd")
		hdv_frame = FrameData.by_id(frame_id)
		frame_data = hdv_frame.duplicate()
		frame_data["stat_bonus"] = HDV_FRAME_STAT_MAP[frame_id].duplicate()
	else:
		frame_data = FrameModData.get_frame(frame_id)
	return {
		"race": RaceDataCharacter.get_race(race_id),
		"frame": frame_data,
		"mod": FrameModData.get_mod(mod_id) if not mod_id.is_empty() else {},
	}

static func apply_creation(race_id: String, faction: String, frame_id: String, player_name: String,
		sex: String = "m", appearance: Dictionary = {}) -> void:
	var profile := AutoloadGate.get_node("PlayerProfile")
	if profile == null:
		push_error("CharacterCreatorLogic: PlayerProfile unavailable")
		return
	profile.call("set_faction", faction)
	profile.call("set_race", race_id)
	profile.call("set_frame", frame_id)
	profile.call("set_sex", sex)
	if not appearance.is_empty() and profile.has_method("set_appearance"):
		for k in appearance.keys():
			profile.call("set_appearance", k, appearance[k])
	profile.set("username", player_name.strip_edges())
	var companions := get_starter_companions(faction)
	var active: Array = profile.get("active_companion_ids")
	if active == null:
		active = []
	for c in companions:
		if c not in active:
			active.append(c)
	profile.set("active_companion_ids", active)
	profile.set("has_expedition", true)
	if profile.has_method("_save"):
		profile.call("_save")
	if profile.has_signal("profile_updated"):
		profile.emit_signal("profile_updated")
