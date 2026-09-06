// (P217 §1) YONETICI hesabiyla toplu borclandirma — asil olcum.
import { chromium } from "playwright";
const KOK = "http://app.localhost:3197";
const t = await chromium.launch();
for (const [etiket, kimlik] of [
  ["ADMIN", { email: "admin@acme.com", password: "Admin123!" }],
  ["YONETICI", { email: "yonetici@acme.com", password: "Yonetici123!" }],
]) {
  const ctx = await t.newContext({ locale: "tr" });
  const g = await ctx.request.post(`${KOK}/api/auth/login`,
    { data: { tenant_slug: "acme-plaza", ...kimlik } });
  console.log(`\n=== ${etiket} login: ${g.status()} ===`);
  if (!g.ok()) { console.log("  ", (await g.text()).slice(0, 150)); await ctx.close(); continue; }
  const s = await ctx.newPage();
  await s.goto(`${KOK}/dashboard`, { waitUntil: "networkidle" });
  const r = await s.evaluate(async () => {
    const tr = await fetch("/api/tanimlar/gelir-gider-tanimlari?limit=50");
    const tanimlar = tr.ok ? await tr.json() : {};
    const gider = (tanimlar.items ?? []).find((x) => x.tip === "gider");
    if (!gider) return { tanimDurum: tr.status };
    const govde = { donem: "2026-11", gelir_gider_tanim_id: gider.id,
      tutar_kurus: 9999, kalem_tipi: "aidat", aciklama: "P217 rol olcumu" };
    const cagir = async (yol) => {
      const y = await fetch(yol, { method: "POST",
        headers: { "Content-Type": "application/json" }, body: JSON.stringify(govde) });
      return { durum: y.status, govde: (await y.text()).slice(0, 200) };
    };
    return {
      tanimDurum: tr.status,
      onizleme: await cagir("/api/panel/borclandirma-toplu-onizleme"),
      isleme: await cagir("/api/panel/borclandirma-toplu"),
    };
  });
  console.log(JSON.stringify(r, null, 1).slice(0, 600));
  await ctx.close();
}
await t.close();
