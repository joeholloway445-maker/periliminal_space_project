export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : (req.body || {});
  const wager = Number(body.wager || 0);
  const game = String(body.game || "slots");
  const player_id = String(body.player_id || "anon");
  if (wager <= 0) return res.status(400).json({ error: "wager required" });
  const ticket_id = "t_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 8);
  const ticket = {
    ticket_id,
    player_id,
    game,
    wager,
    layer: body.layer || "hyperliminal",
    issued_at: Date.now(),
    play_url: "/casino?ticket=" + encodeURIComponent(player_id) + "&tid=" + encodeURIComponent(ticket_id),
  };
  return res.status(200).json(ticket);
}
