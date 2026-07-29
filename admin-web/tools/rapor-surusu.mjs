// TUR 41 — RAPOR SONUCLARINI sur (panelde DOLU VERI).
//
// Tur 36 envanteri: `/reports/*` sayfalari her suruste YALNIZ SORGU FORMU
// halinde olculuyordu — sonuc tablosuna hicbir surus ugramamisti, cunku
// hicbiri "Raporu getir"e basmiyordu. Tablo basliklari, satirlar, toplam
// satiri, bos-sonuc hali ve CSV dugmesi hakkinda elimizde hicbir olcum yoktu.
//
// Bu arac formu DOLDURUP calistirir, sonucun geldigini DOGRULAR (satir ya da
// bos-durum metni), sonra olcer: axe (acik + koyu tema), yatay tasma (360 dp),
// TR sizintisi (tr disi dillerde).
//
// KULLANIM: KOK=http://localhost:3131 node tools/rapor-surusu.mjs
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const AXE = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');

const KOK = process.env.KOK ?? 'http://localhost:3131';
const DILLER = ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'];
const TEMALAR = ['light', 'dark'];

// Doneme bagli rapor: seed verisi 2026 ortasinda — gecerli bir donem verilir.
const DONEM = process.env.DONEM ?? '2026-06';

const SAYFALAR = [
  {
    yol: '/reports/dues',
    ad: 'aidat tahsilat',
    // Tek metin alani = donem. Bulucu tipe gore (dilden bagimsiz).
    doldur: async (sayfa) => {
      const alan = sayfa.locator('input[type="text"], input:not([type])').first();
      if (await alan.count()) await alan.fill(DONEM);
    },
  },
  { yol: '/reports/patrols', ad: 'tur gecmisi' },
  { yol: '/reports/tasks', ad: 'gorev gecmisi' },
];

const TR = /[ğışĞİŞ]/;
const VERI = /Demo |Acme|Gece devriyesi|Ana Kapı|Otopark|Havuz|Kerem|Ayşe|Mehmet|Çiğdem/;

const tarayici = await chromium.launch();
const bulgular = [];
let sonucluOlcum = 0;

for (const tema of TEMALAR)
  for (const dil of DILLER) {
    const ctx = await tarayici.newContext({
      viewport: { width: 1280, height: 900 },
      locale: dil,
      reducedMotion: 'reduce',
      colorScheme: tema,
    });
    const api = await ctx.request.post(`${KOK}/api/auth/login`, {
      data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
    });
    if (!api.ok()) { bulgular.push([`${tema}/${dil}`, '-', 'LOGIN BASARISIZ']); await ctx.close(); continue; }
    await ctx.addCookies([{ name: 'ui.locale', value: dil, url: KOK }]);
    const sayfa = await ctx.newPage();
    await sayfa.addInitScript((t) => {
      try { localStorage.setItem('theme', t); } catch { /* yok say */ }
    }, tema);

    for (const { yol, ad, doldur } of SAYFALAR) {
      await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
      if (doldur) await doldur(sayfa);

      // "Raporu getir" = formun submit dugmesi (metne DEGIL tipe bakilir).
      const dugme = sayfa.locator('form button[type="submit"]').first();
      if (!(await dugme.count())) {
        bulgular.push([`${tema}/${dil}`, yol, 'SORGU DUGMESI YOK']);
        continue;
      }
      await dugme.click();
      await sayfa.waitForTimeout(1200);

      // SONUC GELDI MI? Tablo satiri ya da bilinen bos-durum. Gelmediyse
      // olcum yapmanin anlami yok — "temiz" raporu bos cikardi.
      const durum = await sayfa.evaluate(() => {
        const govde = document.querySelector('main') ?? document.body;
        // TR taramasi icin VERI hucreleri (td) DISARIDA: tablo govdesindeki
        // metin sunucu verisidir ve cevrilmemesi DOGRUDUR. Ilk kosumda
        // kelime bazli tarama seed gorev adindaki "sızıntısı"yi sizinti
        // saniyordu — baglami kaybeden bir tarama, olcum degil gurultu.
        const kopya = govde.cloneNode(true);
        for (const td of kopya.querySelectorAll('td')) td.remove();
        return {
          satir: govde.querySelectorAll('tbody tr').length,
          metin: govde.innerText.replace(/\s+/g, ' '),
          arayuzMetni: kopya.innerText.replace(/\s+/g, ' '),
        };
      });
      if (durum.satir === 0) {
        bulgular.push([`${tema}/${dil}`, yol,
          `SONUC YOK: "${ad}" sorgusu satir uretmedi — son="${durum.metin.slice(-120)}"`]);
        continue;
      }
      sonucluOlcum++;

      // TR sizintisi (sunucu VERISI haric).
      if (dil !== 'tr') {
        for (const kelime of durum.arayuzMetni.split(' ')) {
          if (TR.test(kelime) && !VERI.test(kelime) && kelime.length > 2) {
            bulgular.push([`${tema}/${dil}`, yol, `TR SIZINTI: ${kelime}`]);
            break;
          }
        }
      }

      await sayfa.addScriptTag({ content: AXE }).catch(() => {});
      const axe = await sayfa.evaluate(async () => {
        const r = await window.axe.run(document, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] },
        });
        return r.violations.map((v) => ({
          id: v.id, etki: v.impact, sayi: v.nodes.length,
          ornek: (v.nodes[0]?.html ?? '').slice(0, 60),
        }));
      }).catch((e) => ({ hata: String(e).slice(0, 60) }));
      if (Array.isArray(axe)) {
        for (const v of axe) {
          bulgular.push([`${tema}/${dil}`, yol, `AXE ${v.id} (${v.etki}, ${v.sayi}x): ${v.ornek}`]);
        }
      }

      // 360 dp: sonuc tablosu yatay tasma yaratiyor mu?
      await sayfa.setViewportSize({ width: 360, height: 780 });
      await sayfa.waitForTimeout(250);
      const tasma = await sayfa.evaluate(() =>
        document.documentElement.scrollWidth - document.documentElement.clientWidth);
      if (tasma > 1) bulgular.push([`${tema}/${dil}`, yol, `YATAY TASMA 360dp: +${tasma}px`]);
      await sayfa.setViewportSize({ width: 1280, height: 900 });
    }
    await ctx.close();
  }
await tarayici.close();

console.log(`kontrol: ${TEMALAR.length * DILLER.length * SAYFALAR.length} sayfa-dil-tema, ${sonucluOlcum} sonuclu olcum`);
console.log(`BULGU: ${bulgular.length}`);
const ozet = {};
for (const [, , n] of bulgular) { const k = n.split(':')[0].slice(0, 45); ozet[k] = (ozet[k] ?? 0) + 1; }
for (const [k, v] of Object.entries(ozet).sort((a, b) => b[1] - a[1])) console.log(`  ${v}x ${k}`);
console.log('--- ornekler:');
for (const b of bulgular.slice(0, 16)) console.log('  ' + b.join(' | '));
