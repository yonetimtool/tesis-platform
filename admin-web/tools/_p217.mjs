import { chromium } from "playwright";
const KOK = "http://app.localhost:3197";
const t = await chromium.launch();
const ctx = await t.newContext({ viewport: { width: 1400, height: 950 }, locale: "tr" });
const a = await ctx.request.post(`${KOK}/api/auth/login`, {
  data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" } });
console.log("admin login:", a.status());
const s = await ctx.newPage();
await s.goto(`${KOK}/dashboard`, { waitUntil: "networkidle" });
const sonuc = await s.evaluate(async () => {
  const tr = await fetch("/api/tanimlar/gelir-gider-tanimlari?limit=50");
  const tanimlar = tr.ok ? await tr.json() : { hata: tr.status };
  const gider = (tanimlar.items ?? []).find((x) => x.tip === "gider");
  if (!gider) return { tanimDurum: tr.status, tanimGovde: JSON.stringify(tanimlar).slice(0, 200) };
  const govde = { donem: "2026-10", gelir_gider_tanim_id: gider.id,
    tutar_kurus: 12345, kalem_tipi: "aidat", aciklama: "P217 surus" };
  const o = await fetch("/api/panel/borclandirma-toplu-onizleme",
    { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(govde) });
  const od = await o.json().catch(() => null);
  const i = await fetch("/api/panel/borclandirma-toplu",
    { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(govde) });
  const idd = await i.json().catch(() => null);
  return { tanim: gider.ad, onizleme: { durum: o.status, islenecek: od?.islenecek, atlanacak: od?.atlanacak },
           isleme: { durum: i.status, govde: JSON.stringify(idd).slice(0, 200) } };
});
console.log(JSON.stringify(sonuc, null, 1));
await t.close();
