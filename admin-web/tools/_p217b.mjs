import { chromium } from "playwright";
const KOK = "http://app.localhost:3197";
const t = await chromium.launch();
const ctx = await t.newContext({ viewport: { width: 1500, height: 1000 }, locale: "tr" });
await ctx.request.post(`${KOK}/api/auth/login`, {
  data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" } });
const s = await ctx.newPage();
s.on("console", (m) => { if (m.type() === "error") console.log("KONSOL HATA:", m.text().slice(0, 120)); });

await s.goto(`${KOK}/finans/borclandirmalar`, { waitUntil: "networkidle" });
await s.waitForTimeout(1500);
const govde = await s.evaluate(() => document.body.innerText.slice(0, 900));
console.log("--- SAYFA ---\n" + govde);

// Listedeki satir sayisi + istek
const istekler = [];
s.on("request", (r) => { if (r.url().includes("/api/")) istekler.push(r.url().replace(KOK, "")); });
await s.reload({ waitUntil: "networkidle" });
await s.waitForTimeout(1200);
console.log("\n--- ISTEKLER ---\n" + istekler.slice(0, 8).join("\n"));
await t.close();
