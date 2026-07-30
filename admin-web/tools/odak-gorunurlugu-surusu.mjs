// TUR 64 — ODAK GORUNURLUGU SURUSU.
//
// Ucuncu envanterin E maddesi: odak SIRASI (tur 33) ve okuma sirasi (tur 60)
// olculdu; odak HALKASININ GORUNUR oldugu olculmedi. `globals.css` tum
// etkilesimli ogelere teal bir `outline` veriyor — ama bu iki sekilde
// gorunmez olabilir ve ikisi de axe'in bakmadigi seyler:
//
//   1. KONTRAST: halka rengi altindaki zeminle ayirt edilemiyorsa halka yok
//      demektir. WCAG 2.2 / 1.4.11 (non-text contrast) esigi 3:1. Ozellikle
//      TEAL zeminli bir dugmede TEAL halka: gorunmez.
//   2. KIRPILMA: `outline-offset` halkayi ogenin DISINA tasir; oge
//      `overflow:hidden` bir kapsayicinin kenarindaysa halka kirpilir.
//
// Ayrica halkanin HIC olmadigi durum (`outline: none` + yerine bir sey
// konmamis) dogrudan yakalanir.
//
// ODAK KLAVYEYLE VERILIR — bu bir ayrinti degil, olcumun GECERLILIK KOSULU.
// Ilk surumde `el.focus()` ile programatik odak veriyordum ve dedektorun kendi
// sinamasi "KOR" dedi: Chromium `:focus-visible`i programatik odakta (metin
// alanlari disinda) UYGULAMIYOR, yani `globals.css`teki halka hic devreye
// girmiyordu ve olculen sey UA'nin varsayilan cizgisiydi. Simdi `Tab` tusuyla
// gezinilir (tur 33'un klavye surusuyle ayni yol).
//
// KULLANIM: npx next build && npx next start -p 3195
//           KOK=http://localhost:3195 node tools/odak-gorunurlugu-surusu.mjs
// DEDEKTOR SINAMASI (DENEY=1): olcumden hemen once bir odaklanabilir ogenin
//           halkasi CSS ile kaldirilir ve bir digerinin rengi zeminine
//           esitlenir; ikisi de gorulmeli.
import { chromium } from "playwright";

import { tesisYollariCoz } from "./tesis-id.mjs";

const KOK = process.env.KOK ?? "http://localhost:3195";
const DENEY = process.env.DENEY === "1";
const TEMALAR = DENEY ? ["light"] : ["light", "dark"];
const SAYFALAR = DENEY
  ? ["/dashboard"]
  : ["/login", "/dashboard", "/tenants", "/shifts", "/checkpoints",
     "/patrol-plans", "/tasks", "/assets", "/units", "/building-editor",
     "/schematic", "/dues", "/reports/dues", "/reports/patrols",
     "/reports/tasks", "/transparency", "/users", "/announcements",
     "/complaints", "/notifications", "/integrations", "/support", "/audit",
     "/settings", "/tenants/:id"];

/** WCAG 1.4.11: metin olmayan ogelerde esik 3:1. */
const ESIK = 3;
/** Sayfa basina en fazla kac odaklanabilir oge yoklanir (surus suresi). */
const OGE_SINIRI = 40;

const tarayici = await chromium.launch();
const bulgular = [];

for (const tema of TEMALAR) {
  const ctx = await tarayici.newContext({
    viewport: { width: 1280, height: 900 },
    locale: "tr",
    colorScheme: tema,
    // Odak halkasi bir ERISILEBILIRLIK ogesidir; hareket azaltma acikken de
    // gorunmeli (ve animasyon olcumu bozmasin).
    reducedMotion: "reduce",
  });
  const api = await ctx.request.post(`${KOK}/api/auth/login`, {
    data: { tenant_slug: "acme-plaza", email: "admin@acme.com", password: "Admin123!" },
  });
  if (!api.ok()) { bulgular.push([tema, "-", "LOGIN BASARISIZ"]); await ctx.close(); continue; }
  await ctx.addCookies([{ name: "ui.locale", value: "tr", url: KOK }]);
  const sayfa = await ctx.newPage();
  await sayfa.addInitScript((t) => {
    try { localStorage.setItem("theme", t); } catch { /* yok say */ }
  }, tema);

  const yollar = await tesisYollariCoz(ctx, KOK, SAYFALAR);
  for (const yol of yollar) {
    await sayfa.goto(KOK + yol, { waitUntil: "networkidle" }).catch(() => {});

    if (DENEY) {
      // Kasitli iki kusur: (a) halkayi tamamen kaldir, (b) halka rengini
      // zeminine esitle. Hidrasyondan SONRA enjekte edilir (tur 60 dersi).
      await sayfa.evaluate(() => {
        // TUM belgede ILK IKI odaklanabilir oge — `Tab` sirasi sayfanin
        // basindan basladigi icin `main` icine enjekte etmek yetmiyordu
        // (kenar cubugu baglantilari once geliyor ve tavan doluyordu).
        const odaklanabilir = [...document.querySelectorAll(
          'a[href],button,input,select,textarea,[tabindex]:not([tabindex="-1"])',
        )].filter((el) => !el.hasAttribute("disabled"));
        if (odaklanabilir[0]) odaklanabilir[0].id = "deney-halkasiz";
        if (odaklanabilir[1]) odaklanabilir[1].id = "deney-ayni-renk";
        const st = document.createElement("style");
        st.textContent =
          "#deney-halkasiz:focus-visible{outline:none!important}" +
          "#deney-ayni-renk:focus-visible{outline:2px solid #ffffff!important;" +
          "background:#ffffff!important}";
        document.head.appendChild(st);
      });
    }

    // Odak gezinmesi KLAVYEYLE: her `Tab` sonrasi AKTIF oge olculur.
    await sayfa.evaluate(() => {
      // Gezinme sayfanin BASINDAN baslasin.
      document.body.setAttribute("tabindex", "-1");
      document.body.focus();
    });
    const ihlaller = [];
    let yoklanan = 0;
    let stilVar = true;
    const gorulen = new Set();
    for (let i = 0; i < OGE_SINIRI; i++) {
      await sayfa.keyboard.press("Tab");
      const olcum = await sayfa.evaluate((esik) => {
        const p = document.createElement("div");
        p.className = "overflow-hidden";
        document.body.appendChild(p);
        const stil = getComputedStyle(p).overflowX === "hidden";
        p.remove();

        const el = document.activeElement;
        if (!el || el === document.body || el === document.documentElement) {
          return { stil, bitti: true };
        }
        const cozRenk = (s) => {
          const m = s.match(/rgba?\(([^)]+)\)/);
          if (!m) return null;
          const [r, g, b, a = "1"] = m[1].split(",").map((x) => parseFloat(x));
          return { r, g, b, a };
        };
        const kanal = (v) => {
          const s = v / 255;
          return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
        };
        const parlaklik = (c) =>
          0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
        const kontrast = (a, b) => {
          const la = parlaklik(a), lb = parlaklik(b);
          return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
        };
        const zemin = (n0) => {
          let n = n0;
          while (n && n !== document.documentElement) {
            const c = cozRenk(getComputedStyle(n).backgroundColor);
            if (c && c.a > 0.5) return c;
            n = n.parentElement;
          }
          return { r: 255, g: 255, b: 255, a: 1 };
        };

        const st = getComputedStyle(el);
        const kalinlik = parseFloat(st.outlineWidth) || 0;
        const etiket = `${el.tagName.toLowerCase()}` +
          `${el.id ? "#" + el.id : ""}` +
          `.${(el.className || "").toString().slice(0, 24)}` +
          ` "${(el.textContent || "").trim().slice(0, 20)}"`;
        const bulgu = [];

        // 1) HALKA VAR MI? (Tailwind `ring` = box-shadow ile de yapilabilir.)
        if (st.outlineStyle === "none" || kalinlik === 0) {
          if (st.boxShadow === "none" || !st.boxShadow) {
            bulgu.push(`HALKA YOK: ${etiket}`);
          }
          return { stil, etiket, bulgu };
        }

        // 2) KONTRAST — WCAG 1.4.11.
        const halka = cozRenk(st.outlineColor);
        if (halka) {
          const oran = kontrast(halka, zemin(el));
          if (oran < esik) {
            bulgu.push(`HALKA KONTRASTI ${oran.toFixed(2)} < ${esik}: ${etiket}`);
          }
        }

        // 3) KIRPILMA — halka `outline-offset + kalinlik` kadar disa tasar.
        const pay = (parseFloat(st.outlineOffset) || 0) + kalinlik;
        if (pay > 0) {
          const r = el.getBoundingClientRect();
          let n = el.parentElement;
          while (n && n !== document.body) {
            const ns = getComputedStyle(n);
            if (/(hidden|clip|auto|scroll)/.test(ns.overflowX + ns.overflowY)) {
              const nr = n.getBoundingClientRect();
              const tasma = Math.max(
                nr.left - (r.left - pay),
                (r.right + pay) - nr.right,
                nr.top - (r.top - pay),
                (r.bottom + pay) - nr.bottom,
              );
              if (tasma > 0.5) {
                bulgu.push(`HALKA KIRPILIYOR (${Math.round(tasma)}px): ${etiket}`);
              }
              break;
            }
            n = n.parentElement;
          }
        }
        return { stil, etiket, bulgu };
      }, ESIK).catch(() => ({ stil: true, bitti: true }));

      stilVar = olcum.stil;
      if (olcum.bitti) break;
      // Ayni ogeye geri donduysek tur kapandi.
      if (olcum.etiket && gorulen.has(olcum.etiket) && gorulen.size > 3) break;
      if (olcum.etiket) gorulen.add(olcum.etiket);
      yoklanan++;
      for (const b of olcum.bulgu ?? []) ihlaller.push(b);
    }
    const rapor = {
      stilVar,
      yoklanan,
      toplam: ihlaller.length,
      ihlal: ihlaller.slice(0, 6),
    };

    if (!rapor.stilVar) {
      bulgular.push([tema, yol, "CSS UYGULANMADI — olcum GECERSIZ"]);
      continue;
    }
    // OLCUM BOS KOSMASIN: odaklanabilir oge yoksa surus hicbir sey denetlemez.
    if (rapor.yoklanan < 3) {
      bulgular.push([tema, yol, `yalniz ${rapor.yoklanan} oge odaklandi — olcum bos`]);
      continue;
    }
    for (const i of rapor.ihlal) bulgular.push([tema, yol, i]);
    if (rapor.toplam > rapor.ihlal.length) {
      bulgular.push([tema, yol,
        `(+${rapor.toplam - rapor.ihlal.length} ihlal daha — tavan)`]);
    }
  }
  await ctx.close();
}
await tarayici.close();

console.log(`kontrol: ${TEMALAR.length * SAYFALAR.length} sayfa-tema`);
console.log(`BULGU: ${bulgular.length}`);
for (const b of bulgular.slice(0, 120)) console.log("  " + b.join(" | "));
if (DENEY) {
  const halkasiz = bulgular.some((b) => /HALKA YOK.*deney-halkasiz/.test(b[2]));
  const renk = bulgular.some((b) => /HALKA KONTRASTI.*deney-ayni-renk/.test(b[2]));
  console.log(`DEDEKTOR "halka yok":       ${halkasiz ? "OK" : "KOR"}`);
  console.log(`DEDEKTOR "halka kontrasti": ${renk ? "OK" : "KOR"}`);
}
