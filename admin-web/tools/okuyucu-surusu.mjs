// TUR 30 — paneli EKRAN OKUYUCU ile sur (mobil tur 29'un web karsiligi).
//
// Iki sey birden olculur:
//   1. axe-core denetimi (WCAG 2.1 A/AA) — etiketsiz dugme/alan, kontrast,
//      eksik landmark, bozuk baslik hiyerarsisi...
//   2. ERISILEBILIRLIK METINLERI CEVRILMIS MI — `aria-label`, `title`, `alt`
//      ekranda GORUNMEZ; gorunen metin cevrilip bunlar Turkce kalabilir ve
//      gormeyen kullanici Arapca arayuzde Turkce duyar (tur 29'un mobil
//      karsiliginda ayni sinif hata bulunmustu).
//
// KULLANIM: npx next start -p 3120 && node tools/okuyucu-surusu.mjs
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const AXE = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');

const KOK = process.env.KOK ?? 'http://localhost:3120';
const DILLER = ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'];
const SAYFALAR = ['/login','/dashboard','/tenants','/shifts','/checkpoints','/patrol-plans',
  '/tasks','/assets','/units','/building-editor','/schematic','/dues','/reports/dues',
  '/reports/patrols','/reports/tasks','/transparency','/users','/announcements','/complaints',
  '/notifications','/integrations','/support','/audit','/settings'];

// YALNIZ Turkcede bulunan harfler (ç/ö/ü Almanca/Fransizca'da da var).
const TR = /[ğışĞİŞ]/;
const MARKA = /Yönetio/i;
// SEED/TENANT VERISI — cevrilmemesi DOGRU olan metinler. Sablon cevrilmis
// olsa da icine giren VERI Turkce kalir: `alt="Image for Demo talep 2:
// Otopark bariyeri kırık"`. Mobil suruste de ayni ayrim var
// (`surusVerisi`); bu ayrimi yapmayan tarama yanlis alarm uretir ve
// zamanla susturulur.
const VERI = /Demo |Acme|Ana Kapı|Otopark|Havuz|Kazan|Bahçe|Asansör|kırık|Kerem|Ayşe|Mehmet/;

const tarayici = await chromium.launch();
const bulgular = [];

for (const dil of DILLER) {
  // `reducedMotion`: framer-motion giris animasyonu SURERKEN olcum yapmak
  // yanlis kontrast verir — dugme zemini (#0B7A79) yari saydam oldugu icin
  // #2b8c8b olarak olculuyordu ve "ihlal" raporlaniyordu. Hareket azaltma
  // hem animasyonu aninda bitirir hem de erisilebilirlik kullanicisinin
  // GERCEK deneyimidir (uygulama `MotionConfig reducedMotion="user"` ile
  // bunu zaten onurlandiriyor).
  const ctx = await tarayici.newContext({
    viewport: { width: 1280, height: 900 },
    locale: dil,
    reducedMotion: 'reduce',
  });
  const api = await ctx.request.post(`${KOK}/api/auth/login`, {
    data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
  });
  if (!api.ok()) { bulgular.push([dil, '-', 'LOGIN BASARISIZ']); await ctx.close(); continue; }
  await ctx.addCookies([{ name: 'ui.locale', value: dil, url: KOK }]);
  const sayfa = await ctx.newPage();

  for (const yol of SAYFALAR) {
    await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
    await sayfa.addScriptTag({ content: AXE }).catch(() => {});
    const sonuc = await sayfa.evaluate(async () => {
      const r = await window.axe.run(document, {
        runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] },
      });
      // Erisilebilirlik METINLERI: ekranda gorunmezler.
      const gizliMetinler = [];
      for (const el of document.querySelectorAll('[aria-label],[title],img[alt]')) {
        for (const oz of ['aria-label', 'title', 'alt']) {
          const v = el.getAttribute(oz);
          if (v && v.trim()) gizliMetinler.push(`${oz}="${v.trim()}"`);
        }
      }
      return {
        ihlaller: r.violations.map((v) => ({
          id: v.id, etki: v.impact, sayi: v.nodes.length,
          ornek: (v.nodes[0]?.html ?? '').slice(0, 70),
        })),
        gizliMetinler: [...new Set(gizliMetinler)],
      };
    }).catch((e) => ({ hata: String(e).slice(0, 80) }));

    if (sonuc.hata) { bulgular.push([dil, yol, sonuc.hata]); continue; }
    for (const v of sonuc.ihlaller) {
      bulgular.push([dil, yol, `AXE ${v.id} (${v.etki}, ${v.sayi}x): ${v.ornek}`]);
    }
    if (dil !== 'tr') {
      for (const m of sonuc.gizliMetinler) {
        if (TR.test(m) && !MARKA.test(m) && !VERI.test(m)) {
          bulgular.push([dil, yol, `TR SIZINTI: ${m}`]);
        }
      }
    }
  }
  await ctx.close();
}
await tarayici.close();
console.log(`kontrol: ${DILLER.length * SAYFALAR.length} sayfa-dil`);
console.log(`BULGU: ${bulgular.length}`);
const ozet = {};
for (const [, , n] of bulgular) { const k = n.split(':')[0].slice(0, 45); ozet[k] = (ozet[k] ?? 0) + 1; }
for (const [k, v] of Object.entries(ozet).sort((a, b) => b[1] - a[1])) console.log(`  ${v}x ${k}`);
console.log('--- ornekler:');
for (const b of bulgular.slice(0, 12)) console.log('  ' + b.join(' | '));
