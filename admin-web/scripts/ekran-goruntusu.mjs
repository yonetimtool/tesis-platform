/**
 * (P245) GORSEL DOGRULAMA — gercek Chromium ile ekran goruntusu.
 *
 * NEDEN VAR: jsdom YERLESIM HESAPLAMAZ. On asama boyunca testler
 * yesilken sayfanin referansa benzemedigi ancak kullanici bakinca
 * anlasildi. Bu betik o dongunun aracidir: degistir -> goruntule ->
 * karsilastir.
 *
 * Kullanim:  node scripts/ekran-goruntusu.mjs [rol] [tema] [mod]
 */
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

// TESIS YUZEYI icin `app.` alt alani sart: `konakYuzeyi()` ILK DNS
// ETIKETINE bakar ve `localhost` PLATFORM (yalniz admin) sayilir —
// yonetici hesabi orada 403 alir. Tarayici `*.localhost`u 127.0.0.1e
// cozer, ek yapilandirma gerekmez.
let TABAN = process.env.YZ_TABAN ?? "http://app.localhost:3000";
const CIKTI = resolve(process.argv[4] ?? "../docs/P245");
mkdirSync(CIKTI, { recursive: true });

/**
 * (P245) WEB'E GIREBILEN ROLLER — OLCULDU.
 *
 * Brief "sakin, guvenlik, yonetici" icin ekran goruntusu istiyordu.
 * OLCUM: `security` ve `resident` hesaplari web girisinde 403 aliyor —
 * "Bu hesap turu Yonetiyor mobil uygulamasinda calisir" (P129 karari).
 * Yani o iki rolun WEB OZET SAYFASI YOKTUR; goruntusu de alinamaz.
 *
 * Web'de panoyu goren uc rol sunlar:
 *   yonetici — tesis yuzeyi (`app.*`), mali yetkili
 *   denetci  — tesis yuzeyi, SALT OKUMA
 *   admin    — platform yuzeyi (`panel.*`), denetim kaydini da gorur
 */
const HESAPLAR = {
  yonetici: { kimlik: "yonetici@acme.com", parola: "Yonetici123!", taban: "http://app.localhost:3000" },
  denetci: { kimlik: "denetci@acme.com", parola: "Denetci123!", taban: "http://app.localhost:3000" },
  admin: { kimlik: "admin@acme.com", parola: "Admin123!", taban: "http://localhost:3000" },
};

async function girisYap(sayfa, rol) {
  const h = HESAPLAR[rol];
  await sayfa.goto(`${h.taban}/login`, { waitUntil: "networkidle" });
  await sayfa.fill("#yz-kimlik", h.kimlik);
  await sayfa.fill("#yz-parola", h.parola);
  await sayfa.click('button[type="submit"]');
  await sayfa.waitForURL((u) => !u.pathname.includes("/login"), { timeout: 45000 });
}

async function cek({ rol, tema, mod, ad }) {
  TABAN = HESAPLAR[rol].taban;
  const tarayici = await chromium.launch();
  const baglam = await tarayici.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
    colorScheme: tema === "koyu" ? "dark" : "light",
    locale: "tr-TR",
  });
  const sayfa = await baglam.newPage();
  try {
    await girisYap(sayfa, rol);
    // TEMA ve GORUNUM CEREZLE tasinir (`lib/tema.ts`, `lib/gorunum.ts`) —
    // SSR ilk karede onu okur, boylece titreme olmaz. `localStorage`a
    // yazmak yanlis katmandi.
    await baglam.addCookies([
      { name: "tema", value: tema === "koyu" ? "dark" : "light", url: TABAN },
      { name: "gorunum", value: mod, url: TABAN },
    ]);
    // ILK GIRIS TURU (P243 §6) ekrani kapatir: goruntu onun altinda
    // kalirdi. Turu "gorulmus" isaretlemek, gercek kullanicinin ikinci
    // girisindeki durumu vermek demektir.
    await sayfa.goto(`${TABAN}/dashboard`, { waitUntil: "networkidle" });
    // KURULUM HATIRLATICISI `localStorage` ile kapanir; isareti SAYFA
    // YUKLENMEDEN once yaziyoruz. Tiklamayla kapatmak, hidrasyon
    // tamamlanmadan once tiklama riski tasiyor ve modal geri geliyordu.
    await sayfa.addInitScript(() => {
      try {
        localStorage.setItem("yonetio.kurulum.kapatildi", "1");
      } catch {}
    });
    // Turu SUNUCUDA gorulmus isaretle: isaret `app_user.tur_goruldu_at`
    // (goc 0148) ve dugmeye tiklamak ayni ucu cagirir. Dogrudan cagirmak
    // hem daha guvenilir hem de gercek kullanicinin IKINCI girisindeki
    // durumu verir.
    await sayfa.request.post(`${TABAN}/api/me/tur-goruldu`).catch(() => {});
    await sayfa.reload({ waitUntil: "networkidle" });


    // ISINMA TURU — `next dev` ROTAYI TALEP UZERINE DERLER.
    //
    // OLCULDU: ilk ekran goruntusunde mali kartlar ve tahsilat halkasi
    // BOS cikti; sebep veri degil, DERLEME GECIKMESIYDI.
    await sayfa.waitForTimeout(2500);
    await sayfa.reload({ waitUntil: "networkidle" });

    // SABIT BEKLEME YETMEZ — VERIYE BAGLI KOSUL BEKLENIR.
    //
    // Ikinci olcumde sayfa YARIM yakalandi: iskeletler, "Henuz duyuru
    // yok", bos maket. Sabit bir sure, derleme + SWR + WebGL'in ne kadar
    // surecegini TAHMIN etmektir; goruntu de o tahminin dogru olup
    // olmadigina gore degisir. Onun yerine gorunmesi GEREKEN seyler
    // beklenir.
    await sayfa
      .locator('[data-test="pano-kahraman"]')
      .waitFor({ state: "visible", timeout: 30000 })
      .catch(() => {});
    // ISKELET YOKLUGU YETMEZ — ICERIK VARLIGI BEKLENIR.
    //
    // `.animate-pulse` sayisi, iskeletler HENUZ MONTE EDILMEDEN once de
    // sifirdir; o kosul "yuklendi" degil "daha baslamadi" anlamina da
    // gelebiliyordu ve goruntu yine yarim cikti. Beklenen sey artik
    // VERININ KENDISI: KPI seridinde kart var mi.
    await sayfa
      .waitForFunction(
        () => {
          const g = document.body.innerText;
          // KPI seridi `building-map` gelince cizilir; duyuru karti da
          // veri gelince bos durumdan cikar.
          return g.includes("Toplam daire") && !g.includes("Henüz duyuru yok");
        },
        { timeout: 45000 },
      )
      .catch(() => {});
    // 3B sahne WebGL ile cizilir; tuval gorununce kare hazirdir.
    if (await sayfa.locator("canvas").count()) {
      await sayfa.locator("canvas").first().waitFor({ state: "visible", timeout: 20000 }).catch(() => {});
    }
    await sayfa.waitForTimeout(3500);
    const yol = `${CIKTI}/${ad}.png`;
    await sayfa.screenshot({ path: yol, fullPage: true });
    console.log("OK  ", yol);
  } catch (e) {
    console.log("HATA", ad, String(e).split("\n")[0]);
  } finally {
    await tarayici.close();
  }
}

const rol = process.argv[2] ?? "yonetici";
const tema = process.argv[3] ?? "acik";
const mod = process.env.YZ_MOD ?? "standart";
await cek({ rol, tema, mod, ad: `ozet-${rol}-${tema}-${mod}` });
