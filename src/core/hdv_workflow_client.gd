extends Node
## HDV Workflow Client — n8n-clone HTTP bridge for Periliminal.Space
##
## Connects the Godot game engine to hdv-orchestrator for:
##   - APEX MoE model routing decisions
##   - KNOLL-gated workflow triggers (VISION execution)
##   - DREAM dry-run simulation
##
## Uses Godot's built-in HTTPRequest node — no external dependencies.
## Configure WORKFLOW_API_URL and WORKFLOW_API_KEY in project settings or env.
##
## Autoloaded as "HDVWorkflow"

signal route_decision_received(model: String, category: String, reasoning: String)
signal workflow_triggered(job_id: String, moe_model: String)
signal simulation_completed(score: int, grade: String, trace: Array)
signal workflow_error(message: String)

# ─── Configuration ────────────────────────────────────────────────────────────
var api_url: String = ""
var api_key: String = ""

# ─── MoE Heuristic (local fallback — mirrors HDV-Foundation apex_router) ──────

enum BudgetTier { LOW, MEDIUM, HIGH }

const MODEL_HAIKU  := "claude-haiku-4-5-20251001"
const MODEL_SONNET := "claude-sonnet-5"
const MODEL_OPUS   := "claude-opus-5"
const MODEL_FABLE  := "claude-fable-5"

## Pure heuristic — no network required.
## Returns the optimal Claude model ID for a given intent/category/budget.
func heuristic_route(intent: String, category: String, budget: BudgetTier) -> String:
	var low  := budget == BudgetTier.LOW
	var high := budget == BudgetTier.HIGH

	match category:
		"security", "audit":
			return MODEL_OPUS if high else MODEL_SONNET
		"code", "analysis":
			if low:   return MODEL_HAIKU
			if high:  return MODEL_OPUS
			return MODEL_SONNET
		"creative", "simulation":
			return MODEL_FABLE if high else MODEL_SONNET
		"vision", "multimodal":
			return MODEL_SONNET
		"chat", "support":
			return MODEL_HAIKU if low else MODEL_SONNET
		_:
			var lower := intent.to_lower()
			if lower.contains("secur") or lower.contains("audit") or lower.contains("knoll"):
				return MODEL_OPUS
			if lower.contains("dream") or lower.contains("simulat") or lower.contains("creat"):
				return MODEL_FABLE
			if lower.contains("cod") or lower.contains("debug") or lower.contains("refactor"):
				return MODEL_SONNET
			return MODEL_HAIKU if low else MODEL_SONNET

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Load from ProjectSettings (set in Project → Settings → HDV)
	api_url = ProjectSettings.get_setting("hdv/workflow_api_url", "")
	api_key  = ProjectSettings.get_setting("hdv/workflow_api_key",  "")
	print_rich("[color=cyan]HDVWorkflow[/color]: Workflow client initialized. API: %s" % [
		"configured" if api_url != "" else "NOT configured — local heuristic only"
	])

# ─── Public API ────────────────────────────────────────────────────────────────

## Synchronous local MoE routing — no network call.
## Use when you need a model name immediately (e.g. before an API call).
func route(intent: String, category: String = "general", budget: BudgetTier = BudgetTier.MEDIUM) -> Dictionary:
	var model := heuristic_route(intent, category, budget)
	return {
		"model": model,
		"category": category,
		"budget_tier": BudgetTier.keys()[budget].to_lower(),
		"reasoning": "Heuristic: category=%s budget=%s → %s" % [category, BudgetTier.keys()[budget], model],
	}

## Trigger a workflow execution in hdv-orchestrator (VISION runtime).
## KNOLL validates payload server-side before DAG execution begins.
func trigger_workflow(workflow_id: String, intent: String, trigger_data: Dictionary = {},
		category: String = "general", budget: BudgetTier = BudgetTier.MEDIUM,
		user_id: String = "") -> void:
	if api_url == "" or api_key == "":
		emit_signal("workflow_error", "WORKFLOW_API_URL or WORKFLOW_API_KEY not configured")
		return

	var moe := heuristic_route(intent, category, budget)
	var body := JSON.stringify({
		"triggerData": _merge({
			"intent": intent,
			"moeModel": moe,
			"moeCategory": category,
			"moeBudgetTier": BudgetTier.keys()[budget].to_lower(),
		}, trigger_data)
	})

	var headers := _build_headers(user_id)
	_post("%s/workflows/%s/run" % [api_url.rstrip("/"), workflow_id], headers, body,
		func(data: Dictionary):
			emit_signal("workflow_triggered", data.get("jobId", ""), moe)
	)

## Simulate a workflow through DREAM — dry run with no side effects.
func simulate_workflow(workflow: Dictionary, trigger_data: Dictionary = {}) -> void:
	if api_url == "" or api_key == "":
		emit_signal("workflow_error", "WORKFLOW_API_URL not configured")
		return

	var body := JSON.stringify({ "workflow": workflow, "triggerData": trigger_data })
	var headers := _build_headers("")
	_post("%s/simulate" % api_url.rstrip("/"), headers, body,
		func(data: Dictionary):
			emit_signal("simulation_completed",
				data.get("score", 0),
				data.get("grade", "?"),
				data.get("trace", [])
			)
	)

# ─── Internal helpers ──────────────────────────────────────────────────────────

func _build_headers(user_id: String) -> PackedStringArray:
	var h := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])
	if user_id != "":
		h.append("x-hdv-user-id: %s" % user_id)
	return h

func _post(url: String, headers: PackedStringArray, body: String,
		on_success: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, resp: PackedByteArray):
			http.queue_free()
			if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
				emit_signal("workflow_error",
					"HTTP %d — %s" % [code, resp.get_string_from_utf8()])
				return
			var parsed: Variant = JSON.parse_string(resp.get_string_from_utf8())
			if parsed is Dictionary:
				on_success.call(parsed)
			else:
				emit_signal("workflow_error", "Invalid JSON response")
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	for k: String in b:
		out[k] = b[k]
	return out
