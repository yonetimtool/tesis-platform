// TUR 25 — paneli DAR EKRANDA 7 dilde sur.  KULLANIM:
//   npx next build && npx next start -p 3115
//   node tools/dar-ekran-surusu.mjs            # KOK ile port degistirilir
// Cikis: bulgu sayisi + (olcu | dil | sayfa | sorun) satirlari. Mobilde (tur 24) sabit olculu
// kutu + uzun ceviri 10 px tasirmisti; web'in karsiligi YATAY TASMA:
// govde kendi genisliginden genis olur ve sayfa yana kayar.
import { chromium } from 'playwright';

const KOK = process.env.KOK ?? 'http://localhost:3115';
const DILLER = ['tr','en','ar','ru','de','fr','es'];
const OLCULER = [{ ad: '360dp', w: 360, h: 780 }, { ad: '414dp', w: 414, h: 896 }];
const SAYFALAR = ['/dashboard','/tenants','/shifts','/checkpoints','/patrol-plans','/tasks',
  '/assets','/units','/building-editor','/schematic','/dues','/reports/dues','/reports/patrols',
  '/reports/tasks','/transparency','/users','/announcements','/complaints','/notifications',
  '/integrations','/support','/audit','/settings','/login'];

const tarayici = await chromium.launch();
const bulgular = [];

for (const olcu of OLCULER) {
  for (const dil of DILLER) {
    const ctx = await tarayici.newContext({
      viewport: { width: olcu.w, height: olcu.h },
      locale: dil,
      deviceScaleFactor: 1,
    });
    // Oturum: BFF'den cerez al.
    const api = await ctx.request.post(`${KOK}/api/auth/login`, {
      data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
    });
    if (!api.ok()) { bulgular.push([olcu.ad, dil, '-', 'LOGIN BASARISIZ']); await ctx.close(); continue; }
    await ctx.addCookies([{ name: 'ui.locale', value: dil, url: KOK }]);
    const sayfa = await ctx.newPage();

    for (const yol of SAYFALAR) {
      await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
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
console.log(`kontrol: ${OLCULER.length * DILLER.length * SAYFALAR.length} sayfa-dil-olcu`);
console.log(`BULGU: ${bulgular.length}`);
for (const b of bulgular.slice(0, 40)) console.log('  ' + b.join(' | '));
