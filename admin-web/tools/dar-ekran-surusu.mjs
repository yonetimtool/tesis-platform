// TUR 25 — paneli DAR EKRANDA 7 dilde sur.  KULLANIM:
//   npx next build && npx next start -p 3115
//   node tools/dar-ekran-surusu.mjs            # KOK ile port degistirilir
// Cikis: bulgu sayisi + (olcu | dil | sayfa | sorun) satirlari. Mobilde (tur 24) sabit olculu
// kutu + uzun ceviri 10 px tasirmisti; web'in karsiligi YATAY TASMA:
// govde kendi genisliginden genis olur ve sayfa yana kayar.
import { chromium } from 'playwright';

import { tesisYollariCoz } from './tesis-id.mjs';

const KOK = process.env.KOK ?? 'http://localhost:3115';
// DEDEKTOR SINAMASI (DENEY=1): her sayfaya, YALNIZ yeni eksenlerde tasan bir
// oge enjekte edilir (genislik = viewport + 40px, kirpan atasi YOK) ve tek
// sayfa/tek dil kosulur. BULGU=0 cikarsa olcum kor demektir.
const DENEY = process.env.DENEY === '1';
const DILLER = DENEY ? ['tr'] : ['tr','en','ar','ru','de','fr','es'];
const AZ = DENEY ? ['tr'] : ['tr','de','ar'];
// Olcu = viewport + KOK YAZI BOYU. Tarayicinin "varsayilan yazi boyu"
// ayari (Chrome: Ayarlar > Gorunum > Yazi tipi boyutu) rem tabanli
// olculeri buyutur; Tailwind rem kullandigi icin metin de bosluk da
// buyur — mobil tur 27'deki TextScaler'in web karsiligi.
//
// TUR 59: eksen DEGERLERI genisletildi. Onceki dort olcu telefon/dar ekran
// ekseninde kaliyordu; envanter (tur 49, D maddesi) sunlari kor nokta olarak
// yazdi: TABLET, YATAY yon, ULTRA-GENIS, kucuk yazi (0.85x karsiligi 14px),
// yuksek DPR ve `forcedColors` gibi SISTEM ayarlari.
const OLCULER = [
  { ad: '360dp', w: 360, h: 780, kok: 16 },
  { ad: '414dp', w: 414, h: 896, kok: 16 },
  { ad: '360dp/20px', w: 360, h: 780, kok: 20 },
  { ad: '1280px/24px', w: 1280, h: 900, kok: 24 },
  // --- tur 59 --- Yeni olculer UC dille kosuyor: `de` en uzun metin,
  // `ar` RTL, `tr` taban. Yedi dilin tamami ilk dort olcude zaten kosuyor;
  // burada amac eksen DEGERI, dil kapsamasi degil.
  { ad: 'kucuk yazi 14px', w: 1280, h: 900, kok: 14, diller: AZ },
  { ad: 'tablet 768', w: 768, h: 1024, kok: 16, dpr: 2, diller: AZ },
  { ad: 'tablet YATAY 1024', w: 1024, h: 768, kok: 16, dpr: 2, diller: AZ },
  { ad: 'ultra genis 1920', w: 1920, h: 1080, kok: 16, diller: AZ },
  { ad: 'dar + buyuk yazi', w: 320, h: 720, kok: 22, diller: AZ },
  // ANIMASYON SURERKEN: `networkidle` beklemek yerine DOM hazir olur olmaz
  // olcer. Gecis/iskelet animasyonlari HENUZ BITMEMISTIR — tur 49'un D
  // maddesindeki "animasyon sururken hicbir sey olculmuyor" korlugu.
  { ad: 'ANIMASYON sururken', w: 360, h: 780, kok: 16, diller: AZ, hemen: true },
];
const SAYFALAR = DENEY ? ['/dashboard'] : ['/dashboard','/tenants','/shifts','/checkpoints','/patrol-plans','/tasks',
  '/assets','/units','/building-editor','/schematic','/dues','/reports/dues','/reports/patrols',
  '/reports/tasks','/transparency','/users','/announcements','/complaints','/notifications',
  '/integrations','/support','/audit','/settings','/login','/tenants/:id'];

// SADECE='dar + buyuk yazi,360dp' → yalniz adi eslesen olculeri kosar.
// Bir bulgu duzeltildikten sonra tam sürüşü (35 dk) beklemeden dogrulamak
// icin; CI'da kullanilmaz.
const SUZGEC = (process.env.SADECE ?? '').split(',').filter(Boolean);
const KOSULACAK = SUZGEC.length
  ? OLCULER.filter((o) => SUZGEC.some((f) => o.ad.includes(f)))
  : OLCULER;

const tarayici = await chromium.launch();
const bulgular = [];

for (const olcu of KOSULACAK) {
  for (const dil of (olcu.diller ?? DILLER)) {
    const ctx = await tarayici.newContext({
      deviceScaleFactor: olcu.dpr ?? 1,
      viewport: { width: olcu.w, height: olcu.h },
      locale: dil,
    });
    // Oturum: BFF'den cerez al.
    const api = await ctx.request.post(`${KOK}/api/auth/login`, {
      data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
    });
    if (!api.ok()) { bulgular.push([olcu.ad, dil, '-', 'LOGIN BASARISIZ']); await ctx.close(); continue; }
    await ctx.addCookies([{ name: 'ui.locale', value: dil, url: KOK }]);
    const sayfa = await ctx.newPage();
    if (olcu.kok !== 16) {
      // Kok yazi boyunu ilk boyamadan ONCE ayarla (yeniden akis olmasin).
      await sayfa.addInitScript((px) => {
        document.addEventListener('DOMContentLoaded', () => {
          document.documentElement.style.fontSize = px + 'px';
        });
      }, olcu.kok);
    }

    if (DENEY) {
      // Kasitli kusur: kokun `clientWidth`inden 40px genis, mutlak konumlu
      // (kirpan bir atasi olmasin) bir seritt. HER olcude tasmali.
      await sayfa.addInitScript(() => {
        addEventListener('DOMContentLoaded', () => {
          const d = document.createElement('div');
          d.style.cssText = 'position:absolute;top:0;left:0;height:8px;' +
            'background:red;z-index:9999';
          d.style.width = (document.documentElement.clientWidth + 40) + 'px';
          d.textContent = 'DENEY';
          document.body.appendChild(d);
        });
      });
    }

    // ---- CSS SAGLAMLIK DENETIMI (tur 59) ----
    // Bir kez yasandi: `next build` calisan sunucunun altindan `.next`i
    // degistirince stil dosyasi 400 donuyor ve sayfa STILSIZ boyaniyor. O
    // halde "tasma" olcumu tamamen anlamsizdir (her sey tasar ya da hicbir
    // kirpma gorunmez) — ama surus yine de RAPOR uretir. Bu yuzden olcumden
    // once stilin GERCEKTEN uygulandigi dogrulanir.
    {
      await sayfa.goto(KOK + '/login', { waitUntil: 'networkidle' }).catch(() => {});
      const stil = await sayfa.evaluate(() => {
        const d = document.createElement('div');
        d.className = 'overflow-hidden';
        document.body.appendChild(d);
        const ox = getComputedStyle(d).overflowX;
        d.remove();
        return ox;
      }).catch(() => 'HATA');
      if (stil !== 'hidden') {
        bulgular.push([olcu.ad, dil, '/login',
          `CSS UYGULANMADI (overflow-hidden -> ${stil}) — olcum GECERSIZ`]);
        await ctx.close();
        continue;
      }
    }

    // `/tenants/:id` calisma aninda cozulur (tur 61).
    const yollar = await tesisYollariCoz(ctx, KOK, SAYFALAR);
    for (const yol of yollar) {
      if (olcu.hemen) {
        // Yalniz DOM: veri istekleri ve CSS gecisleri surerken olc.
        await sayfa.goto(KOK + yol, { waitUntil: 'domcontentloaded' }).catch(() => {});
        await sayfa.waitForTimeout(120);
      } else {
        await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
      }
      const rapor = await sayfa.evaluate(() => {
        const kok = document.documentElement;
        const govde = document.body;
        // 1) YATAY TASMA: sayfa kendi genisliginden genis mi?
        const yatay = Math.max(kok.scrollWidth, govde.scrollWidth) - kok.clientWidth;
        // 2) TASAN OGE: viewport disina cikan gorunur ogeleri bul (yatay
        //    kaydirma KAPSAYICISI olanlar mesrudur — tablolar boyle).
        const disari = [];
        const genislik = kok.clientWidth;
        for (const el of document.querySelectorAll('body *')) {
          const r = el.getBoundingClientRect();
          if (r.width === 0 || r.height === 0) continue;
          const sag = document.dir === 'rtl' ? -r.left : r.right;
          if (sag <= genislik + 1) continue;
          // Kaydirilabilir bir ata varsa tasma DEGIL (bilincli tasarim).
          let p = el.parentElement, kaydirilir = false;
          while (p && p !== document.body) {
            const st = getComputedStyle(p);
            // `hidden`/`clip` de KIRPAR: dekoratif orb'ler boyle tutulur.
            // Ilk surumde yalniz auto|scroll bakiliyordu ve /login'deki
            // bilincli tasarim "tasma" diye raporlaniyordu (dedektor hatasi).
            if (/(auto|scroll|hidden|clip)/.test(st.overflowX)) { kaydirilir = true; break; }
            p = p.parentElement;
          }
          if (!kaydirilir) {
            disari.push(`${el.tagName.toLowerCase()}.${(el.className || '').toString().slice(0, 40)} +${Math.round(sag - genislik)}px "${(el.textContent || '').trim().slice(0, 30)}"`);
          }
        }
        return { yatay, disari: disari.slice(0, 3), lang: kok.lang, dir: kok.dir || 'ltr' };
      }).catch((e) => ({ hata: String(e) }));

      if (rapor.hata) { bulgular.push([olcu.ad, dil, yol, rapor.hata.slice(0, 60)]); continue; }
      if (rapor.lang !== dil) bulgular.push([olcu.ad, dil, yol, `lang=${rapor.lang}`]);
      if ((rapor.dir === 'rtl') !== (dil === 'ar')) bulgular.push([olcu.ad, dil, yol, `dir=${rapor.dir}`]);
      if (rapor.yatay > 1) bulgular.push([olcu.ad, dil, yol, `YATAY TASMA +${rapor.yatay}px`]);
      for (const d of rapor.disari) bulgular.push([olcu.ad, dil, yol, `TASAN: ${d}`]);
    }
    await ctx.close();
  }
}
await tarayici.close();
const kosum = KOSULACAK.reduce((t, o) => t + (o.diller ?? DILLER).length, 0) * SAYFALAR.length;
console.log(`kontrol: ${kosum} sayfa-dil-olcu`);
console.log(`BULGU: ${bulgular.length}`);
if (DENEY) {
  // Her olcu kendi kusurunu GORMUS olmali; goremeyen olcu KOR olcudur.
  const goren = new Set(bulgular.filter((b) => /TASAN|YATAY/.test(b[3])).map((b) => b[0]));
  const kor = KOSULACAK.map((o) => o.ad).filter((ad) => !goren.has(ad));
  console.log(kor.length ? `DEDEKTOR KOR OLCULER: ${kor.join(', ')}` : 'DEDEKTOR OK: her olcu kusuru gordu');
}
for (const b of bulgular.slice(0, 250)) console.log('  ' + b.join(' | '));
