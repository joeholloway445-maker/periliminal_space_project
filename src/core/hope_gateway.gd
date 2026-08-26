extends Node
## HOPE — Holistic Operational Persistence Engine
##
## The authentication and memory anchor of the fractal matrix. HOPE holds
## the player's identity, session tokens, and behavioral memory across
## the entire Periliminal.Space ecosystem. It is the threshold guardian
## that every other subsystem checks before accessing user-specific data.
##
## HOPE connects to the Supabase Auth backend for session validation
## and maintains a local cache of resolved user profiles to minimize
## round-trips during high-frequency game loops.
##
## Gateway Parallel: The Threshold Guardian — every soul that crosses into
## the fractal space must first be acknowledged and recognized by HOPE.
##
## Autoloaded as "HOPE"

signal user_authenticated(user_id: String, role: String)
signal user_session_expired(user_id: String)
signal auth_error(user_id: String, reason: String)
signal profile_updated(user_id: String, profile: Dictionary)

# ─── Configuration ────────────────────────────────────────────────────────────
const SESSION_TTL_SECONDS: float = 3600.0   # 1 hour session cache TTL
const MAX_CACHED_PROFILES: int = 512        # cap on in-memory profile cache

# ─── State ────────────────────────────────────────────────────────────────────
var _sessions: Dictionary = {}       # user_id → {token, expires_at, role, email}
var _profiles: Dictionary = {}       # user_id → Dictionary (behavioral + identity data)
var _auth_http: HTTPRequest = null   # reusable HTTP node for Supabase Auth requests

# ─── Supabase configuration ───────────────────────────────────────────────────
var _supabase_url: String = ""
var _supabase_anon_key: String = ""

func _ready() -> void:
	_supabase_url = ProjectSettings.get_setting("hdv/supabase_url", "")
	_supabase_anon_key = ProjectSettings.get_setting("hdv/supabase_anon_key", "")
	_auth_http = HTTPRequest.new()
	add_child(_auth_http)
	_auth_http.request_completed.connect(_on_auth_response)
	print_rich("[color=magenta]HOPE[/color]: Holistic Operational Persistence Engine initialized.")
	print_rich("  Supabase: %s | Session TTL: %.0fs" % [
		"configured" if _supabase_url != "" else "NOT configured — local session mode",
		SESSION_TTL_SECONDS,
	])

# ─── Public API ───────────────────────────────────────────────────────────────

## Validate a session token and cache the resolved user session.
## Emits user_authenticated on success, auth_error on failure.
func authenticate(token: String) -> void:
	if token.is_empty():
		auth_error.emit("", "empty token")
		return

	# Check cache first
	for uid in _sessions:
		var sess: Dictionary = _sessions[uid]
		if sess.get("token", "") == token:
			var expires: float = float(sess.get("expires_at", 0.0))
			if Time.get_unix_time_from_system() < expires:
				user_authenticated.emit(uid, str(sess.get("role", "user")))
				return
			else:
				_sessions.erase(uid)
				user_session_expired.emit(uid)
				break

	# No cache hit — validate with Supabase
	if _supabase_url.is_empty() or _supabase_anon_key.is_empty():
		# Dev mode: accept any non-empty token as synthetic user
		var synthetic_uid: String = "dev-" + token.left(8)
		_cache_session(synthetic_uid, token, "user", "dev@hdv.local")
		user_authenticated.emit(synthetic_uid, "user")
		return

	var headers: PackedStringArray = PackedStringArray([
		"Authorization: Bearer %s" % token,
		"apikey: %s" % _supabase_anon_key,
	])
	_auth_http.request("%s/auth/v1/user" % _supabase_url, headers, HTTPClient.METHOD_GET)

## Check whether a user_id has an active (non-expired) session in cache.
func is_authenticated(user_id: String) -> bool:
	if not _sessions.has(user_id):
		return false
	var expires: float = float(_sessions[user_id].get("expires_at", 0.0))
	return Time.get_unix_time_from_system() < expires

## Get the cached role for a user_id, or "anon" if not found.
func get_role(user_id: String) -> String:
	return str(_sessions.get(user_id, {}).get("role", "anon"))

## Get the cached token for a user_id (empty string if not found/expired).
func get_token(user_id: String) -> String:
	if not is_authenticated(user_id):
		return ""
	return str(_sessions[user_id].get("token", ""))

## Store behavioral or identity data for a user.
func record(user_id: String, key: String, value: Variant) -> void:
	if not _profiles.has(user_id):
		_profiles[user_id] = {}
	_profiles[user_id][key] = value
	profile_updated.emit(user_id, _profiles[user_id])

## Get the full profile dictionary for a user.
func get_profile(user_id: String) -> Dictionary:
	return _profiles.get(user_id, {})

## Invalidate a cached session (logout).
func invalidate(user_id: String) -> void:
	_sessions.erase(user_id)
	user_session_expired.emit(user_id)

## Get a summary of HOPE's current auth state.
func get_auth_summary() -> Dictionary:
	var now: float = Time.get_unix_time_from_system()
	var active: int = 0
	for uid in _sessions:
		if float(_sessions[uid].get("expires_at", 0.0)) > now:
			active += 1
	return {
		"active_sessions": active,
		"cached_profiles": _profiles.size(),
		"supabase_configured": not _supabase_url.is_empty(),
	}

# ─── Internals ────────────────────────────────────────────────────────────────

func _cache_session(user_id: String, token: String, role: String, email: String) -> void:
	# Evict oldest if at capacity
	if _sessions.size() >= MAX_CACHED_PROFILES:
		var oldest_uid: String = _sessions.keys()[0]
		_sessions.erase(oldest_uid)
	_sessions[user_id] = {
		"token": token,
		"role": role,
		"email": email,
		"expires_at": Time.get_unix_time_from_system() + SESSION_TTL_SECONDS,
	}

func _on_auth_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		auth_error.emit("", "Supabase auth HTTP %d" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		auth_error.emit("", "Invalid Supabase auth response")
		return
	var user: Dictionary = parsed as Dictionary
	var uid: String = str(user.get("id", ""))
	if uid.is_empty():
		auth_error.emit("", "No user id in Supabase response")
		return
	var role: String = str(
		user.get("app_metadata", {}).get("role",
			user.get("user_metadata", {}).get("role", "user"))
	)
	var email: String = str(user.get("email", ""))
	# Recover token from existing sessions if this uid is a re-validation
	var token: String = ""
	for uid_key in _sessions:
		if uid_key == uid:
			token = str(_sessions[uid_key].get("token", ""))
	_cache_session(uid, token, role, email)
	user_authenticated.emit(uid, role)
