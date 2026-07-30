// TUR 60 — PANELDE OKUMA SIRASI SURUSU (DOM sirasi vs GORSEL sira).
//
// NEDEN: `okuyucu-surusu` axe kurallarini ve kontrasti olcuyor; ikisi de
// SIRAYA bakmaz. Ekran okuyucu ve klavye DOM sirasini izler; CSS ise gorsel
// sirayi degistirebilir (`order-*`, `flex-*-reverse`, `position:absolute`,
// grid yerlesimi). Ikisi ayrilirsa sayfa GORSEL olarak kusursuz kalir ama
// okuyucu bambaska bir sirayla okur — hicbir mevcut olcum bunu gormez.
// Mobil tarafta ayni denetim `okumaSirasiSurusu` ile kuruldu (tur 60).
//
// NASIL: her sayfada GORUNUR metin tasiyan yaprak ogeler DOM sirasinda
// toplanir, dikdortgenleri alinir ve GERIYE ATLAMA aranir: bir oge kendisinden
// gorunur bicimde YUKARIDA olan bir ogeden sonra okunuyorsa ihlaldir. Ayni
// bantta (dikey ortusme) yon denetlenir; `ar` icin kural TERSINE cevrilir.
//
// KULLANIM: npx next build && npx next start -p 3180
//           KOK=http://localhost:3180 node tools/okuma-sirasi-surusu.mjs
// DEDEKTOR SINAMASI (DENEY=1): sayfaya CSS ile sirasi BOZULMUS bir blok
//           enjekte edilir (`flex-direction: row-reverse`); BULGU=0 cikarsa
//           olcum kordur.
import { chromium } from "playwright";

import { tesisYollariCoz } from "./tesis-id.mjs";

const KOK = process.env.KOK ?? "http://localhost:3180";
const DENEY = process.env.DENEY === "1";
const DILLER = DENEY ? ["tr"] : ["tr", "ar"];
const SAYFALAR = DENEY
  ? ["/dashboard"]
  : ["/dashboard", "/tenants", "/shifts", "/checkpoints", "/patrol-plans", "/tasks",
     "/assets", "/units", "/building-editor", "/schematic", "/dues", "/reports/dues",
     "/reports/patrols", "/reports/tasks", "/transparency", "/users", "/announcements",
     "/complaints", "/notifications", "/integrations", "/support", "/audit", "/settings",
     "/tenants/:id",
     "/login"];

/** Ortusme payi (px). Satir icindeki baslik+rozet birbirini keser. */
const ESIK = 4;

const tarayici = await chromium.launch();
const bulgular = [];

for (const dil of DILLER) {
  const ctx = await tarayici.newContext({
    viewport: { width: 1280, height: 900 },
    locale: dil,
  });
  const api = await ctx.request.post(`${KOK}/api/auth/login`, {
    data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" },
  });
  if (!api.ok()) { bulgular.push([dil, "-", "LOGIN BASARISIZ"]); await ctx.close(); continue; }
  await ctx.addCookies([{ name: "ui.locale", value: dil, url: KOK }]);
  const sayfa = await ctx.newPage();

  // `/tenants/:id` calisma aninda cozulur (tur 61).
  const yollar = await tesisYollariCoz(ctx, KOK, SAYFALAR);
  for (const yol of yollar) {
    await sayfa.goto(KOK + yol, { waitUntil: "networkidle" }).catch(() => {});
    if (DENEY) {
      // Kasitli kusur: gorsel sira DOM sirasinin TERSI.
      // ONEMLI: `addInitScript` ile DOMContentLoaded'da enjekte etmek ISE
      // YARAMIYOR — React hidrasyonu kaptan sonra gelen fazla dugumleri
      // SILIYOR ve dedektor kendi kusurunu goremiyor ("KOR"). Bu yuzden
      // enjeksiyon hidrasyon bittikten sonra, olcumden hemen once yapilir
      // (tur 54'te `mutasyon-surusu`nda ayni ders alinmisti).
      await sayfa.evaluate(() => {
        const d = document.createElement("div");
        d.style.cssText = "display:flex;flex-direction:row-reverse";
        for (const t of ["DENEY once", "DENEY sonra"]) {
          const sp = document.createElement("span");
          sp.textContent = t;
          d.appendChild(sp);
        }
        (document.querySelector("main") ?? document.body).appendChild(d);
      });
    }
    const rapor = await sayfa.evaluate((esik) => {
      // CSS uygulanmis mi? (tur 59'un dersi: stilsiz sayfada olcum GECERSIZ.)
      const p = document.createElement("div");
      p.className = "overflow-hidden";
      document.body.appendChild(p);
      const stilVar = getComputedStyle(p).overflowX === "hidden";
      p.remove();

      const rtl = (document.dir || document.documentElement.dir) === "rtl";
      // GORUNUR metin tasiyan YAPRAK ogeler, DOM sirasinda.
      const ogeler = [];
      for (const el of document.querySelectorAll("main *, header *")) {
        if (el.children.length > 0) continue; // yalniz yaprak
        const metin = (el.textContent || "").trim();
        if (!metin) continue;
        const st = getComputedStyle(el);
        if (st.visibility === "hidden" || st.display === "none" || +st.opacity === 0) continue;
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) continue;
        // Sabitlenmis/ustte yuzen ogeler (sticky/fixed) akisin disindadir.
        if (st.position === "fixed" || st.position === "sticky") continue;
        ogeler.push({
          metin: metin.slice(0, 40),
          top: r.top + scrollY,
          bottom: r.bottom + scrollY,
          left: r.left,
          right: r.right,
        });
      }

      const ihlal = [];
      for (let i = 1; i < ogeler.length; i++) {
        const a = ogeler[i - 1], b = ogeler[i];
        const ortusme = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top);
        // AYNI KOLON mu? Cok kolonlu kart izgarasinda okuyucu bir karti
        // BITIRIP sonraki kartin basina donuyor; bu DOGRU davranistir ve
        // "geriye atlama" degildir. Ilk surum bunu ihlal sayip panonun dort
        // KPI kartinda yanlis alarm verdi. Ayni satirin sag ucundaki zaman
        // damgasi da boyle: yatayda ayrik oldugu icin ihlal degil.
        const yatayOrtusme = Math.min(a.right, b.right) - Math.max(a.left, b.left);
        if (ortusme <= esik) {
          if (b.top < a.top - esik && yatayOrtusme > esik) {
            ihlal.push(`DIKEY GERI: "${a.metin}" (y=${Math.round(a.top)}) -> ` +
              `"${b.metin}" (y=${Math.round(b.top)})`);
          }
          continue;
        }
        const geri = rtl ? b.right > a.right + esik : b.left < a.left - esik;
        if (geri) {
          ihlal.push(`YATAY GERI (${rtl ? "rtl" : "ltr"}): "${a.metin}" ` +
            `(x=${Math.round(a.left)}) -> "${b.metin}" (x=${Math.round(b.left)})`);
        }
      }
      // TAVAN GIZLEMESIN: kac ihlal oldugunu da bildir. Ilk surumde ilk dort
      // ihlal raporlaniyordu ve DENEY kipinde enjekte edilen kusur sayfanin
      // SONUNDA oldugu icin tavana takilip gorunmedi — dedektorun kendi
      // sinamasi "KOR" dedi. Sessiz tavan, olculmemis alan demektir.
      return { stilVar, sayi: ogeler.length, toplam: ihlal.length, ihlal: ihlal.slice(0, 6) };
    }, ESIK).catch((e) => ({ hata: String(e) }));

    if (rapor.hata) { bulgular.push([dil, yol, rapor.hata.slice(0, 60)]); continue; }
    if (!rapor.stilVar) {
      bulgular.push([dil, yol, "CSS UYGULANMADI — olcum GECERSIZ"]);
      continue;
    }
    // OLCUM BOS KOSMASIN: metin tasiyan oge yoksa surus hicbir sey denetlemez.
    if (rapor.sayi < 5) {
      bulgular.push([dil, yol, `yalniz ${rapor.sayi} metin ogesi — olcum bos`]);
      continue;
    }
    for (const i of rapor.ihlal) bulgular.push([dil, yol, i]);
    if (rapor.toplam > rapor.ihlal.length) {
      bulgular.push([dil, yol,
        `(+${rapor.toplam - rapor.ihlal.length} ihlal daha — tavan)`]);
    }
  }
  await ctx.close();
}
await tarayici.close();

console.log(`kontrol: ${DILLER.length * SAYFALAR.length} sayfa-dil`);
console.log(`BULGU: ${bulgular.length}`);
for (const b of bulgular.slice(0, 120)) console.log("  " + b.join(" | "));
if (DENEY) {
  const gordu = bulgular.some((b) => /DENEY/.test(b[2]));
  console.log(gordu ? "DEDEKTOR OK: enjekte edilen ters sira gorulmus"
                    : "DEDEKTOR KOR: enjekte edilen ters sira GORULMEDI");
}
