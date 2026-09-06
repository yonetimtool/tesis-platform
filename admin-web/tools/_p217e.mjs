// (P217 §2) TAHAKKUK MODALI: kaydettikten sonra KAPANIYOR MU?
import { chromium } from "playwright";
const KOK = "http://app.localhost:3197";
const t = await chromium.launch();
const ctx = await t.newContext({ viewport: { width: 1500, height: 1000 }, locale: "tr" });
await ctx.request.post(`${KOK}/api/auth/login`, {
  data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" } });
const s = await ctx.newPage();
s.on("console", (m) => { if (m.type() === "error") console.log("KONSOL:", m.text().slice(0, 140)); });
await s.goto(`${KOK}/finans/borclandirmalar`, { waitUntil: "networkidle" });
await s.waitForTimeout(1200);
// Kurulum sihirbazi modali onu ortuyor — kapat.
for (let i = 0; i < 3; i++) {
  if (await s.getByRole("dialog").count()) { await s.keyboard.press("Escape"); await s.waitForTimeout(400); }
}
console.log("baslangicta acik dialog:", await s.getByRole("dialog").count());

await s.getByRole("button", { name: /^\+?\s*Yeni$/i }).first().click();
await s.waitForTimeout(600);
const acikMi = async () => (await s.getByRole("dialog").filter({ hasText: /tahakkuk|borçlandırma/i }).count()) > 0;
console.log("modal acildi mi:", await acikMi());

// Formu doldur: daire + tutar
const modal = s.getByRole("dialog").filter({ hasText: /tahakkuk|borçlandırma/i }).first();
const secimler = modal.locator("select");
const n = await secimler.count();
console.log("modaldaki secim sayisi:", n);
for (let i = 0; i < n; i++) {
  const secenekler = await secimler.nth(i).locator("option").count();
  if (secenekler > 1) await secimler.nth(i).selectOption({ index: 1 });
}
const tutar = modal.locator('input[inputmode="decimal"], input[type="text"]').first();
await tutar.fill("123,45");
await s.waitForTimeout(300);
await modal.getByRole("button", { name: /^kaydet$/i }).click();
await s.waitForTimeout(2500);

console.log("KAYDETTIKTEN SONRA modal acik mi:", await acikMi());
const govde = await s.evaluate(() => document.body.innerText);
console.log("ekranda 'eklendi/kaydedildi' var mi:", /eklendi|kaydedildi/i.test(govde));
const hata = await modal.locator('[role="alert"]').allTextContents().catch(() => []);
if (hata.length) console.log("modaldaki uyari:", hata.join(" | ").slice(0, 200));
await t.close();
