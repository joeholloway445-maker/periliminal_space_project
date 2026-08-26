## test/audit/test_character_stats.gd
## GdUnit4 tests for CharacterStats (src/character/character_stats.gd)
## and SkillCastResolver.windup_for (src/skills/skill_cast_resolver.gd).
##
## CharacterStats extends Resource — .new() constructs it without any scene or
## autoload, so all methods that operate on internal state are testable here.
##
## SkillCastResolver.windup_for() is a pure static function with no autoload
## dependencies — tested via its class_name registration.
extends GdUnitTestSuite


func _make_stats() -> CharacterStats:
	return auto_free(CharacterStats.new())


# ---------------------------------------------------------------------------
# A. CharacterStats — default values
# ---------------------------------------------------------------------------

func test_default_pow_is_50() -> void:
	var s := _make_stats()
	assert_int(s.get_stat("pow")).is_equal(50)

func test_default_res_is_50() -> void:
	var s := _make_stats()
	assert_int(s.get_stat("res")).is_equal(50)

func test_default_spd_is_50() -> void:
	var s := _make_stats()
	assert_int(s.get_stat("spd")).is_equal(50)

func test_default_lck_is_50() -> void:
	var s := _make_stats()
	assert_int(s.get_stat("lck")).is_equal(50)

func test_default_sty_is_50() -> void:
	var s := _make_stats()
	assert_int(s.get_stat("sty")).is_equal(50)

func test_unknown_stat_returns_zero() -> void:
	var s := _make_stats()
	assert_int(s.get_stat("void_stat")).is_equal(0)


# ---------------------------------------------------------------------------
# B. CharacterStats — get_all_stats shape
# ---------------------------------------------------------------------------

func test_get_all_stats_has_five_keys() -> void:
	var s := _make_stats()
	var all: Dictionary = s.get_all_stats()
	assert_int(all.size()).is_equal(5)

func test_get_all_stats_contains_expected_keys() -> void:
	var s := _make_stats()
	var all: Dictionary = s.get_all_stats()
	for k in ["pow", "res", "spd", "lck", "sty"]:
		assert_bool(all.has(k)).is_true()


# ---------------------------------------------------------------------------
# C. CharacterStats — faction multiplier
# ---------------------------------------------------------------------------

func test_faction_mult_one_leaves_stats_unchanged() -> void:
	var s := _make_stats()
	s.set_faction_mult(1.0)
	assert_int(s.get_stat("pow")).is_equal(50)

func test_faction_mult_doubles_stat() -> void:
	var s := _make_stats()
	s.set_faction_mult(2.0)
	assert_int(s.get_stat("pow")).is_equal(100)

func test_faction_mult_zero_zeroes_all_stats() -> void:
	var s := _make_stats()
	s.set_faction_mult(0.0)
	for k in ["pow", "res", "spd", "lck", "sty"]:
		assert_int(s.get_stat(k)).is_equal(0)


# ---------------------------------------------------------------------------
# D. CharacterStats — companion synergy bonus
# ---------------------------------------------------------------------------

func test_companion_synergy_adds_to_stat() -> void:
	var s := _make_stats()
	s.apply_companion_synergy({"pow": 20})
	assert_int(s.get_stat("pow")).is_equal(70)

func test_companion_synergy_affects_only_specified_stat() -> void:
	var s := _make_stats()
	s.apply_companion_synergy({"pow": 20})
	assert_int(s.get_stat("res")).is_equal(50)

func test_companion_synergy_overrides_previous() -> void:
	var s := _make_stats()
	s.apply_companion_synergy({"pow": 20})
	s.apply_companion_synergy({"pow": 5})
	assert_int(s.get_stat("pow")).is_equal(55)


# ---------------------------------------------------------------------------
# E. CharacterStats — consumable bonus
# ---------------------------------------------------------------------------

func test_consumable_bonus_adds_to_stat() -> void:
	var s := _make_stats()
	s.apply_consumable({"lck": 10})
	assert_int(s.get_stat("lck")).is_equal(60)

func test_clear_consumable_removes_bonus() -> void:
	var s := _make_stats()
	s.apply_consumable({"lck": 10})
	s.clear_consumable()
	assert_int(s.get_stat("lck")).is_equal(50)


# ---------------------------------------------------------------------------
# F. CharacterStats — combat power calculation
# ---------------------------------------------------------------------------

func test_get_combat_power_default() -> void:
	# pow=50, lck=50, sty=50 → 50 + int(50*0.3) + int(50*0.1) = 50+15+5 = 70
	var s := _make_stats()
	assert_int(s.get_combat_power()).is_equal(70)

func test_get_combat_power_scales_with_companion_bonus() -> void:
	var s := _make_stats()
	s.apply_companion_synergy({"pow": 10})
	# pow=60, lck=50, sty=50 → 60+15+5 = 80
	assert_int(s.get_combat_power()).is_equal(80)


# ---------------------------------------------------------------------------
# G. CharacterStats — check_sleeper_burst
# ---------------------------------------------------------------------------

func test_sleeper_burst_false_by_default() -> void:
	var s := _make_stats()
	assert_bool(s.check_sleeper_burst()).is_false()

func test_sleeper_burst_false_when_lck_high_but_mult_low() -> void:
	var s := _make_stats()
	s.apply_companion_synergy({"lck": 30})  # lck = 80
	s.set_faction_mult(1.0)                 # mult < 1.2
	assert_bool(s.check_sleeper_burst()).is_false()

func test_sleeper_burst_true_when_both_thresholds_met() -> void:
	var s := _make_stats()
	s.apply_companion_synergy({"lck": 30})  # base lck = 50+30 = 80, then *1.2 = 96 >= 80
	s.set_faction_mult(1.2)
	assert_bool(s.check_sleeper_burst()).is_true()


# ---------------------------------------------------------------------------
# H. SkillCastResolver.windup_for — pure static logic
# ---------------------------------------------------------------------------

func test_windup_default_damage_kind() -> void:
	# power=1.0 → clamp(1.0/2+0.5, 0.6, 1.4)=1.0 → 0.22*1.0 = 0.22
	var w: float = SkillCastResolver.windup_for({})
	assert_float(w).is_equal_approx(0.22, 0.001)

func test_windup_ult_cost_nonzero_returns_ult_constant() -> void:
	var w: float = SkillCastResolver.windup_for({"ult_cost": 3})
	assert_float(w).is_equal_approx(0.38, 0.001)

func test_windup_shield_kind_returns_utility_constant() -> void:
	var w: float = SkillCastResolver.windup_for({"kind": "shield"})
	assert_float(w).is_equal_approx(0.12, 0.001)

func test_windup_buff_kind_returns_utility_constant() -> void:
	var w: float = SkillCastResolver.windup_for({"kind": "buff"})
	assert_float(w).is_equal_approx(0.12, 0.001)

func test_windup_mobility_kind_returns_utility_constant() -> void:
	var w: float = SkillCastResolver.windup_for({"kind": "mobility"})
	assert_float(w).is_equal_approx(0.12, 0.001)

func test_windup_high_power_clamped_at_max() -> void:
	# power=4.0 → clamp(4.0/2+0.5, 0.6, 1.4)=1.4 → 0.22*1.4 = 0.308
	var w: float = SkillCastResolver.windup_for({"power": 4.0})
	assert_float(w).is_equal_approx(0.308, 0.001)

func test_windup_zero_power_clamped_at_min() -> void:
	# power=0.0 → clamp(0.0/2+0.5, 0.6, 1.4)=0.6 → 0.22*0.6 = 0.132
	var w: float = SkillCastResolver.windup_for({"power": 0.0})
	assert_float(w).is_equal_approx(0.132, 0.001)

func test_windup_ult_overrides_kind() -> void:
	# ult_cost check comes first, so kind is irrelevant
	var w: float = SkillCastResolver.windup_for({"ult_cost": 1, "kind": "shield"})
	assert_float(w).is_equal_approx(0.38, 0.001)
