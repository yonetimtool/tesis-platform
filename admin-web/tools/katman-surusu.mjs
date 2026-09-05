// (P214) KATMAN SURUSU — modal GERCEKTEN haritanin ustunde mi?
//
// ===========================================================================
// NEDEN BIRIM TESTI YETMEZ
// ===========================================================================
// jsdom boyama yapmaz ve yiginlama sirasini HESAPLAMAZ; oradaki kilitler
// katman ILISKISINI olcer ("harita izole mi", "olcek tutarli mi").
// Kullanicinin sikayeti ise PIKSEL duzeyinde: "form alanlari gorunmuyor".
//
// Bu surus tam olarak onu olcer: modali acar ve her form alani icin
// `document.elementFromPoint(merkez)` sorar — o noktada EN USTTE hangi oge
// var? Yanit alanin kendisi (ya da onun bir atasi) degilse, alan baska bir
// sey tarafindan ORTULMUS demektir; ustteki ogenin ne oldugunu da yazar.
//
// DEDEKTOR SINAMASI (DENEY=1): olcumden hemen once harita kutusunun
// izolasyonu KALDIRILIR ve z-index'i Leaflet bandina cekilir. Surus bunu
// gormezse olcum KORDUR ve "gecti" demesinin degeri yoktur.
//
// KULLANIM: npx next build && npx next start -p 3196
//           KOK=http://localhost:3196 node tools/katman-surusu.mjs
import { chromium } from "playwright";

// KONAK ONEMLI: `localhost` PANEL yuzeyidir ve admin oradan `/tenants`e
// duser — `/checkpoints` hic acilmaz. Tesis yuzeyi `app.*`.
const KOK = process.env.KOK ?? "http://app.localhost:3196";
const DENEY = process.env.DENEY === "1";

const tarayici = await chromium.launch();
const ctx = await tarayici.newContext({
  viewport: { width: 1280, height: 900 },
  locale: "tr",
});
const giris = await ctx.request.post(`${KOK}/api/auth/login`, {
  data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" },
});
if (!giris.ok()) {
  console.error("LOGIN BASARISIZ — surus kosulamaz");
  await tarayici.close();
  process.exit(2);
}
await ctx.addCookies([{ name: "ui.locale", value: "tr", url: KOK }]);
const sayfa = await ctx.newPage();

// HARITA ANCAK GPS'LI NOKTA VARSA CIZILIR. Boyle bir nokta yoksa surus
// "harita yok" diye sessizce gecerdi — yani catismanin YASANDIGI durumu
// hic olcmeden "temiz" derdi. O yuzden nokta VARLIGI garanti edilir.
//
// ISTEK TARAYICI ICINDEN atilir (`page.evaluate` + `fetch`), `ctx.request`
// ile DEGIL: BFF kimligi httpOnly cerezden okuyor ve ilk denemede
// `ctx.request` 401 aldi. Tarayici baglaminda cerez kesin gider.
await sayfa.goto(`${KOK}/checkpoints`, { waitUntil: "networkidle" });

const gecici = await sayfa.evaluate(async () => {
  const r = await fetch("/api/checkpoints?limit=100&offset=0");
  const liste = r.ok ? (await r.json()).items ?? [] : [];
  if (liste.some((n) => n.gps_lat != null && n.gps_lng != null)) return null;
  const y = await fetch("/api/checkpoints", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      ad: `KATMAN-SURUS-${Date.now()}`,
      nfc_tag_uid: `04${Date.now().toString(16).toUpperCase().slice(-12)}`,
      gps_lat: 41.0082, gps_lng: 28.9784, aktif: true,
    }),
  });
  if (!y.ok) return { hata: y.status, govde: (await y.text()).slice(0, 200) };
  return { id: (await y.json()).id };
});
if (gecici?.hata) {
  console.error("GPS'li nokta acilamadi — olcum kurulamadi:", gecici.hata, gecici.govde);
  await tarayici.close();
  process.exit(2);
}

await sayfa.reload({ waitUntil: "networkidle" });

// Kurulum sihirbazi modali onu ortebilir — varsa kapat.
const sihirbaz = sayfa.getByRole("dialog").filter({ hasText: /Kurulum/i });
if (await sihirbaz.count()) {
  await sayfa.keyboard.press("Escape");
  await sayfa.waitForTimeout(300);
}

// Harita GERCEKTEN cizilmis olmali; yoksa olcum bosa duser.
await sayfa.waitForSelector(".leaflet-container", { timeout: 20000 });

if (DENEY) {
  // Kok nedeni GERI GETIR: izolasyonu kaldir, kutuyu Leaflet bandina cek.
  await sayfa.evaluate(() => {
    const kutu = document.querySelector(".leaflet-container")?.parentElement;
    if (kutu) {
      kutu.style.isolation = "auto";
      kutu.style.zIndex = "400";
      kutu.style.position = "relative";
    }
  });
}

// Modali ac.
await sayfa.getByRole("button", { name: /Yeni|Ekle/ }).first().click();
await sayfa.waitForSelector("[role=dialog]", { timeout: 10000 });
await sayfa.waitForTimeout(300); // acilis gecisi

const sonuc = await sayfa.evaluate(() => {
  const diyalog = document.querySelector("[role=dialog]");
  if (!diyalog) return { hata: "diyalog yok" };
  const alanlar = [...diyalog.querySelectorAll("input, select, textarea, button")];
  const ortulen = [];
  for (const a of alanlar) {
    const r = a.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) continue;      // gizli alan
    const x = r.left + r.width / 2;
    const y = r.top + r.height / 2;
    if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) continue;
    const ust = document.elementFromPoint(x, y);
    if (!ust || !(a.contains(ust) || ust.contains(a))) {
      ortulen.push({
        alan: a.getAttribute("name") || a.getAttribute("type") ||
              a.tagName.toLowerCase(),
        ustteki: ust ? `${ust.tagName.toLowerCase()}.${ust.className}`.slice(0, 60)
                     : "(yok)",
      });
    }
  }
  return { toplam: alanlar.length, ortulen };
});

console.log(`Modaldaki etkilesimli oge: ${sonuc.toplam}`);
if (sonuc.ortulen?.length) {
  console.log(`ORTULEN ${sonuc.ortulen.length} oge:`);
  for (const o of sonuc.ortulen) console.log(`  - ${o.alan}  <-  ${o.ustteki}`);
} else {
  console.log("ORTULEN OGE YOK — modal tamamen erisilebilir.");
}

if (gecici?.id) {
  await sayfa.evaluate((id) => fetch(`/api/checkpoints/${id}`, { method: "DELETE" }),
                       gecici.id);
}
await tarayici.close();

if (DENEY) {
  // Deneyde ORTULME BEKLENIR; gorulmediyse olcum kordur.
  if (!sonuc.ortulen?.length) {
    console.error("DEDEKTOR KOR: kok neden geri getirildi ama olcum gormedi.");
    process.exit(3);
  }
  console.log("DEDEKTOR CALISIYOR (deneyde ortulme gorundu).");
  process.exit(0);
}
process.exit(sonuc.ortulen?.length ? 1 : 0);
