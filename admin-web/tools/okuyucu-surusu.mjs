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

import { tesisYollariCoz } from './tesis-id.mjs';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const AXE = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');

const KOK = process.env.KOK ?? 'http://localhost:3120';
// DEDEKTOR SINAMASI (DENEY=1) — TUR 62.
//
// Ucuncu envanterin C maddesi: bu arac 350 kosumluk EN BUYUK surus ve
// kendisini hic sinamiyordu. `DENEY=1` olcumden hemen once sayfaya IKI kasitli
// kusur enjekte eder:
//   1. `alt`siz gorsel   -> axe `image-alt` ihlali gormeli,
//   2. `aria-label` icinde TURKCE metin -> TR SIZINTI gormeli.
// Enjeksiyon hidrasyondan SONRA yapilir: `DOMContentLoaded`da eklenen dugumu
// React siliyor (tur 60'ta bu tuzaga dusuldu).
const DENEY = process.env.DENEY === '1';
const _DILLER_TAM = ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'];
// TEMA da bir eksen (tur 32): kontrast KOYU zeminde bambaska cikar ve
// tur 30 denetimi YALNIZ acik temada kosmustu. Tema `<html class="dark">`
// ile ve `localStorage.theme` uzerinden kalicidir.
const TEMALAR_TAM = ['light', 'dark'];
const SAYFALAR_TAM = ['/login','/dashboard','/tenants','/shifts','/checkpoints','/patrol-plans',
  '/tasks','/assets','/units','/building-editor','/schematic','/dues','/reports/dues',
  '/reports/patrols','/reports/tasks','/transparency','/users','/announcements','/complaints',
  '/notifications','/integrations','/support','/audit','/settings','/tenants/:id'];
// DENEY kipinde tek dil/tema/sayfa: sinama hizli olsun.
// DENEY dili `en`: TR sizinti kurali YALNIZ tr disi dillerde kosar, `tr` ile
// sinasak o kural hic denenmemis olurdu (ilk sinamada "KOR" cikti ve sebebi
// buydu — dedektorun dedektoru).
const DILLER = DENEY ? ['en'] : _DILLER_TAM;
const TEMALAR = DENEY ? ['light'] : TEMALAR_TAM;
// SADECE='/integrations,/users' → yalniz o sayfalar. Bir bulgu duzeltildikten
// sonra 350 kosumluk tam surusu beklemeden dogrulamak icin (tur 62;
// `dar-ekran-surusu`daki ayni kolaylik).
const _SUZGEC = (process.env.SADECE ?? '').split(',').filter(Boolean);
const SAYFALAR = DENEY
  ? ['/dashboard']
  : _SUZGEC.length
    ? SAYFALAR_TAM.filter((y) => _SUZGEC.some((f) => y.includes(f)))
    : SAYFALAR_TAM;

// YALNIZ Turkcede bulunan harfler (ç/ö/ü Almanca/Fransizca'da da var).
const TR = /[ğışĞİŞ]/;
const MARKA = /Yönetiyor/i;
// SEED/TENANT VERISI — cevrilmemesi DOGRU olan metinler. Sablon cevrilmis
// olsa da icine giren VERI Turkce kalir: `alt="Image for Demo talep 2:
// Otopark bariyeri kırık"`. Mobil suruste de ayni ayrim var
// (`surusVerisi`); bu ayrimi yapmayan tarama yanlis alarm uretir ve
// zamanla susturulur.
const VERI = /Demo |Acme|Ana Kapı|Otopark|Havuz|Kazan|Bahçe|Asansör|kırık|Kerem|Ayşe|Mehmet/;

const tarayici = await chromium.launch();
const bulgular = [];

for (const tema of TEMALAR)
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
    // Isletim sistemi tercihi de temayla ayni olsun: `theme=system` yolunu
    // ve `prefers-color-scheme` sorgularini da dogru tarafa dusurur.
    colorScheme: tema,
  });
  const api = await ctx.request.post(`${KOK}/api/auth/login`, {
    data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
  });
  if (!api.ok()) { bulgular.push([`${tema}/${dil}`, '-', 'LOGIN BASARISIZ']); await ctx.close(); continue; }
  await ctx.addCookies([{ name: 'ui.locale', value: dil, url: KOK }]);
  const sayfa = await ctx.newPage();
  // Temayi ILK BOYAMADAN once ayarla: layout'taki satir-ici script
  // localStorage'i okuyup `.dark` sinifini kendisi atar (FOUC yok).
  await sayfa.addInitScript((t) => {
    try { localStorage.setItem('theme', t); } catch { /* yok say */ }
  }, tema);

  // `/tenants/:id` calisma aninda cozulur (tur 61).
  const yollar = await tesisYollariCoz(ctx, KOK, SAYFALAR);
  for (const yol of yollar) {
    await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
    if (DENEY) {
      // Hidrasyon bitti; simdi kasitli kusurlari ekle (bkz. dosya basi).
      await sayfa.evaluate(() => {
        const kap = document.querySelector('main') ?? document.body;
        const img = document.createElement('img');
        img.src =
          'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
        img.width = 24;
        img.height = 24;
        kap.appendChild(img);          // alt YOK -> axe image-alt
        const b = document.createElement('button');
        b.setAttribute('aria-label', 'Deney: kayıt sil');  // TR sizinti
        b.textContent = 'x';
        kap.appendChild(b);
      });
    }
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

    if (sonuc.hata) { bulgular.push([`${tema}/${dil}`, yol, sonuc.hata]); continue; }
    for (const v of sonuc.ihlaller) {
      bulgular.push([`${tema}/${dil}`, yol, `AXE ${v.id} (${v.etki}, ${v.sayi}x): ${v.ornek}`]);
    }
    if (dil !== 'tr') {
      for (const m of sonuc.gizliMetinler) {
        if (TR.test(m) && !MARKA.test(m) && !VERI.test(m)) {
          bulgular.push([`${tema}/${dil}`, yol, `TR SIZINTI: ${m}`]);
        }
      }
    }
  }
  await ctx.close();
}
await tarayici.close();
console.log(`kontrol: ${TEMALAR.length * DILLER.length * SAYFALAR.length} sayfa-dil-tema`);
if (DENEY) {
  const axeGordu = bulgular.some((b) => /AXE image-alt/.test(b[2]));
  const trGordu = bulgular.some((b) => /TR SIZINTI/.test(b[2]));
  console.log(`DEDEKTOR axe(image-alt): ${axeGordu ? 'OK' : 'KOR'}`);
  console.log(`DEDEKTOR TR sizinti:     ${trGordu ? 'OK' : 'KOR'}`);
}
console.log(`BULGU: ${bulgular.length}`);
const ozet = {};
for (const [, , n] of bulgular) { const k = n.split(':')[0].slice(0, 45); ozet[k] = (ozet[k] ?? 0) + 1; }
for (const [k, v] of Object.entries(ozet).sort((a, b) => b[1] - a[1])) console.log(`  ${v}x ${k}`);
// Ornekleri TEMA basina ayri bas: koyu temanin bulgulari acik temanin
// listesi altinda gomulu kalmasin.
for (const tema of TEMALAR) {
  const t = bulgular.filter((b) => b[0].startsWith(tema + '/'));
  console.log(`--- ${tema} (${t.length}):`);
  for (const b of t.slice(0, 14)) console.log('  ' + b.join(' | '));
}
