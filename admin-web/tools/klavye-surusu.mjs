// TUR 33 — paneli KLAVYEYLE sur: ODAK SIRASI ve ODAK TUZAGI.
//
// Onceki eksenler (dil / dar ekran / yazi olcegi / ekran okuyucu / koyu tema)
// hep EKRANI olctu. Klavye baska bir sey olcer: bir sayfa gorsel olarak
// kusursuz, kontrasti tam, etiketleri cevrilmis olabilir ve yine de fareyi
// kullanamayan biri icin CALISMAYABILIR. axe bunun yalnizca bir kismini
// gorur (tabindex degeri, gizli odaklanabilir oge); SIRA ve TUZAK ancak
// gercekten TAB'a basarak olculur.
//
// Olculen bes sey:
//   1. POZITIF tabindex — DOM sirasini ezer, sirayi ongorulemez yapar.
//   2. ERISILEBILIRLIK — her etkilesimli oge TAB ile ULASILABILIYOR mu?
//      (`<div onClick>` kalibi fareyle calisir, klavyeyle asla.)
//   3. TUZAK — odak bir alt kumede donup kaliyor mu (cikis yok).
//   4. ODAK GORUNURLUGU — odaklanan ogenin gorsel isareti var mi
//      (outline / box-shadow); yoksa kullanici NEREDE oldugunu bilemez.
//   5. SIRA — GORSEL sira DOM sirasindan kopmus mu. Olcum TAB'a basmadan
//      ONCE, tek seferde alinir: odaklanan oge kendini gorunume KAYDIRIR
//      (scrollIntoView), yani gezinti sirasinda alinan dikdortgenler
//      birbiriyle kiyaslanamaz — ilk olcumde kaydirma yoktur.
//      Kabuk->icerik gecisi MESRU tek geri zipmadir.
//
// DIL EKSENI: tr + ar. Klavye sirasi DOM sirasidir, dile gore degismez;
// degisen RTL'de GORSEL siradir. Bu yuzden 7 dil yerine LTR + RTL temsilcisi
// surulur (Arapcada `start/end` yerine `left/right` kullanan bir yerlesim
// sirayi tersine cevirir — asil risk budur).
//
// KULLANIM: npx next build && npx next start -p 3127
//           KOK=http://localhost:3127 node tools/klavye-surusu.mjs
import { chromium } from 'playwright';

const KOK = process.env.KOK ?? 'http://localhost:3127';
// DEDEKTOR SINAMASI (DENEY=1): sayfaya BILEREK uc hata enjekte edilir ve
// taramanin UCUNU DE yakaladigi dogrulanir. "0 bulgu" ancak tarama gercekten
// olcuyorsa bir sey ifade eder — tur 32'de ayni disiplin mobil tarafta
// `koyu_tema_detektor_test.dart` ile kurulmustu.
const DENEY = process.env.DENEY === '1';
const DILLER = DENEY ? ['tr'] : ['tr', 'ar'];
const SAYFALAR = ['/login', '/dashboard', '/tenants', '/shifts', '/checkpoints', '/patrol-plans',
  '/tasks', '/assets', '/units', '/building-editor', '/schematic', '/dues', '/reports/dues',
  '/reports/patrols', '/reports/tasks', '/transparency', '/users', '/announcements', '/complaints',
  '/notifications', '/integrations', '/support', '/audit', '/settings'];
if (DENEY) SAYFALAR.length = 2;

// TAB ust siniri SAYFAYA GORE belirlenir: odaklanabilir oge sayisi + pay.
// Sabit bir tavan (200) yanlisti — `/tenants` seed'de 251 odaklanabilir oge
// tasiyor ve tavan "TUZAK" gibi gorunuyordu. Tuzak, ogelerin SAYISINDAN
// fazla TAB'a ragmen donguye girilmemesidir.
const PAY = 25;

const tarayici = await chromium.launch();
const bulgular = [];

for (const dil of DILLER) {
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

    if (DENEY) {
      await sayfa.evaluate(() => {
        // (a) odak isaretini tamamen kaldir
        const st = document.createElement('style');
        st.textContent = '*:focus{outline:none !important;box-shadow:none !important}';
        document.head.appendChild(st);
        // (b) fare-yalniz oge
        const d = document.createElement('div');
        d.style.cssText = 'cursor:pointer;width:80px;height:20px';
        d.textContent = 'deney tikla';
        document.body.prepend(d);
        // (c) pozitif tabindex
        const b = document.createElement('button');
        b.setAttribute('tabindex', '3');
        b.textContent = 'deney tabindex';
        document.body.prepend(b);
      });
      if (yol === SAYFALAR[1]) {
        // (d) GERCEK ODAK TUZAGI — TAB'i yutan bir dugme. Odak bir daha
        // ilerlemez; hem TUZAK hem de ARDINDAKI her sey ULASILAMAZ olmali.
        await sayfa.evaluate(() => {
          const t = document.createElement('button');
          t.textContent = 'deney tuzak';
          t.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') { e.preventDefault(); t.focus(); }
          });
          document.body.prepend(t);
        });
      }
    }

    // --- 1) POZITIF tabindex + etkilesimli oge ENVANTERI ------------------
    const envanter = await sayfa.evaluate(() => {
      // Odaklanabilir sayilan ogeler (yaygin kume). `disabled` ve
      // `tabindex="-1"` bilerek disarida: ikisi de KASITLI olarak sira disi.
      const SEC = 'a[href],button,input,select,textarea,[tabindex]';
      const gorunur = (el) => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
      };
      const yon = getComputedStyle(document.documentElement).direction;
      const kimlik = (el) => {
        const metin = (el.getAttribute('aria-label') || el.textContent || el.getAttribute('placeholder') || '')
          .trim().replace(/\s+/g, ' ').slice(0, 40);
        return `${el.tagName.toLowerCase()}:${metin}`;
      };
      const pozitif = [];
      const beklenen = [];
      // DOM SIRASINDA konumlar — sira denetimi icin (kaydirma OLMADAN).
      const konumlar = [];
      for (const el of document.querySelectorAll(SEC)) {
        if (!gorunur(el)) continue;
        if (el.hasAttribute('disabled')) continue;
        const ti = el.getAttribute('tabindex');
        if (ti !== null && Number(ti) > 0) pozitif.push(kimlik(el));
        if (ti !== null && Number(ti) < 0) continue;    // kasitli sira disi
        if (el.closest('[aria-hidden="true"]')) continue;
        beklenen.push(kimlik(el));
        const r = el.getBoundingClientRect();
        konumlar.push({ ad: kimlik(el), ust: Math.round(r.top), sol: Math.round(r.left) });
      }
      // FARE-YALNIZ kalip: tiklanabilir gorunen ama odaklanamayan oge.
      const fareYalniz = [];
      for (const el of document.querySelectorAll('div,span,li,td')) {
        if (!gorunur(el)) continue;
        if (getComputedStyle(el).cursor !== 'pointer') continue;
        if (el.closest(SEC) || el.querySelector(SEC)) continue;  // zaten odaklanabilir sarmal
        if (el.getAttribute('tabindex') !== null || el.getAttribute('role')) continue;
        // `<label>` icindeki metin ETIKETTIR: tiklaninca kendi denetimini
        // etkinlestirir ve o denetim odaklanabilirdir. ("Beni hatirla"
        // span'i boyle bir YANLIS ALARM idi.)
        const etiket = el.closest('label');
        if (etiket && (etiket.control || etiket.querySelector('input,select,textarea'))) continue;
        fareYalniz.push(kimlik(el));
      }
      return {
        pozitif, konumlar, yon,
        // HAM sayi (tekillestirilmemis): TAB tavani bundan hesaplanir.
        // `beklenen` tekillestirilir (rapor icin), ama bir sayfada 80 tane
        // "Sil" dugmesi olabilir — tavani tekil sayidan hesaplamak
        // `/tenants`te yeniden "TUZAK" yanlis alarmi uretmisti.
        sayi: beklenen.length,
        beklenen: [...new Set(beklenen)],
        fareYalniz: [...new Set(fareYalniz)],
      };
    });

    for (const p of envanter.pozitif) bulgular.push([dil, yol, `POZITIF TABINDEX: ${p}`]);
    for (const f of envanter.fareYalniz.slice(0, 3)) bulgular.push([dil, yol, `FARE-YALNIZ: ${f}`]);

    // --- 2) TAB ile gercek gezinti ----------------------------------------
    // Odagi belgenin basina al: govdeye odaklan, TAB ilk odaklanabilire gider.
    await sayfa.evaluate(() => {
      document.body.setAttribute('tabindex', '-1');
      document.body.focus();
    });

    const azamiTab = Math.max(60, envanter.sayi + PAY);
    const ziyaret = [];      // sirayla odaklanan ogeler
    let ilk = null;
    let tuzak = null;
    for (let i = 0; i < azamiTab; i++) {
      await sayfa.keyboard.press('Tab');
      const o = await sayfa.evaluate(() => {
        const el = document.activeElement;
        if (!el || el === document.body) return null;
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        const metin = (el.getAttribute('aria-label') || el.textContent || el.getAttribute('placeholder') || '')
          .trim().replace(/\s+/g, ' ').slice(0, 40);
        return {
          ad: `${el.tagName.toLowerCase()}:${metin}`,
          ust: Math.round(r.top), sol: Math.round(r.left),
          // ODAK ISARETI: outline VEYA box-shadow (Tailwind `ring-*`)
          // VEYA kenarlik rengi degisimi sayilir.
          isaret: (s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0)
            || (s.boxShadow !== 'none' && s.boxShadow !== ''),
        };
      });
      if (o === null) break;                  // odak belgeden cikti (dogru)
      const imza = o.ad + o.ust + o.sol;
      // Dongu ancak ILK ogeye donunce kapanir. "Daha once gorulen HERHANGI
      // bir oge" ile kesmek YANLISTI: `<input type="date">` ic bolumleri
      // (gg/aa/yyyy) arasinda TAB ayni ogede kalir, tarama erken biter ve
      // ARDINDAKI her sey "ulasilamaz" gorunurdu.
      if (ilk === null) ilk = imza;
      else if (imza === ilk) break;
      ziyaret.push(o);
    }
    if (ziyaret.length >= azamiTab) {
      tuzak = `TUZAK: ${azamiTab} TAB (oge sayisi ${envanter.sayi} + pay) sonrasi dongu kapanmadi`;
    } else if (ziyaret.length < envanter.sayi / 2) {
      // Dongu kapandi AMA ogelerin yarisina bile ugramadan: odak bir ALT
      // KUMEDE hapsolmus demektir. (Ilk dedektor sinamasinda TAB'i yutan
      // dugme tam bunu yapti ve "dongu ilk ogeye dondu" diye TEMIZ
      // gorunuyordu — tuzagin en yaygin bicimi budur.)
      tuzak = `TUZAK: odak ${ziyaret.length} ogede kapandi, sayfada ${envanter.sayi} odaklanabilir oge var`;
    }
    if (tuzak) bulgular.push([dil, yol, tuzak]);

    // 2a) ULASILAMAYAN etkilesimli ogeler
    const ulasilan = new Set(ziyaret.map((z) => z.ad));
    const ulasilmayan = envanter.beklenen.filter((b) => !ulasilan.has(b));
    for (const u of ulasilmayan.slice(0, 3)) {
      bulgular.push([dil, yol, `ULASILAMAZ: ${u}`]);
    }

    // 2b) ODAK ISARETI olmayanlar
    const isaretsiz = [...new Map(ziyaret.filter((z) => !z.isaret).map((z) => [z.ad, z])).values()];
    for (const z of isaretsiz.slice(0, 3)) {
      bulgular.push([dil, yol, `ODAK ISARETI YOK: ${z.ad}`]);
    }

    // 2c) SIRA: DOM sirasindaki ogeler GORSEL olarak da ilerliyor mu?
    // Olcum TAB'dan bagimsizdir (kaydirma bulastirmasin diye). Kabuk→icerik
    // gecisi tek mesru geri ziplamadir; ayni satirdaki oynamalar (40 px)
    // sayilmaz.
    // IZGARA/SUTUN ISTISNASI: yukari zipma, oge SATIR EKSENINDE ilerlemisse
    // (LTR'de saga, RTL'de sola) dogru okuma sirasidir — yan yana kartlar,
    // "solda icerik / sagda eylemler" duzeni, cok sutunlu izgara. Bunu
    // ayirt etmeyen tarama `/building-editor` ve `/complaints`te YANLIS
    // ALARM veriyordu.
    const ileri = envanter.yon === 'rtl'
      ? (a, b) => b.sol < a.sol - 40
      : (a, b) => b.sol > a.sol + 40;
    const kopuk = (a, b) => b.ust < a.ust - 40 && !ileri(a, b);
    let geri = 0;
    const k = envanter.konumlar;
    for (let i = 1; i < k.length; i++) {
      if (kopuk(k[i - 1], k[i])) geri++;
    }
    if (geri > 1) {
      const nerede = [];
      for (let i = 1; i < k.length; i++) {
        if (kopuk(k[i - 1], k[i])) nerede.push(`${k[i - 1].ad}(${k[i - 1].ust})→${k[i].ad}(${k[i].ust})`);
      }
      bulgular.push([dil, yol,
        `SIRA: ${geri} kez yukari geri zipladi — ${nerede.slice(0, 3).join(' , ')}`]);
    }
  }
  await ctx.close();
}
await tarayici.close();

console.log(`kontrol: ${DILLER.length * SAYFALAR.length} sayfa-dil`);
console.log(`BULGU: ${bulgular.length}`);
const ozet = {};
for (const [, , n] of bulgular) { const k = n.split(':')[0]; ozet[k] = (ozet[k] ?? 0) + 1; }
for (const [k, v] of Object.entries(ozet).sort((a, b) => b[1] - a[1])) console.log(`  ${v}x ${k}`);
if (DENEY) {
  const siniflar = ['POZITIF TABINDEX', 'FARE-YALNIZ', 'ODAK ISARETI YOK', 'TUZAK', 'ULASILAMAZ'];
  let eksik = 0;
  for (const c of siniflar) {
    const n = bulgular.filter(([, , m]) => m.startsWith(c)).length;
    console.log(`DEDEKTOR ${c}: ${n} bulgu ${n > 0 ? 'OK' : '*** YAKALAMADI ***'}`);
    if (n === 0) eksik++;
  }
  if (eksik > 0) process.exitCode = 1;
}
console.log('--- ornekler:');
for (const b of bulgular.slice(0, 20)) console.log('  ' + b.join(' | '));
