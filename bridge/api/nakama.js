export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : (req.body || {});
  return res.status(200).json({
    ok: true,
    presence: "stub",
    player_id: body.player_id || "",
    layer: body.layer || "",
    bots: { static: 0.6, reactive: 0.3, adaptive: 0.1 },
  });
}
