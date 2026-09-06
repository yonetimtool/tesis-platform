import { chromium } from "playwright";
const KOK = "http://app.localhost:3197";
const t = await chromium.launch();
const ctx = await t.newContext({ viewport: { width: 1500, height: 1000 }, locale: "tr" });
await ctx.request.post(`${KOK}/api/auth/login`, {
  data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" } });
const s = await ctx.newPage();
await s.goto(`${KOK}/dashboard`, { waitUntil: "networkidle" });
const d = await s.evaluate(async () => {
  const al = async (u) => { const r = await fetch(u); return { durum: r.status, govde: r.ok ? await r.json() : null }; };
  return {
    tahsilatGostergesi: await al("/api/panel/tahsilat-gostergesi"),
    yaslandirma: await al("/api/panel/yaslandirma"),
    finansOzet: await al("/api/panel/finans-ozet"),
  };
});
for (const [ad, v] of Object.entries(d)) {
  console.log(`--- ${ad}: ${v.durum} ---`);
  console.log("   " + JSON.stringify(v.govde).slice(0, 320));
}
await t.close();
