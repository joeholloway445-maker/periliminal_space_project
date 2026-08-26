# GdUnit4 suite for ApexOrchestrator observation logic and delegation queue.
# No autoloads or scene tree needed — pure in-memory unit tests.
# Run via: Godot Project → Tools → GdUnit4 (or CI godot --headless).
extends GdUnitTestSuite


func _make_apex() -> Node:
	return auto_free(load("res://src/core/apex_orchestrator.gd").new())


# ── API surface ────────────────────────────────────────────────────────────────

func test_apex_has_required_methods() -> void:
	var apex := _make_apex()
	assert_bool(apex.has_method("process_observation")).is_true()
	assert_bool(apex.has_method("delegate")).is_true()
	assert_bool(apex.has_method("get_system_load")).is_true()
	assert_bool(apex.has_method("get_response_history")).is_true()
	assert_bool(apex.has_method("get_pending_delegations")).is_true()
	assert_bool(apex.has_method("get_matrix_summary")).is_true()


# ── process_observation — first observation triggers onboarding ────────────────

func test_first_observation_returns_onboarding() -> void:
	var apex := _make_apex()
	var response: Dictionary = apex.process_observation("user_a", {})
	assert_str(str(response.get("action", ""))).is_equal("narrative_prompt")
	var params: Dictionary = response.get("params", {})
	assert_bool(bool(params.get("welcome", false))).is_true()


# ── process_observation — high entropy + low potential → re-engagement ─────────

func test_high_entropy_low_potential_triggers_reengagement() -> void:
	var apex := _make_apex()
	# Seed history so the onboarding branch does not override
	apex.process_observation("user_b", {"entropy": 0.5, "potential": 0.5, "trajectory": "stable"})
	var response: Dictionary = apex.process_observation("user_b", {
		"entropy": 0.8, "potential": 0.2, "trajectory": "stable"
	})
	assert_str(str(response.get("action", ""))).is_equal("narrative_prompt")
	assert_str(str(response.get("params", {}).get("type", ""))).is_equal("re_engagement")


# ── process_observation — flow state → increase challenge ─────────────────────

func test_flow_state_increases_difficulty() -> void:
	var apex := _make_apex()
	apex.process_observation("user_c", {"entropy": 0.5, "potential": 0.5})
	var response: Dictionary = apex.process_observation("user_c", {
		"entropy": 0.2, "potential": 0.8, "trajectory": "stable"
	})
	assert_str(str(response.get("action", ""))).is_equal("difficulty_scale")
	assert_str(str(response.get("params", {}).get("direction", ""))).is_equal("increase")


# ── process_observation — erratic trajectory → environment shift ───────────────

func test_erratic_trajectory_triggers_environment_shift() -> void:
	var apex := _make_apex()
	apex.process_observation("user_d", {"entropy": 0.5, "potential": 0.5})
	var response: Dictionary = apex.process_observation("user_d", {
		"entropy": 0.5, "potential": 0.5, "trajectory": "erratic"
	})
	assert_str(str(response.get("action", ""))).is_equal("environment_shift")
	assert_str(str(response.get("params", {}).get("type", ""))).is_equal("calming")


# ── process_observation — destabilizing → telemetry focus ─────────────────────

func test_destabilizing_trajectory_triggers_telemetry_focus() -> void:
	var apex := _make_apex()
	apex.process_observation("user_e", {"entropy": 0.5, "potential": 0.5})
	var response: Dictionary = apex.process_observation("user_e", {
		"entropy": 0.5, "potential": 0.5, "trajectory": "destabilizing"
	})
	assert_str(str(response.get("action", ""))).is_equal("telemetry_focus")


# ── process_observation — long hesitation → gentle nudge ──────────────────────

func test_long_hesitation_triggers_gentle_nudge() -> void:
	var apex := _make_apex()
	apex.process_observation("user_f", {"entropy": 0.5, "potential": 0.5})
	var response: Dictionary = apex.process_observation("user_f", {
		"entropy": 0.5, "potential": 0.5,
		"trajectory": "stable", "hesitation_ms": 6000.0
	})
	assert_str(str(response.get("action", ""))).is_equal("narrative_prompt")
	assert_str(str(response.get("params", {}).get("type", ""))).is_equal("gentle_nudge")


# ── response history is stored and bounded ─────────────────────────────────────

func test_response_history_accumulates() -> void:
	var apex := _make_apex()
	for i in range(5):
		apex.process_observation("user_g", {"entropy": 0.5, "potential": 0.5})
	var history: Array = apex.get_response_history("user_g")
	assert_int(history.size()).is_equal(5)


func test_response_history_bounded_at_100() -> void:
	var apex := _make_apex()
	for i in range(105):
		apex.process_observation("user_h", {"entropy": 0.5, "potential": 0.5})
	var history: Array = apex.get_response_history("user_h")
	assert_int(history.size()).is_less_equal(100)


func test_response_history_empty_for_unknown_user() -> void:
	var apex := _make_apex()
	var history: Array = apex.get_response_history("nobody")
	assert_int(history.size()).is_equal(0)


# ── delegation queue — priority ordering ──────────────────────────────────────

func test_delegate_adds_to_queue() -> void:
	var apex := _make_apex()
	apex.delegate("HOPE", "store_observation")
	var q: Array = apex.get_pending_delegations()
	assert_int(q.size()).is_equal(1)
	assert_str(str(q[0].get("target", ""))).is_equal("HOPE")


func test_delegate_higher_priority_inserted_before_lower() -> void:
	var apex := _make_apex()
	# LOW (3) first, then CRITICAL (0)
	apex.delegate("HOPE", "low_task", 3)
	apex.delegate("DREAM", "critical_task", 0)
	var q: Array = apex.get_pending_delegations()
	assert_int(q.size()).is_equal(2)
	# CRITICAL should be at front
	assert_str(str(q[0].get("target", ""))).is_equal("DREAM")
	assert_str(str(q[1].get("target", ""))).is_equal("HOPE")


func test_delegate_same_priority_fifo_order() -> void:
	var apex := _make_apex()
	apex.delegate("HOPE", "task_1", 2)
	apex.delegate("DREAM", "task_2", 2)
	var q: Array = apex.get_pending_delegations()
	assert_str(str(q[0].get("target", ""))).is_equal("HOPE")
	assert_str(str(q[1].get("target", ""))).is_equal("DREAM")


# ── matrix summary ─────────────────────────────────────────────────────────────

func test_get_matrix_summary_returns_expected_keys() -> void:
	var apex := _make_apex()
	var summary: Dictionary = apex.get_matrix_summary()
	assert_bool(summary.has("system_load")).is_true()
	assert_bool(summary.has("pending_delegations")).is_true()
	assert_bool(summary.has("active_delegations")).is_true()
	assert_bool(summary.has("users_with_history")).is_true()
	assert_bool(summary.has("total_responses_logged")).is_true()


func test_matrix_summary_counts_match_state() -> void:
	var apex := _make_apex()
	apex.process_observation("user_i", {"entropy": 0.5, "potential": 0.5})
	apex.delegate("HOPE", "task", 2)
	var summary: Dictionary = apex.get_matrix_summary()
	assert_int(int(summary.get("users_with_history", 0))).is_equal(1)
	assert_int(int(summary.get("pending_delegations", 0))).is_equal(1)
	assert_int(int(summary.get("total_responses_logged", 0))).is_equal(1)


# ── get_pending_delegations is a copy (no mutation) ───────────────────────────

func test_get_pending_delegations_returns_copy() -> void:
	var apex := _make_apex()
	apex.delegate("HOPE", "task")
	var q: Array = apex.get_pending_delegations()
	q.clear()
	# Internal queue must still have the item
	assert_int(apex.get_pending_delegations().size()).is_equal(1)
