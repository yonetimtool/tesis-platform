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
  // (P245) `/olaylar` ROL olarak yalniz `admin`e acik ama TESIS
  // yuzeyinde yasiyor (`lib/yuzey.ts`): panel yuzeyinde acilinca
  // `/tenants`e yonleniyor. Ayni hesap, `app.*` konagindan.
  "admin-tesis": {
    kimlik: "admin@acme.com",
    parola: "Admin123!",
    taban: "http://app.localhost:3000",
  },
};

async function girisYap(sayfa, rol) {
  const h = HESAPLAR[rol];
  await sayfa.goto(`${h.taban}/login`, { waitUntil: "networkidle" });
  /**
   * HIDRASYON BEKLENIR — ve beklemek YETMEZSE TEKRAR DENENIR.
   *
   * OLCULEN KUSUR: form JS hazir olmadan gonderilince tarayici NATIVE
   * gonderim yapiyor ve sayfa `/login`de kaliyordu (sekiz rotanin
   * yedisi bu yuzden zaman asimina dustu). "Bir sure bekle" cozumu yine
   * bir TAHMINDIR; onun yerine SONUC olculur: giris olduysa adres
   * degisir, olmadiysa yeniden denenir.
   */
  for (let deneme = 1; deneme <= 4; deneme += 1) {
    await sayfa.waitForTimeout(deneme * 1200);
    await sayfa.fill("#yz-kimlik", h.kimlik);
    await sayfa.fill("#yz-parola", h.parola);
    await sayfa.click('button[type="submit"]');
    try {
      await sayfa.waitForURL((u) => !u.pathname.includes("/login"), { timeout: 12000 });
      return;
    } catch {
      // Native gonderim sayfayi yeniden yukleyebilir; alanlar bosalir.
      await sayfa.goto(`${h.taban}/login`, { waitUntil: "networkidle" }).catch(() => {});
    }
  }
  throw new Error("giris yapilamadi");
}

/**
 * (P245) TEK OTURUM, COK ROTA.
 *
 * Ilk surum her rota icin yeniden giris yapiyordu; sekiz ardisik giris
 * sonrasinda hepsi ZAMAN ASIMINA dustu (giris ucu ard arda denemeleri
 * sinirliyor — dogru davranis). Oturum bir kez acilir ve tum rotalar
 * ayni baglamda gezilir: hem hizli hem de gercek kullanicinin yaptigi
 * sey bu.
 */
async function cekHepsi({ rol, tema, mod, rotalar }) {
  TABAN = HESAPLAR[rol].taban;
  const tarayici = await chromium.launch();
  const baglam = await tarayici.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
    colorScheme: tema === "koyu" ? "dark" : "light",
    locale: "tr-TR",
    /**
     * HAREKET AZALTILDI — KAPRIS DEGIL, OLCUM GEREGI.
     *
     * `VeriTablosu` satirlari KADEMELI beliriyor (`siraGecikmesi`).
     * Goruntu o kademe bitmeden alininca tablo YARIM cikiyordu: 27
     * kayitli listede yalniz iki satir doluydu, gerisi bos serit
     * (olculdu: /units).
     *
     * Depo `reducedMotion`a ZATEN saygi duyuyor (`hareketVar`), yani
     * bu mod uydurma bir durum degil, urunun desteklenen bir hali.
     */
    reducedMotion: "reduce",
  });
  await baglam.addCookies([
    { name: "tema", value: tema === "koyu" ? "dark" : "light", url: TABAN },
    { name: "gorunum", value: mod, url: TABAN },
  ]);
  // Kurulum hatirlaticisi SAYFA YUKLENMEDEN kapatilir (hidrasyon
  // bitmeden tiklamak modali geri getiriyordu).
  await baglam.addInitScript(() => {
    try {
      localStorage.setItem("yonetio.kurulum.kapatildi", "1");
    } catch {}
  });
  const sayfa = await baglam.newPage();
  try {
    await girisYap(sayfa, rol);
    // Ilk-giris turunun isareti SUNUCUDA (`app_user.tur_goruldu_at`).
    await sayfa.request.post(`${TABAN}/api/me/tur-goruldu`).catch(() => {});

    for (const rota of rotalar) {
      const ad =
        rota === "/dashboard"
          ? `ozet-${rol}-${tema}-${mod}`
          : `${rota.replace(/\//g, "")}-${rol}-${tema}`;
      try {
        await sayfa.goto(`${TABAN}${rota}`, { waitUntil: "networkidle" });
        // SABIT BEKLEME YETMEZ — ICERIK BEKLENIR. Sabit sure, derleme +
        // SWR + WebGL suresini TAHMIN etmektir ve goruntu iki kez YARIM
        // cikmisti.
        await sayfa
          .waitForFunction(
            (ozetMi) => {
              const g = document.body.innerText;
              if (!ozetMi) {
                // ICERIK VAR **ve** ISKELET YOK.
                //
                // Yalniz "metin uzunlugu" bakmak yetmiyordu: sayfa
                // basligi hemen cizilir, tablo hala iskelettir ve
                // goruntu YARIM cikar (olculdu: /patrol-plans).
                // Iskelet parcasi `motion-safe:animate-pulse` tasir.
                const iskelet = document.querySelectorAll(
                  '[class*="animate-pulse"]',
                ).length;
                return g.length > 200 && iskelet === 0;
              }
              return g.includes("Toplam daire") && !g.includes("Henüz duyuru yok");
            },
            rota === "/dashboard",
            { timeout: 45000 },
          )
          .catch(() => {});
        if (await sayfa.locator("canvas").count()) {
          await sayfa
            .locator("canvas")
            .first()
            .waitFor({ state: "visible", timeout: 15000 })
            .catch(() => {});
        }
        await sayfa.waitForTimeout(2500);
        const yol = `${CIKTI}/${ad}.png`;
        // `animations: "disabled"` CSS gecislerini de dondurur.
        await sayfa.screenshot({ path: yol, fullPage: true, animations: "disabled" });
        console.log("OK  ", yol);
      } catch (e) {
        console.log("HATA", ad, String(e).split("\n")[0]);
      }
    }
  } catch (e) {
    console.log("GIRIS HATASI", rol, String(e).split("\n")[0]);
  } finally {
    await tarayici.close();
  }
}

const rol = process.argv[2] ?? "yonetici";
const tema = process.argv[3] ?? "acik";
const mod = process.env.YZ_MOD ?? "standart";

// `YZ_ROTALAR=/kameralar,/olaylar` -> her rota icin ayri goruntu.
const rotalar = (process.env.YZ_ROTALAR ?? "/dashboard").split(",").filter(Boolean);
await cekHepsi({ rol, tema, mod, rotalar });
