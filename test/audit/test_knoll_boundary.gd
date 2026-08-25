## test/audit/test_knoll_boundary.gd
## GdUnit4 unit tests for KnollBoundary (src/core/knoll_boundary.gd).
##
## KnollBoundary is a Node subclass with pure in-memory policy enforcement.
## .new() does not fire _ready(), so _layer_isolation starts empty — which is
## the safe default (all cross-layer flows denied until explicitly authorized).
##
## Run via GdUnit4 in the editor or with gdunit4 CLI.
extends GdUnitTestSuite


func _make_knoll() -> Node:
	return auto_free(load("res://src/core/knoll_boundary.gd").new())


# ---------------------------------------------------------------------------
# A. API surface
# ---------------------------------------------------------------------------

func test_has_method_validate_data_flow() -> void:
	var k := _make_knoll()
	assert_bool(k.has_method("validate_data_flow")).is_true()

func test_has_method_initiate_lockdown() -> void:
	var k := _make_knoll()
	assert_bool(k.has_method("initiate_lockdown")).is_true()

func test_has_method_release_lockdown() -> void:
	var k := _make_knoll()
	assert_bool(k.has_method("release_lockdown")).is_true()

func test_has_method_is_layer_locked() -> void:
	var k := _make_knoll()
	assert_bool(k.has_method("is_layer_locked")).is_true()

func test_has_method_validate_node_heartbeat() -> void:
	var k := _make_knoll()
	assert_bool(k.has_method("validate_node_heartbeat")).is_true()

func test_has_method_get_matrix_summary() -> void:
	var k := _make_knoll()
	assert_bool(k.has_method("get_matrix_summary")).is_true()

func test_has_method_authorize_cross_layer() -> void:
	var k := _make_knoll()
	assert_bool(k.has_method("authorize_cross_layer")).is_true()


# ---------------------------------------------------------------------------
# B. validate_data_flow — valid same-layer flows
# ---------------------------------------------------------------------------

func test_valid_pillar_no_layer_target_allowed() -> void:
	var k := _make_knoll()
	var result: bool = k.validate_data_flow({"payload": "hello"}, "HOPE")
	assert_bool(result).is_true()

func test_valid_pillar_same_layer_allowed() -> void:
	var k := _make_knoll()
	var data := {"source_layer": "subliminal", "target_layer": "subliminal"}
	assert_bool(k.validate_data_flow(data, "VISION")).is_true()

func test_all_valid_pillars_allowed() -> void:
	var k := _make_knoll()
	for pillar in ["HOPE", "DREAM", "VISION", "APEX", "KNOLL"]:
		assert_bool(k.validate_data_flow({}, pillar)).is_true()


# ---------------------------------------------------------------------------
# C. validate_data_flow — rejection cases
# ---------------------------------------------------------------------------

func test_invalid_target_layer_rejected() -> void:
	var k := _make_knoll()
	var data := {"target_layer": "shadow_realm"}
	assert_bool(k.validate_data_flow(data, "HOPE")).is_false()

func test_unknown_source_pillar_rejected() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_data_flow({}, "ROGUE")).is_false()

func test_empty_source_pillar_rejected() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_data_flow({}, "")).is_false()

func test_cross_layer_without_authorization_rejected() -> void:
	var k := _make_knoll()
	var data := {"source_layer": "subliminal", "target_layer": "supraliminal"}
	assert_bool(k.validate_data_flow(data, "HOPE")).is_false()

func test_locked_layer_rejects_flows() -> void:
	var k := _make_knoll()
	k.initiate_lockdown("liminal", "test lockdown")
	var data := {"target_layer": "liminal"}
	assert_bool(k.validate_data_flow(data, "HOPE")).is_false()


# ---------------------------------------------------------------------------
# D. authorize_cross_layer + cross-layer flow
# ---------------------------------------------------------------------------

func test_authorized_cross_layer_flow_allowed() -> void:
	var k := _make_knoll()
	k.authorize_cross_layer("DREAM", "subliminal", "supraliminal")
	var data := {"source_layer": "subliminal", "target_layer": "supraliminal"}
	assert_bool(k.validate_data_flow(data, "DREAM")).is_true()

func test_authorization_is_source_specific() -> void:
	var k := _make_knoll()
	k.authorize_cross_layer("DREAM", "subliminal", "supraliminal")
	# VISION was not authorized for the same cross-layer route
	var data := {"source_layer": "subliminal", "target_layer": "supraliminal"}
	assert_bool(k.validate_data_flow(data, "VISION")).is_false()


# ---------------------------------------------------------------------------
# E. initiate_lockdown / release_lockdown / is_layer_locked
# ---------------------------------------------------------------------------

func test_layer_not_locked_by_default() -> void:
	var k := _make_knoll()
	assert_bool(k.is_layer_locked("liminal")).is_false()

func test_initiate_lockdown_locks_layer() -> void:
	var k := _make_knoll()
	k.initiate_lockdown("periliminal", "test")
	assert_bool(k.is_layer_locked("periliminal")).is_true()

func test_release_lockdown_returns_true_and_unlocks() -> void:
	var k := _make_knoll()
	k.initiate_lockdown("extraliminal", "test")
	var released: bool = k.release_lockdown("extraliminal")
	assert_bool(released).is_true()
	assert_bool(k.is_layer_locked("extraliminal")).is_false()

func test_release_unlocked_layer_returns_false() -> void:
	var k := _make_knoll()
	assert_bool(k.release_lockdown("hyperliminal")).is_false()

func test_invalid_layer_lockdown_silently_ignored() -> void:
	var k := _make_knoll()
	k.initiate_lockdown("void_realm", "test")  # should not crash or lock anything
	assert_bool(k.is_layer_locked("void_realm")).is_false()

func test_multiple_layers_can_be_locked_independently() -> void:
	var k := _make_knoll()
	k.initiate_lockdown("subliminal", "a")
	k.initiate_lockdown("liminal", "b")
	assert_bool(k.is_layer_locked("subliminal")).is_true()
	assert_bool(k.is_layer_locked("liminal")).is_true()
	assert_bool(k.is_layer_locked("supraliminal")).is_false()


# ---------------------------------------------------------------------------
# F. validate_node_heartbeat
# ---------------------------------------------------------------------------

func test_valid_pillar_sys_load_in_range_passes() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_node_heartbeat("node-001", "HOPE", 0.5)).is_true()

func test_sys_load_zero_is_valid() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_node_heartbeat("node-001", "DREAM", 0.0)).is_true()

func test_sys_load_one_is_valid() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_node_heartbeat("node-001", "APEX", 1.0)).is_true()

func test_sys_load_above_one_fails() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_node_heartbeat("node-001", "VISION", 1.1)).is_false()

func test_sys_load_negative_fails() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_node_heartbeat("node-001", "KNOLL", -0.1)).is_false()

func test_invalid_pillar_heartbeat_fails() -> void:
	var k := _make_knoll()
	assert_bool(k.validate_node_heartbeat("node-001", "SHADOW", 0.5)).is_false()


# ---------------------------------------------------------------------------
# G. get_matrix_summary
# ---------------------------------------------------------------------------

func test_summary_shape_has_required_keys() -> void:
	var k := _make_knoll()
	var summary: Dictionary = k.get_matrix_summary()
	assert_bool(summary.has("active_lockdowns")).is_true()
	assert_bool(summary.has("locked_layers")).is_true()
	assert_bool(summary.has("blocked_flows")).is_true()
	assert_bool(summary.has("allowed_flows")).is_true()
	assert_bool(summary.has("status")).is_true()
	assert_bool(summary.has("layers_monitored")).is_true()

func test_summary_status_nominal_when_no_lockdowns() -> void:
	var k := _make_knoll()
	assert_str(k.get_matrix_summary()["status"]).is_equal("NOMINAL")

func test_summary_status_locked_when_lockdown_active() -> void:
	var k := _make_knoll()
	k.initiate_lockdown("liminal", "test")
	assert_str(k.get_matrix_summary()["status"]).is_equal("LOCKED")

func test_summary_active_lockdowns_count() -> void:
	var k := _make_knoll()
	k.initiate_lockdown("subliminal", "a")
	k.initiate_lockdown("periliminal", "b")
	assert_int(k.get_matrix_summary()["active_lockdowns"]).is_equal(2)

func test_summary_layers_monitored_is_6() -> void:
	var k := _make_knoll()
	assert_int(k.get_matrix_summary()["layers_monitored"]).is_equal(6)

func test_summary_allowed_flows_increments() -> void:
	var k := _make_knoll()
	k.validate_data_flow({}, "HOPE")
	k.validate_data_flow({}, "DREAM")
	assert_int(k.get_matrix_summary()["allowed_flows"]).is_equal(2)

func test_summary_blocked_flows_increments() -> void:
	var k := _make_knoll()
	k.validate_data_flow({"target_layer": "void"}, "HOPE")   # invalid layer
	k.validate_data_flow({}, "INTRUDER")                       # invalid pillar
	assert_int(k.get_matrix_summary()["blocked_flows"]).is_equal(2)
