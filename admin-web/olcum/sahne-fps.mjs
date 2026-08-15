/**
 * (P161) SAHNE OLCUMU — kare suresi + GERCEK cizim cagrisi sayisi.
 *
 * =========================================================================
 * NE OLCULUYOR, NE OLCULMUYOR
 * =========================================================================
 * CIZIM CAGRISI SAYISI GPU'DAN BAGIMSIZDIR ve dogrudan brief'in
 * "yuzlerce daire ayri mesh olmasin" kuralini olcer. WebGL cizim
 * fonksiyonlari tarayici tarafinda sarmalanip sayilir; urun kodu bunun
 * icin hicbir sey tasimaz.
 *
 * KARE SURESI BURADA BIR ALT SINIRDIR, gercek FPS degil: bu ortamda GPU
 * yok, Chromium SwiftShader (YAZILIM rasterlayici) ile calisiyor. Yazilim
 * rasterlaymasi her gercek GPU'dan kat kat yavastir. Yani olculen sayi
 * "en kotu durum"dur; gercek bir dizustunde daha iyisi beklenir. Bu
 * dosyanin ciktisinda hangi rasterlayicinin kullanildigi da yazar ki
 * sayilar baglamsiz okunmasin.
 *
 * Kullanim: `npm run dev` acikken `node olcum/sahne-fps.mjs`
 */
import { chromium } from "playwright";

const TABAN = process.env.OLCUM_URL ?? "http://localhost:3000";
const SENARYOLAR = [
  { ad: "kucuk site", blok: 2, kat: 5, katbasi: 4 },
  { ad: "orta site", blok: 4, kat: 8, katbasi: 6 },
  { ad: "buyuk site", blok: 6, kat: 12, katbasi: 8 },
];
const ISINMA_MS = 2500;
const OLCUM_MS = 5000;

const HAZIRLIK = `
  window.__olcum = { kare: [], cizim: 0, sonCizim: 0 };
  const say = (proto, ad) => {
    if (!proto || !proto[ad]) return;
    const asil = proto[ad];
    proto[ad] = function (...a) { window.__olcum.cizim++; return asil.apply(this, a); };
  };
  for (const p of [WebGLRenderingContext.prototype, WebGL2RenderingContext.prototype]) {
    say(p, "drawArrays"); say(p, "drawElements");
    say(p, "drawArraysInstanced"); say(p, "drawElementsInstanced");
  }
  let onceki = performance.now();
  const tik = (t) => {
    window.__olcum.kare.push(t - onceki);
    window.__olcum.sonCizim = window.__olcum.cizim;
    window.__olcum.cizim = 0;
    onceki = t;
    requestAnimationFrame(tik);
  };
  requestAnimationFrame(tik);
`;

function yuzdelik(dizi, p) {
  if (dizi.length === 0) return 0;
  const s = [...dizi].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((s.length - 1) * p))];
}

const tarayici = await chromium.launch({
  args: ["--use-gl=swiftshader", "--enable-unsafe-swiftshader"],
});
const sayfa = await tarayici.newPage({ viewport: { width: 1440, height: 900 } });
await sayfa.addInitScript(HAZIRLIK);

const rasterlayici = await sayfa.evaluate(() => {
  const c = document.createElement("canvas");
  const gl = c.getContext("webgl2") ?? c.getContext("webgl");
  const d = gl?.getExtension("WEBGL_debug_renderer_info");
  return d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : "?";
});

const satirlar = [];
for (const s of SENARYOLAR) {
  const daire = s.blok * s.kat * s.katbasi;
  await sayfa.goto(`${TABAN}/olcum/sahne?blok=${s.blok}&kat=${s.kat}&katbasi=${s.katbasi}`, {
    waitUntil: "networkidle",
  });
  await sayfa.waitForSelector("canvas", { timeout: 30000 });
  await sayfa.waitForTimeout(ISINMA_MS);
  await sayfa.evaluate(() => {
    window.__olcum.kare.length = 0;
  });
  await sayfa.waitForTimeout(OLCUM_MS);
  const o = await sayfa.evaluate(() => ({
    kare: window.__olcum.kare,
    cizim: window.__olcum.sonCizim,
  }));
  const ort = o.kare.reduce((a, b) => a + b, 0) / Math.max(1, o.kare.length);
  satirlar.push({
    senaryo: s.ad,
    blok: s.blok,
    daire,
    "cizim/kare": o.cizim,
    "ort ms": +ort.toFixed(2),
    "p95 ms": +yuzdelik(o.kare, 0.95).toFixed(2),
    "ort fps": +(1000 / ort).toFixed(1),
    "en dusuk fps": +(1000 / yuzdelik(o.kare, 0.99)).toFixed(1),
  });
}

console.log(`rasterlayici: ${rasterlayici}`);
console.table(satirlar);
await tarayici.close();
