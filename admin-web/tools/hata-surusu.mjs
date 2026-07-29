// TUR 42 — HATA ve CEVRIMDISI durumlarini sur.
//
// Tur 36 envanterinin E maddesi: hicbir surus uctan HATA aldirmadi. Butun
// olcumler "her sey calisiyor" halinde yapildi. Oysa kullanicinin gordugu en
// kotu ekran budur: sunucu 500 verir ya da baglanti kopar.
//
// Iki kip:
//   * `500`      — BFF ucu 500 doner (sunucu hatasi).
//   * `cevrimdisi` — istek hic tamamlanmaz (baglanti yok).
//
// Olculen:
//   1. HATA GORUNUYOR MU — sayfa sessizce bos/iskelet kalirsa BULGUDUR:
//      kullanici neyin yanlis gittigini bilemez, yenileyemez.
//   2. TR SIZINTISI — hata metinleri de cevrilmis olmali (tur 14'te SUNUCU
//      metinleri yerellestirildi; istemci tarafi hic olculmemisti).
//   3. AXE — hata kutusunun kendi kontrasti/rolu.
//   4. YATAY TASMA — uzun hata metni dar ekranda tasiyor mu.
//
// KULLANIM: KOK=http://localhost:3134 node tools/hata-surusu.mjs
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const AXE = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');

const KOK = process.env.KOK ?? 'http://localhost:3134';
const DILLER = (process.env.DILLER ?? 'tr,en,ar,de').split(',');
const KIPLER = ['500', 'cevrimdisi'];
const SAYFALAR = ['/dashboard', '/tenants', '/shifts', '/checkpoints', '/patrol-plans',
  '/tasks', '/assets', '/units', '/building-editor', '/schematic', '/dues', '/transparency',
  '/users', '/announcements', '/complaints', '/notifications', '/integrations', '/support',
  '/audit'];

const TR = /[ğışĞİŞ]/;
const MARKA = /Yönetio/i;
// HAM TEKNIK METIN — kullaniciya gosterilmemeli. Tur 42'de cevrimdisi kipi
// her dilde "Failed to fetch" gosteriyordu; tur 41'de rapor kartlari
// "undefined" yaziyordu. Ikisi de bu kaliba girer.
const TEKNIK = /Failed to fetch|TypeError|NetworkError|\bundefined\b|\[object Object\]|SyntaxError/;

const tarayici = await chromium.launch();
const bulgular = [];

for (const kip of KIPLER)
  for (const dil of DILLER) {
    const ctx = await tarayici.newContext({
      viewport: { width: 1280, height: 900 },
      locale: dil,
      reducedMotion: 'reduce',
    });
    // Oturum acilirken hata ENJEKTE EDILMEZ; yoksa giris yapamayiz.
    const api = await ctx.request.post(`${KOK}/api/auth/login`, {
      data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
    });
    if (!api.ok()) { bulgular.push([`${kip}/${dil}`, '-', 'LOGIN BASARISIZ']); await ctx.close(); continue; }
    await ctx.addCookies([{ name: 'ui.locale', value: dil, url: KOK }]);
    const sayfa = await ctx.newPage();

    // VERI uclarini boz: kimlik/oturum uclari haric (sayfa acilabilsin).
    await sayfa.route('**/api/**', async (route) => {
      const url = route.request().url();
      if (url.includes('/api/auth/')) return route.continue();
      if (kip === '500') {
        return route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ code: 'server_error', message: 'Sunucu hatasi (surus)' }),
        });
      }
      return route.abort('failed');
    });

    for (const yol of SAYFALAR) {
      await sayfa.goto(KOK + yol, { waitUntil: 'domcontentloaded' }).catch(() => {});
      await sayfa.waitForTimeout(1500);

      const d = await sayfa.evaluate(() => {
        const govde = document.querySelector('main') ?? document.body;
        const metin = govde.innerText.replace(/\s+/g, ' ').trim();
        return {
          metin,
          uzunluk: metin.length,
          // Hata kutusu: `role="alert"` ya da kirmizi tonlu kutu.
          uyari: govde.querySelectorAll('[role="alert"], .text-red-700, .text-red-600, [class*="bg-red"]').length,
          gizliMetinler: [...govde.querySelectorAll('[aria-label],[title]')]
            .map((e) => e.getAttribute('aria-label') || e.getAttribute('title'))
            .filter(Boolean),
        };
      });

      // 1) Hata GORUNUYOR mu?
      if (d.uyari === 0) {
        bulgular.push([`${kip}/${dil}`, yol,
          `SESSIZ HATA: uyari yok — ekranda "${d.metin.slice(0, 90)}"`]);
      }

      // 2a) HAM TEKNIK METIN (dilden bagimsiz).
      if (TEKNIK.test(d.metin)) {
        const es = d.metin.match(TEKNIK)?.[0] ?? '';
        bulgular.push([`${kip}/${dil}`, yol, `TEKNIK METIN: "${es}" kullaniciya gosteriliyor`]);
      }

      // 2) TR sizintisi (tr disi dillerde), gorunen + gizli metinlerde.
      if (dil !== 'tr') {
        for (const m of [d.metin, ...d.gizliMetinler]) {
          if (TR.test(m) && !MARKA.test(m)) {
            const kelime = m.split(' ').find((w) => TR.test(w)) ?? m.slice(0, 40);
            bulgular.push([`${kip}/${dil}`, yol, `TR SIZINTI: ${kelime}`]);
            break;
          }
        }
      }

      // 3) axe
      await sayfa.addScriptTag({ content: AXE }).catch(() => {});
      const axe = await sayfa.evaluate(async () => {
        const r = await window.axe.run(document, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] },
        });
        return r.violations.map((v) => ({
          id: v.id, etki: v.impact, sayi: v.nodes.length,
          ornek: (v.nodes[0]?.html ?? '').slice(0, 60),
        }));
      }).catch(() => []);
      for (const v of axe) {
        bulgular.push([`${kip}/${dil}`, yol, `AXE ${v.id} (${v.etki}, ${v.sayi}x): ${v.ornek}`]);
      }

      // 4) 360 dp yatay tasma
      await sayfa.setViewportSize({ width: 360, height: 780 });
      await sayfa.waitForTimeout(200);
      const tasma = await sayfa.evaluate(() =>
        document.documentElement.scrollWidth - document.documentElement.clientWidth);
      if (tasma > 1) bulgular.push([`${kip}/${dil}`, yol, `YATAY TASMA 360dp: +${tasma}px`]);
      await sayfa.setViewportSize({ width: 1280, height: 900 });
    }
    await ctx.close();
  }
await tarayici.close();

console.log(`kontrol: ${KIPLER.length * DILLER.length * SAYFALAR.length} sayfa-dil-kip`);
console.log(`BULGU: ${bulgular.length}`);
const ozet = {};
for (const [, , n] of bulgular) { const k = n.split(':')[0].slice(0, 45); ozet[k] = (ozet[k] ?? 0) + 1; }
for (const [k, v] of Object.entries(ozet).sort((a, b) => b[1] - a[1])) console.log(`  ${v}x ${k}`);
for (const kip of KIPLER) {
  const t = bulgular.filter((b) => b[0].startsWith(kip + '/'));
  console.log(`--- ${kip} (${t.length}):`);
  for (const b of t.slice(0, 12)) console.log('  ' + b.join(' | '));
}
