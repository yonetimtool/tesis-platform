// TUR 59 — PANELDE TURKCE SIZINTISI SURUSU.
//
// NEDEN: mobilde her surus `trSizintisiYok` ile Turkce sizintisi arar; panelde
// BOYLE BIR DENETIM HIC YOKTU. `okuyucu-surusu` 336 sayfa-dil-tema kosuyor
// ama yalniz erisilebilirlik/kontrast olcuyor; `dar-ekran-surusu` tasmaya
// bakiyor. Sonuc: panonun dort KPI aciklamasi (`{n} plan penceresi`,
// `{n} turdan`, `tur yok`, `ilgilenilmeli`) ALTI DILDE Turkce goruntulendi.
// Sozluk anahtarlari zaten vardi ve yedi dile cevrilmisti — sayfa onlari
// kullanmiyordu. Hicbir olcum bunu gormedi.
//
// NASIL: karakterden ("ğışç") degil SOZLUKTEN gider. Bir sayfa `de` dilinde
// boyanirken metninde TR sozlugunun bir DEGERI birebir geciyorsa ve o
// anahtarin Almanca cevirisi farkliysa → sizinti. Boylece "tur yok" gibi
// TR'ye ozgu harf tasimayan metinler de yakalanir.
//
// KULLANIM: npx next build && npx next start -p 3170
//           KOK=http://localhost:3170 node tools/tr-sizinti-surusu.mjs
// DEDEKTOR SINAMASI (DENEY=1): sayfaya TR sozlugunden bir deger enjekte
//           edilir; BULGU=0 cikarsa olcum kordur.
import { chromium } from "playwright";
import { readFileSync } from "node:fs";

const KOK = process.env.KOK ?? "http://localhost:3170";
const DENEY = process.env.DENEY === "1";
const DILLER = DENEY ? ["de"] : ["en", "ar", "ru", "de", "fr", "es"];
const SAYFALAR = DENEY
  ? ["/dashboard"]
  : ["/dashboard", "/tenants", "/shifts", "/checkpoints", "/patrol-plans", "/tasks",
     "/assets", "/units", "/building-editor", "/schematic", "/dues", "/reports/dues",
     "/reports/patrols", "/reports/tasks", "/transparency", "/users", "/announcements",
     "/complaints", "/notifications", "/integrations", "/support", "/audit", "/settings"];

/** `  anahtar: "deger",` satirlarini oku (sozlukler duz nesne). */
function sozlukOku(dil) {
  const ham = readFileSync(`lib/i18n/sozluk/${dil}.ts`, "utf8");
  const out = {};
  for (const m of ham.matchAll(/^ {2}([A-Za-z][A-Za-z0-9]*): "((?:[^"\\]|\\.)*)",$/gm)) {
    out[m[1]] = m[2].replace(/\\"/g, '"');
  }
  return out;
}

/** `{n} plan penceresi` → ` plan penceresi` (en uzun sabit parca). */
function sabitParca(deger) {
  return deger
    .split(/\{[^}]*\}/g)
    .map((p) => p.trim())
    .sort((a, b) => b.length - a.length)[0] ?? "";
}

/** VERI kaynakli yanlis alarmlar: bu anahtarlarin TR degeri, cevrilmeyen
 * VERIDE de geciyor. Ceviri hatasi degil, veri.
 *  - `tesisKurulum`/`tesisBekliyor`: backend yeni tesise "(Kurulum bekliyor)"
 *    yer tutucu ADI verir (`routers/tenants.py:_PLACEHOLDER_AD`).
 *  - `devriyeVardiya`: seed'deki vardiya ADLARI ("Gunduz Vardiyasi").
 *  - `gorevTipiTemizlik`: gorev KATEGORI adi (dinamik, tenant verisi).
 * Tur 54'te de ayni tuzak yasanmisti ("Vardiyasi" TR sizintisi sanilmisti). */
const VERI = new Set(["tesisKurulum", "tesisBekliyor", "devriyeVardiya", "gorevTipiTemizlik"]);

const tr = sozlukOku("tr");
const bulgular = [];
const tarayici = await chromium.launch();

for (const dil of DILLER) {
  const hedef = sozlukOku(dil);
  // Aranacak metinler: TR degeri hedef dilde FARKLI olan ve yeterince uzun
  // olanlar. Kisa/ortak degerler (marka, "ID", "CSV") rastgele eslesir.
  const aranacak = [];
  for (const [anahtar, trDeger] of Object.entries(tr)) {
    const hedefDeger = hedef[anahtar];
    if (!hedefDeger || hedefDeger === trDeger) continue;
    const parca = sabitParca(trDeger);
    if (parca.length < 6 || !/[A-Za-zÇĞİÖŞÜçğıöşü]{3}/.test(parca)) continue;
    // Hedef dilin cevirisi TR parcasini iceriyorsa ayirt edilemez.
    if (hedefDeger.includes(parca)) continue;
    if (VERI.has(anahtar)) continue;
    aranacak.push([anahtar, parca]);
  }

  const ctx = await tarayici.newContext({ viewport: { width: 1280, height: 900 }, locale: dil });
  const api = await ctx.request.post(`${KOK}/api/auth/login`, {
    data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" },
  });
  if (!api.ok()) { bulgular.push([dil, "-", "LOGIN BASARISIZ"]); await ctx.close(); continue; }
  await ctx.addCookies([{ name: "ui.locale", value: dil, url: KOK }]);
  const sayfa = await ctx.newPage();

  if (DENEY) {
    // Kasitli sizinti: TR sozlugunden gercek bir deger sayfaya basilir.
    await sayfa.addInitScript((metin) => {
      addEventListener("DOMContentLoaded", () => {
        const p = document.createElement("p");
        p.textContent = metin;
        document.body.appendChild(p);
      });
    }, tr.panelTurYok);
  }

  for (const yol of SAYFALAR) {
    await sayfa.goto(KOK + yol, { waitUntil: "networkidle" }).catch(() => {});
    const metin = await sayfa
      .evaluate(() => document.body.innerText.replace(/\s+/g, " "))
      .catch(() => "");
    if (!metin) { bulgular.push([dil, yol, "SAYFA OKUNAMADI"]); continue; }
    for (const [anahtar, parca] of aranacak) {
      if (metin.includes(parca)) bulgular.push([dil, yol, `${anahtar}: "${parca}"`]);
    }
  }
  await ctx.close();
}
await tarayici.close();

console.log(`kontrol: ${DILLER.length * SAYFALAR.length} sayfa-dil`);
console.log(`BULGU: ${bulgular.length}`);
for (const b of bulgular.slice(0, 120)) console.log("  " + b.join(" | "));
if (DENEY) {
  console.log(bulgular.length ? "DEDEKTOR OK: enjekte edilen TR metni gorulmus"
                              : "DEDEKTOR KOR: enjekte edilen TR metni GORULMEDI");
}
