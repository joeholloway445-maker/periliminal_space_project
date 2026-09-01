export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : (req.body || {});
  const wager = Number(body.wager || 0);
  const won = Boolean(body.won);
  const payout = won ? Math.max(0, Math.floor(wager * Number(body.mult || 2))) : 0;
  return res.status(200).json({
    ticket_id: body.ticket_id || "",
    player_id: body.player_id || "",
    wager,
    payout,
    won,
  });
}
