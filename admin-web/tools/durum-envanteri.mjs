// TUR 36 — DURUM ENVANTERI: hangi sayfalar hangi DURUMDA surulmus?
//
// Suruslerin hepsi "sayfa X'te bulgu yok" der. Ama bir sayfa BOS listeyle
// cizildiyse, o sayfanin satir/kart/rozet/eylem kodlarina hic ugranmamistir
// ve "temiz" raporu o kod icin HICBIR SEY soylemez. Tur 34/35'te ayni sinif
// kor nokta (fotografli veri) urun hatasi cikardi.
//
// Bu arac urun kodunu DEGISTIRMEZ; yalniz her sayfanin CANLI seed verisiyle
// hangi durumda ciziledigini sayar:
//   * satir/kart sayisi (tablo satiri, liste ogesi, kart)
//   * bos-durum metni gorunuyor mu (EmptyState)
//   * hata kutusu var mi
//   * etkilesimli oge sayisi (dugme/baglanti/alan)
//
// KULLANIM: KOK=http://localhost:3131 node tools/durum-envanteri.mjs
import { chromium } from 'playwright';

const KOK = process.env.KOK ?? 'http://localhost:3131';
// DEDEKTOR SINAMASI (DENEY=1) — TUR 62: veri ogeleri olcumden hemen once
// DOM'dan silinir; "VERISIZ SURULEN" listesi TUM sayfalari icermeli. Icermezse
// sayim koru demektir.
const DENEY = process.env.DENEY === '1';
const SAYFALAR = ['/dashboard', '/tenants', '/shifts', '/checkpoints', '/patrol-plans',
  '/tasks', '/assets', '/units', '/building-editor', '/schematic', '/dues', '/reports/dues',
  '/reports/patrols', '/reports/tasks', '/transparency', '/users', '/announcements',
  '/complaints', '/notifications', '/integrations', '/support', '/audit', '/settings'];

const tarayici = await chromium.launch();
const ctx = await tarayici.newContext({ viewport: { width: 1440, height: 1000 }, locale: 'tr' });
await ctx.request.post(`${KOK}/api/auth/login`, {
  data: { tenant_slug: 'acme-plaza', email: 'admin@acme.com', password: 'Admin123!' },
});
await ctx.addCookies([{ name: 'ui.locale', value: 'tr', url: KOK }]);
const sayfa = await ctx.newPage();

const satirlar = [];
for (const yol of SAYFALAR) {
  await sayfa.goto(KOK + yol, { waitUntil: 'networkidle' }).catch(() => {});
  await sayfa.waitForTimeout(700);
  if (DENEY) {
    await sayfa.evaluate(() => {
      for (const el of document.querySelectorAll('tbody tr, li, article')) {
        el.remove();
      }
    });
  }
  const d = await sayfa.evaluate(() => {
    const govde = document.querySelector('main') ?? document.body;
    const metin = govde.innerText.replace(/\s+/g, ' ');
    return {
      satir: govde.querySelectorAll('tbody tr').length,
      kart: govde.querySelectorAll('article, [class*="rounded-2xl"], [class*="shadow-lift"]').length,
      // OGE = kullanici VERISINI tasiyan birim: tablo satiri + liste ogesi +
      // article. TUR 62 DUZELTMESI: "verisiz" karari `satir === 0 && kart <= 2`
      // idi ve KART kullanan sayfalari yanlis sinifliyordu — `/announcements`
      // sayfasi tam iki gercek duyuru karti tasiyor ve arac onu "verisiz"
      // listesine koyuyordu. Kart sayisi sayfa iskeletini de (form paneli,
      // filtre kutusu) sayar; `li`/`article` saymaz.
      oge: govde.querySelectorAll('tbody tr, li, article').length,
      // Bos durum: `EmptyState` bileseni her zaman bir ikon kutusu + baslik
      // cizer; metin esleme yerine YAPISAL isaret kullanilir (dile bagimli
      // olmasin diye).
      bos: !!govde.querySelector('[data-bos-durum], .empty-state')
        || /kayıt yok|henüz|bulunamadı/i.test(metin),
      hata: /hata|başarısız/i.test(metin),
      etkilesim: govde.querySelectorAll('a[href],button,input,select,textarea').length,
      uzunluk: metin.length,
    };
  });
  satirlar.push({ yol, ...d });
}
await tarayici.close();

const bicim = (s) => `${s.yol.padEnd(18)} satir=${String(s.satir).padStart(3)} kart=${String(s.kart).padStart(3)}`
  + ` oge=${String(s.oge).padStart(3)}`
  + ` etkilesim=${String(s.etkilesim).padStart(3)} metin=${String(s.uzunluk).padStart(5)}`
  + `${s.bos ? '  [BOS DURUM]' : ''}${s.hata ? '  [HATA METNI]' : ''}`;

console.log('--- TUM SAYFALAR');
for (const s of satirlar) console.log(bicim(s));

// VERISIZ surulen sayfalar: ne tablo satiri ne kart var.
const verisiz = satirlar.filter((s) => s.oge === 0);
if (DENEY) {
  const tam = verisiz.length === satirlar.length;
  console.log(`DEDEKTOR oge sayaci: ${tam ? 'OK' : 'KOR'} `
    + `(${verisiz.length}/${satirlar.length} verisiz gorundu)`);
}
console.log(`\n--- VERISIZ SURULEN (${verisiz.length}/${satirlar.length}):`);
// DURUST OKUMA UYARISI (tur 62): `oge` sayaci tablo satiri/`li`/`article`
// sayar. Kendi yerlesimini cizen sayfalar (bina duzenleme blok kartlari,
// sematik izgara, seffaflik ozet kartlari) ve FORM GONDERIMI gerektiren rapor
// sayfalari bu sayacta 0 gorunur ama VERISIZ DEGILDIR. Liste bir ADAY
// listesidir; her satir elle dogrulanmali.
console.log('    (not: /building-editor, /schematic, /transparency kendi'
  + ' yerlesimini cizer; /reports/* form gonderimi ister — bunlar sayacta 0'
  + ' gorunur, verisiz demek DEGIL)');
for (const s of verisiz) console.log('  ' + bicim(s));
