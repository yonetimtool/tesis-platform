// TUR 35 — paneli FOTOGRAFLI VERIYLE sur (mobil tur 34'un web karsiligi).
//
// Onceki panel suruslerinin hepsi fotograf tasiyan sayfalari da geziyordu
// AMA fotograflar YUKLENMIYORDU: seed, `complaint_photo.foto_key` alanina
// MinIO'ya HIC yuklenmemis bir anahtar yaziyordu (presigned URL gecerli,
// obje yok -> NoSuchKey). Yani her surus KIRIK GORSEL halini olcup "temiz"
// diyordu. Bu arac once fotografin GERCEKTEN yuklendigini dogrular, sonra
// fotografli DURUMU olcer.
//
// Olculen:
//   1. YUKLENDI MI — `naturalWidth > 0`. Kirik gorsel bulgudur.
//   2. ALT METNI — var mi, bos mu, Turkce mi sizmis (tr disi dillerde).
//   3. DUZEN KAYMASI (CLS) — sayfa ONCE gorseller ENGELLENEREK, sonra
//      normal cizilir; belge yuksekligi degisiyorsa gorsel icin yer
//      AYRILMAMIS demektir ve icerik yuklenirken zipliyor.
//   4. AXE — fotografli durumda WCAG 2.1 A/AA (acik + koyu tema).
//   5. TASMA — 360 dp'de fotograf yatay tasmaya yol aciyor mu.
//
// Fotografli DURUMLAR bazen etkilesim ister (destek biletinin detay
// bolmesi) — `hazirla` ile acilir.
//
// KULLANIM: npx next build && npx next start -p 3128
//           KOK=http://localhost:3128 node tools/foto-surusu.mjs
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const AXE = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');

const KOK = process.env.KOK ?? 'http://localhost:3128';
// DEDEKTOR SINAMASI (DENEY=1): sayfaya bilerek bozuk/alt'siz/yer ayirmayan
// gorsel enjekte edilir ve UCUNUN DE yakalandigi dogrulanir. "0 bulgu" ancak
// tarama gercekten olcuyorsa bir sey ifade eder.
const DENEY = process.env.DENEY === '1';
const DILLER = DENEY ? ['tr'] : ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'];
const TEMALAR = DENEY ? ['light'] : ['light', 'dark'];

// Marka logosu her sayfada var ve fotograf DEGIL — sayim disi.
const MARKA_GORSEL = /yonetio/i;

const SAYFALAR = [
  { yol: '/complaints', ad: 'talep fotograflari' },
  { yol: '/announcements', ad: 'duyuru gorseli' },
  {
    yol: '/support',
    ad: 'destek bileti gorseli',
    // Gorsel DETAY bolmesindedir: listedeki "Yanitla" dugmesi acar.
    // Dilden bagimsiz secici: satirdaki son hucrenin dugmesi.
    hazirla: async (sayfa) => {
      const dugme = sayfa.locator('tbody tr td:last-child button').first();
      if (await dugme.count()) {
        await dugme.click();
        await sayfa.waitForTimeout(600);
      }
    },
  },
];

const TR = /[ğışĞİŞ]/;
// Sunucu VERISI (talep basligi, tesis adi) alt metnine girer — cevrilmemesi
// dogrudur (mobil `surusVerisi`, panel okuyucu surusundeki `VERI` emsali).
const VERI = /Demo |Acme|Otopark|Hoş geldiniz|kırık|Panel bildirim/;

const tarayici = await chromium.launch();
const bulgular = [];
let toplamFoto = 0;

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

    for (const { yol, ad, hazirla } of SAYFALAR) {
      await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
      if (hazirla) await hazirla(sayfa);
      // Gorsellerin cozulmesini bekle (presigned GET + MinIO).
      await sayfa.waitForTimeout(900);

      if (DENEY) {
        await sayfa.evaluate(() => {
          const kirik = document.createElement('img');
          kirik.src = 'http://127.0.0.1:1/deney-yok.png';
          kirik.alt = 'deney kirik';
          document.body.prepend(kirik);
          const altsiz = document.createElement('img');
          // Marka suzgecine TAKILMAYAN bir ad: `/yonetio-*` deseni sayimdan
          // dusuruluyor ve ilk denemede kendi deneyimi kendim susturmustum.
          altsiz.src = '/deney-altsiz.png';
          document.body.prepend(altsiz);
        });
        await sayfa.waitForTimeout(400);
      }

      const gorseller = await sayfa.evaluate((marka) => {
        const re = new RegExp(marka, 'i');
        return [...document.querySelectorAll('img')]
          .filter((i) => !re.test(i.currentSrc || i.src || ''))
          .map((i) => {
            const s = getComputedStyle(i);
            return {
              yuklendi: i.complete && i.naturalWidth > 0,
              alt: i.getAttribute('alt'),
              src: (i.currentSrc || i.src || '').slice(0, 60),
              _s: s.aspectRatio,
            };
          });
      }, MARKA_GORSEL.source);

      if (gorseller.length === 0) {
        // NEDENI de kaydet: "fotograf yok" ile "sayfa hic veri gostermiyor"
        // ayri sorunlardir ve ilk kosumda ikincisini birincisi saniyordum.
        const tani = await sayfa.evaluate(() => ({
          satir: document.querySelectorAll('tbody tr, article, li').length,
          hata: document.body.innerText.match(/(hata|error|خطأ|ошибка|fehler|erreur)/i)?.[0] ?? null,
          metin: document.body.innerText.replace(/\s+/g, ' ').slice(-160),
        }));
        bulgular.push([`${tema}/${dil}`, yol,
          `FOTOGRAF YOK: "${ad}" cizilmedi — satir=${tani.satir} hata=${tani.hata} son="${tani.metin}"`]);
        continue;
      }
      toplamFoto += gorseller.length;

      for (const g of gorseller) {
        if (!g.yuklendi) bulgular.push([`${tema}/${dil}`, yol, `KIRIK GORSEL: ${g.src}`]);
        if (g.alt === null) bulgular.push([`${tema}/${dil}`, yol, `ALT YOK: ${g.src}`]);
        else if (dil !== 'tr' && TR.test(g.alt) && !VERI.test(g.alt)) {
          bulgular.push([`${tema}/${dil}`, yol, `ALT TR SIZINTI: ${g.alt.slice(0, 50)}`]);
        }
      }

      // DUZEN KAYMASI: ayni sayfa gorseller ENGELLENEREK cizilir; belge
      // yuksekligi farkliysa gorsel icin yer ayrilmamis demektir.
      // (Ilk denemede "olculu mu" diye COMPUTED STYLE'a bakiyordum —
      // Chromium `width/height` icin asla 'auto' dondurmez, yani o kontrol
      // HER ZAMAN geciyordu: olcen degil, susturan bir kontroldu.)
      await sayfa.route('**/*', (r) =>
        r.request().resourceType() === 'image' ? r.abort() : r.continue());
      await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
      if (hazirla) await hazirla(sayfa);
      await sayfa.waitForTimeout(400);
      const gorselsizYukseklik = await sayfa.evaluate(() => document.body.scrollHeight);
      await sayfa.unroute('**/*');
      await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
      if (hazirla) await hazirla(sayfa);
      await sayfa.waitForTimeout(900);
      const gorselliYukseklik = await sayfa.evaluate(() => document.body.scrollHeight);
      const fark = Math.abs(gorselliYukseklik - gorselsizYukseklik);
      if (fark > 8) {
        bulgular.push([`${tema}/${dil}`, yol,
          `DUZEN KAYMASI: gorsel yuklenince belge ${fark}px degisiyor (yer ayrilmamis)`]);
      }

      // axe — fotografli DURUMDA.
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

      // 360 dp: fotograf yatay tasmaya yol aciyor mu?
      await sayfa.setViewportSize({ width: 360, height: 780 });
      await sayfa.waitForTimeout(250);
      const tasma = await sayfa.evaluate(() =>
        document.documentElement.scrollWidth - document.documentElement.clientWidth);
      if (tasma > 1) {
        bulgular.push([`${tema}/${dil}`, yol, `YATAY TASMA 360dp: +${tasma}px`]);
      }
      await sayfa.setViewportSize({ width: 1280, height: 900 });
    }
    await ctx.close();
  }
await tarayici.close();

console.log(`kontrol: ${TEMALAR.length * DILLER.length * SAYFALAR.length} sayfa-dil-tema, ${toplamFoto} gorsel`);
console.log(`BULGU: ${bulgular.length}`);
const ozet = {};
for (const [, , n] of bulgular) { const k = n.split(':')[0].slice(0, 45); ozet[k] = (ozet[k] ?? 0) + 1; }
for (const [k, v] of Object.entries(ozet).sort((a, b) => b[1] - a[1])) console.log(`  ${v}x ${k}`);
if (DENEY) {
  const siniflar = ['KIRIK GORSEL', 'ALT YOK'];
  let eksik = 0;
  for (const c of siniflar) {
    const n = bulgular.filter(([, , m]) => m.startsWith(c)).length;
    console.log(`DEDEKTOR ${c}: ${n} bulgu ${n > 0 ? 'OK' : '*** YAKALAMADI ***'}`);
    if (n === 0) eksik++;
  }
  if (eksik > 0) process.exitCode = 1;
}
console.log('--- ornekler:');
for (const b of bulgular.slice(0, 16)) console.log('  ' + b.join(' | '));
