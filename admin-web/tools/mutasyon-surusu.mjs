// TUR 54 — MUTASYON AKISLARINI sur (panelde YAZMA yolu).
//
// Tur 49 envanterinin C maddesi: butun panel surusleri YALNIZ OKUMA yapiyordu
// (`rapor-surusu` ve `foto-surusu` birer dugmeye basiyor, gerisi GET). Yani
// kullanicinin en cok dokundugu yol — kaydet/sil ve sonrasi — hic olculmedi.
//
// Bu arac ISTEKLERI KESER (route interception): urun verisi DEGISMEZ, yalniz
// panelin YAZMA yanitina verdigi tepki olculur. Dort kip:
//   * `basari`   — 200/201 doner: basari bildirimi cikiyor mu, form kapaniyor mu
//   * `dogrulama`— 422 alan hatalari: formda GORUNUYOR mu (sessizce yutulmasin)
//   * `catisma`  — 409: anlasilir bir mesaj mi
//   * `oturum`   — 401 MID-SESSION: /login'e YONLENDIRILMELI (kullanici
//                  bilinmeyen bir hatayla ekranda kalmamali)
//
// KULLANIM: npx next build && npx next start -p 3150
//           KOK=http://localhost:3150 node tools/mutasyon-surusu.mjs
import { chromium } from 'playwright';

const KOK = process.env.KOK ?? 'http://localhost:3150';
const DILLER = (process.env.DILLER ?? 'tr,en,de').split(',');
const KIPLER = (process.env.KIPLER ?? 'basari,dogrulama,catisma,oturum').split(',');

// Formu olan sayfalar: her biri "yeni kayit" formunu acar ve gonderir.
const SAYFALAR = [
  { yol: '/units', ad: 'daire' },
  { yol: '/checkpoints', ad: 'nokta' },
  { yol: '/shifts', ad: 'vardiya' },
  { yol: '/patrol-plans', ad: 'devriye plani' },
  { yol: '/announcements', ad: 'duyuru' },
  { yol: '/users', ad: 'kullanici' },
];

// DEDEKTOR SINAMASI (DENEY=1): hata/bildirim kutulari CSS ile GIZLENIR ve
// taramanin "sessiz hata" / "basari bildirimi yok" dediginin dogrulanmasi.
// "0 bulgu" ancak tarama gercekten olcuyorsa bir sey ifade eder.
const DENEY = process.env.DENEY === '1';

const TR = /[ğışĞİŞ]/;
const TEKNIK = /Failed to fetch|TypeError|\bundefined\b|\[object Object\]|SyntaxError|NetworkError/;

const tarayici = await chromium.launch();
const bulgular = [];
let olcum = 0;

for (const kip of KIPLER)
  for (const dil of DILLER) {
    const ctx = await tarayici.newContext({
      viewport: { width: 1280, height: 900 },
      locale: dil,
      reducedMotion: 'reduce',
    });
    const api = await ctx.request.post(`${KOK}/api/auth/login`, {
      data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
    });
    if (!api.ok()) { bulgular.push([`${kip}/${dil}`, '-', 'LOGIN BASARISIZ']); await ctx.close(); continue; }
    await ctx.addCookies([{ name: 'ui.locale', value: dil, url: KOK }]);
    const sayfa = await ctx.newPage();

    // YAZMA isteklerini kes — okuma (GET) dokunulmaz, urun verisi degismez.
    // `yazmaSayaci`: gonderim GERCEKTEN yazma istegi uretti mi? Uretmediyse
    // olcum ANLAMSIZDIR (form GET arama formu olabilir) — tur 39/45'in
    // "bos kosan surus" dersi.
    let yazmaSayaci = 0;
    await sayfa.route('**/api/**', async (route) => {
      const istek = route.request();
      if (istek.method() === 'GET' || istek.url().includes('/api/auth/')) {
        return route.continue();
      }
      yazmaSayaci++;
      if (kip === 'basari') {
        return route.fulfill({
          status: 201,
          contentType: 'application/json',
          body: JSON.stringify({ id: '00000000-0000-0000-0000-000000000001' }),
        });
      }
      if (kip === 'dogrulama') {
        return route.fulfill({
          status: 422,
          contentType: 'application/json',
          body: JSON.stringify({
            error: { code: 'validation_error', message: 'Alan degeri gecersiz (surus).' },
          }),
        });
      }
      if (kip === 'catisma') {
        return route.fulfill({
          status: 409,
          contentType: 'application/json',
          body: JSON.stringify({
            error: { code: 'conflict', message: 'Kayit zaten var (surus).' },
          }),
        });
      }
      // oturum: 401 — panel /login'e yonlendirmeli
      return route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({ error: { code: 'unauthorized', message: 'Oturum bitti.' } }),
      });
    });

    for (const { yol, ad } of SAYFALAR) {
      await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
      await sayfa.waitForTimeout(400);

      // KAYIT FORMUNU BUL. Sayfada zaten bir form olabilir ama o ARAMA/FILTRE
      // formudur (GET) — ona gondermek hicbir yazma istegi uretmez ve olcum
      // sessizce bos kalir (ilk kosumda `/users` tam bunu yapip YANLIS bir
      // "401'de yonlendirme yok" bulgusu uretti).
      //
      // Cozum: sayfa basligindaki eylem dugmesine (sag ust "Yeni ...") basip
      // form sayisinin ARTMASINI bekle; artmiyorsa var olan formu kullan.
      const formSayisi = async () => sayfa.locator('form').count();
      const once = await formSayisi();
      // ACICI: YALNIZ `main` icindeki, form DISINDA, submit OLMAYAN dugmeler.
      // Kabuk (`aside`/`nav`/`header`) dugmelerine dokunulmaz — ilk denemede
      // oraya basip "Cikis yap"i tetikledim ve sayfa kapandi.
      const acicilar = sayfa.locator(
        'main button:not([type="submit"]):not(form button)',
      );
      const sayi = Math.min(await acicilar.count(), 3);
      for (let i = 0; i < sayi; i++) {
        await acicilar.nth(i).click().catch(() => {});
        await sayfa.waitForTimeout(400);
        if ((await formSayisi()) > once) break;
      }
      let form = (await formSayisi()) > once
          ? sayfa.locator('form').last()
          : sayfa.locator('form').last();
      if (!(await form.count())) {
        bulgular.push([`${kip}/${dil}`, yol, `FORM YOK: "${ad}" formu acilamadi`]);
        continue;
      }

      // Zorunlu alanlari TIPE UYGUN doldur. Ilk denemede her alana
      // "SurusDeger1" yaziyordum; telefon/e-posta alanlarinda ISTEMCI
      // DOGRULAMASI gonderimi engelliyor ve hicbir yazma istegi gitmiyordu —
      // olcum sessizce bos kaliyordu.
      const alanlar = form.locator(
        'input:not([type=hidden]):not([type=checkbox]), textarea',
      );
      const n = await alanlar.count();
      for (let i = 0; i < n; i++) {
        const a = alanlar.nth(i);
        const tip = (await a.getAttribute('type')) ?? 'text';
        const ad2 = ((await a.getAttribute('name')) ?? '') +
          ((await a.getAttribute('id')) ?? '');
        if (['date', 'datetime-local', 'time', 'file'].includes(tip)) continue;
        let deger = 'SurusDeger1';
        if (tip === 'number') deger = '1';
        else if (tip === 'tel' || /telefon|phone/i.test(ad2)) deger = '+905491234567';
        else if (tip === 'email' || /email|posta/i.test(ad2)) deger = 'surus@ornek.com';
        else if (tip === 'password') deger = 'SurusParola1!';
        await a.fill(deger).catch(() => {});
      }
      // `select` alanlari: ilk GECERLI secenek (bos deger zorunluysa engeller).
      const secmeler = form.locator('select');
      const sn = await secmeler.count();
      for (let i = 0; i < sn; i++) {
        const secenekler = await secmeler.nth(i).locator('option').all();
        for (const o of secenekler) {
          const v = await o.getAttribute('value');
          if (v) { await secmeler.nth(i).selectOption(v).catch(() => {}); break; }
        }
      }
      const gonder = form.locator('button[type="submit"]').first();
      if (!(await gonder.count())) {
        bulgular.push([`${kip}/${dil}`, yol, 'GONDER DUGMESI YOK']);
        continue;
      }
      const oncekiYazma = yazmaSayaci;
      await gonder.click().catch(() => {});
      await sayfa.waitForTimeout(1200);
      if (yazmaSayaci === oncekiYazma) {
        // Yazma istegi HIC gitmedi: form bir GET/arama formuydu ya da
        // istemci-tarafi dogrulama engelledi. Olcum yapilmaz.
        bulgular.push([`${kip}/${dil}`, yol,
          `YAZMA ISTEGI GITMEDI: "${ad}" formu gonderildi ama POST/PATCH yok`]);
        continue;
      }
      olcum++;

      if (DENEY) {
        // Uyari/bildirim dugumlerini OLCUMDEN HEMEN ONCE kaldir. (Ilk denemede
        // bunu CSS ile gizlemistim; `shadow-lift` sinifini FORM PANELI de
        // kullaniyor, dolayisiyla formu da gizleyip gonderimi engelledim ve
        // deney kendi kendini bozdu.)
        await sayfa.evaluate(() => {
          document
            .querySelectorAll('[role="alert"],[role="status"],.text-red-700,'
              + '.text-red-600,[class*="bg-red"]')
            .forEach((e) => e.remove());
          document.querySelectorAll('[class*="shadow-lift"]').forEach((e) => {
            if (!e.querySelector('form')) e.remove();
          });
        }).catch(() => {});
      }

      const d = await sayfa.evaluate(() => ({
        url: location.pathname,
        metin: (document.querySelector('main') ?? document.body).innerText
          .replace(/\s+/g, ' ').trim(),
        uyari: document.querySelectorAll(
          '[role="alert"], [role="status"], .text-red-700, .text-red-600, [class*="bg-red"]',
        ).length,
        toast: document.querySelectorAll('[class*="shadow-lift"]').length,
      }));

      if (kip === 'oturum') {
        // 401: /login'e yonlendirme BEKLENIR.
        if (!d.url.startsWith('/login')) {
          bulgular.push([`${kip}/${dil}`, yol,
            `401'DE YONLENDIRME YOK: hala ${d.url} — son="${d.metin.slice(-90)}"`]);
        }
      } else if (kip === 'basari') {
        if (d.toast === 0 && d.uyari === 0) {
          bulgular.push([`${kip}/${dil}`, yol,
            `BASARI GERI BILDIRIMI YOK: son="${d.metin.slice(-90)}"`]);
        }
      } else if (d.uyari === 0) {
        // 422/409: hata GORUNMELI.
        bulgular.push([`${kip}/${dil}`, yol,
          `SESSIZ ${kip.toUpperCase()}: uyari yok — son="${d.metin.slice(-90)}"`]);
      }

      if (TEKNIK.test(d.metin)) {
        bulgular.push([`${kip}/${dil}`, yol,
          `TEKNIK METIN: "${d.metin.match(TEKNIK)[0]}" kullaniciya gosteriliyor`]);
      }
      if (dil !== 'tr' && TR.test(d.metin)) {
        const kelime = d.metin.split(' ').find((w) => TR.test(w) && w.length > 3);
        // SEED/TENANT VERISI cevrilmez — arayuz metniyle karistirilmamali
        // (mobil `surusVerisi`, panel `VERI` allowlist'i emsali). "Vardiyası"
        // shift ADIDIR ("Sabah Vardiyası"); ilk kosumda 12 yanlis alarm
        // uretti.
        const VERI = /Surus|surus|Acme|Demo|Otopark|Havuz|Kapı|Bariyer|Vardiyası|devriyesi|Şikayet|Sızıntı|sızıntı|müzik|Bahçe|kırık/;
        if (kelime && !VERI.test(kelime)) {
          bulgular.push([`${kip}/${dil}`, yol, `TR SIZINTI: ${kelime}`]);
        }
      }
    }
    await ctx.close();
  }
await tarayici.close();

console.log(`kontrol: ${KIPLER.length * DILLER.length * SAYFALAR.length} sayfa-dil-kip, ${olcum} gonderim`);
console.log(`BULGU: ${bulgular.length}`);
if (DENEY) {
  const bekleyen = ['SESSIZ', 'BASARI GERI BILDIRIMI YOK'];
  let eksik = 0;
  for (const c of bekleyen) {
    const n = bulgular.filter(([, , m]) => m.includes(c)).length;
    console.log(`DEDEKTOR ${c}: ${n} bulgu ${n > 0 ? 'OK' : '*** YAKALAMADI ***'}`);
    if (n === 0) eksik++;
  }
  if (eksik > 0) process.exitCode = 1;
}
const ozet = {};
for (const [, , n] of bulgular) { const k = n.split(':')[0].slice(0, 45); ozet[k] = (ozet[k] ?? 0) + 1; }
for (const [k, v] of Object.entries(ozet).sort((a, b) => b[1] - a[1])) console.log(`  ${v}x ${k}`);
for (const kip of KIPLER) {
  const t = bulgular.filter((b) => b[0].startsWith(kip + '/'));
  console.log(`--- ${kip} (${t.length}):`);
  for (const b of t.slice(0, 8)) console.log('  ' + b.join(' | '));
}
