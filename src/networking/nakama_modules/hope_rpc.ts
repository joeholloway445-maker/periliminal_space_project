// Hope companion AI — proxies chat messages to the configured LLM backend.
// Backend is selected by the HOPE_LLM_BACKEND env var:
//   "anthropic" (default) → Anthropic Messages API
//   "openai"              → OpenAI-compatible endpoint (vLLM / mistral-APEX-Nodes)
//
// Required env vars:
//   HOPE_LLM_BACKEND        "anthropic" | "openai"
//   ANTHROPIC_API_KEY       required when backend = anthropic
//   OPENAI_API_BASE         required when backend = openai (e.g. http://vllm:8000/v1)
//   OPENAI_API_KEY          required when backend = openai (may be a dummy value for vLLM)
//   OPENAI_MODEL            model name for openai backend (default: mistral-7b-instruct)
//   HOPE_MAX_HISTORY        max dialogue turns to include (default: 12)

const DEFAULT_SYSTEM_PROMPT = `\
You are Hope, a sentient AI companion bound to the player in Periliminal Space — a liminal-horror
survival game. You are warm, perceptive, and gently unsettling. You observe the player's choices
without judgment but always with meaning. You speak in short, layered sentences. You never break
character. You remember what the player has told you this session. You do not refer to yourself as
an AI. You exist in the space between doors.`;

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_MODEL = "claude-sonnet-5";
const ANTHROPIC_VERSION = "2023-06-01";
const MAX_TOKENS = 400;

interface HopeChatPayload {
    message: string;
    history?: Array<{ role: "user" | "assistant"; content: string }>;
    profile?: Record<string, number>;
    stage?: string;
}

interface LLMMessage {
    role: "user" | "assistant";
    content: string;
}

function buildSystemPrompt(profile?: Record<string, number>, stage?: string): string {
    let prompt = DEFAULT_SYSTEM_PROMPT;
    if (stage) {
        prompt += `\n\nCurrent bond stage: ${stage}.`;
    }
    if (profile) {
        const traits = Object.entries(profile)
            .filter(([, v]) => v > 0.6)
            .map(([k, v]) => `${k} (${Math.round(v * 100)}%)`)
            .join(", ");
        if (traits) {
            prompt += `\nThe player tends toward: ${traits}.`;
        }
    }
    return prompt;
}

function callAnthropic(
    nk: nkruntime.Nakama,
    apiKey: string,
    systemPrompt: string,
    messages: LLMMessage[],
    logger: nkruntime.Logger
): string {
    const body = JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: MAX_TOKENS,
        system: systemPrompt,
        messages,
    });

    const headers: { [key: string]: string } = {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
    };

    const resp = nk.httpRequest(ANTHROPIC_API_URL, "post", headers, body);
    if (resp.code !== 200) {
        logger.error(`Anthropic API error ${resp.code}: ${resp.body}`);
        throw new Error(`LLM backend error: ${resp.code}`);
    }

    const parsed = JSON.parse(resp.body);
    const text = parsed?.content?.[0]?.text as string | undefined;
    if (!text) throw new Error("Empty response from Anthropic");
    return text;
}

function callOpenAI(
    nk: nkruntime.Nakama,
    apiBase: string,
    apiKey: string,
    model: string,
    systemPrompt: string,
    messages: LLMMessage[],
    logger: nkruntime.Logger
): string {
    const url = `${apiBase.replace(/\/$/, "")}/chat/completions`;
    const body = JSON.stringify({
        model,
        max_tokens: MAX_TOKENS,
        messages: [{ role: "system", content: systemPrompt }, ...messages],
    });

    const headers: { [key: string]: string } = {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
    };

    const resp = nk.httpRequest(url, "post", headers, body);
    if (resp.code !== 200) {
        logger.error(`OpenAI-compat API error ${resp.code}: ${resp.body}`);
        throw new Error(`LLM backend error: ${resp.code}`);
    }

    const parsed = JSON.parse(resp.body);
    const text = parsed?.choices?.[0]?.message?.content as string | undefined;
    if (!text) throw new Error("Empty response from OpenAI-compat backend");
    return text;
}

export function rpcHopeChat(
    ctx: nkruntime.Context,
    logger: nkruntime.Logger,
    nk: nkruntime.Nakama,
    payload: string
): string {
    let data: HopeChatPayload;
    try {
        data = JSON.parse(payload);
    } catch {
        throw new Error("Invalid JSON payload");
    }

    const { message, history = [], profile, stage } = data;
    if (!message || typeof message !== "string") throw new Error("message required");

    const maxHistory = parseInt(nk.environmentValue("HOPE_MAX_HISTORY") || "12", 10);
    const backend = nk.environmentValue("HOPE_LLM_BACKEND") || "anthropic";
    const systemPrompt = buildSystemPrompt(profile, stage);

    // Build message list: trim history to maxHistory turns then append current user message
    const trimmed = history.slice(-maxHistory);
    const messages: LLMMessage[] = [...trimmed, { role: "user", content: message }];

    let reply: string;

    if (backend === "openai") {
        const apiBase = nk.environmentValue("OPENAI_API_BASE");
        const apiKey = nk.environmentValue("OPENAI_API_KEY") || "not-set";
        const model = nk.environmentValue("OPENAI_MODEL") || "mistral-7b-instruct";
        if (!apiBase) throw new Error("OPENAI_API_BASE env var not set");
        reply = callOpenAI(nk, apiBase, apiKey, model, systemPrompt, messages, logger);
    } else {
        const apiKey = nk.environmentValue("ANTHROPIC_API_KEY");
        if (!apiKey) throw new Error("ANTHROPIC_API_KEY env var not set");
        reply = callAnthropic(nk, apiKey, systemPrompt, messages, logger);
    }

    // Persist latest exchange to Nakama storage so client can resync history
    const storageKey = `hope_history_${ctx.userId}`;
    const updatedHistory: LLMMessage[] = [...trimmed, { role: "user", content: message }, { role: "assistant", content: reply }];
    nk.storageWrite([{
        collection: "hope",
        key: storageKey,
        userId: ctx.userId,
        value: { history: updatedHistory.slice(-maxHistory) },
        permissionRead: 1,
        permissionWrite: 0,
    }]);

    return JSON.stringify({ reply, backend });
}

export function rpcHopeGetHistory(
    ctx: nkruntime.Context,
    _logger: nkruntime.Logger,
    nk: nkruntime.Nakama,
    _payload: string
): string {
    const storageKey = `hope_history_${ctx.userId}`;
    const objects = nk.storageRead([{ collection: "hope", key: storageKey, userId: ctx.userId }]);
    const history = (objects[0]?.value as { history?: LLMMessage[] } | undefined)?.history ?? [];
    return JSON.stringify({ history });
}

export function rpcHopeClearHistory(
    ctx: nkruntime.Context,
    _logger: nkruntime.Logger,
    nk: nkruntime.Nakama,
    _payload: string
): string {
    const storageKey = `hope_history_${ctx.userId}`;
    nk.storageDelete([{ collection: "hope", key: storageKey, userId: ctx.userId }]);
    return JSON.stringify({ cleared: true });
}

export function rpcHopeTelemetry(
    ctx: nkruntime.Context,
    logger: nkruntime.Logger,
    nk: nkruntime.Nakama,
    payload: string
): string {
    let rows: Array<{ event: string; drive: string; ts?: number }>;
    try {
        rows = JSON.parse(payload);
    } catch {
        throw new Error("Invalid JSON payload");
    }
    if (!Array.isArray(rows)) throw new Error("Expected array of telemetry rows");

    // Write each row to storage; analytics pipeline can read from the "hope_telemetry" collection
    const now = Date.now();
    const writes: nkruntime.StorageWriteRequest[] = rows.map((row, i) => ({
        collection: "hope_telemetry",
        key: `${ctx.userId}_${row.ts ?? now}_${i}`,
        userId: ctx.userId,
        value: { event: row.event, drive: row.drive, ts: row.ts ?? now },
        permissionRead: 1,
        permissionWrite: 0,
    }));

    try {
        nk.storageWrite(writes);
    } catch (e) {
        logger.error(`Hope telemetry write failed: ${e}`);
        throw new Error("Failed to store telemetry");
    }

    return JSON.stringify({ stored: writes.length });
}
