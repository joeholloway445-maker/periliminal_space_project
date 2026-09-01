export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  return res.status(200).json({
    ok: true,
    service: "periliminal-bridge",
    routes: [
      "/api/casino/ticket",
      "/api/casino/settle",
      "/api/hope",
      "/api/vote",
      "/api/secret",
      "/api/persist",
      "/api/nakama",
      "/api/supabase",
      "/api/health",
    ],
  });
}
