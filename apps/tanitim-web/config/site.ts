// ==========================================================================
// (P177) SITE SABITLERI — adresler, bayraklar, magaza baglantilari.
// ==========================================================================
// HEPSI ORTAM DEGISKENINDEN OKUNUR; varsayilanlar KANONIK prod adresleridir.
// Test sunucusu (192.168.1.25) bunlari kendi ortam degiskenleriyle ezer
// (bkz. infra/.env.test.example). Prod (192.168.1.105) DONDURULMUS.

/** Yoneticinin GIRIS yapacagi calisma alani. Sakine GONDERILMEZ (§6). */
export const APP_ADRESI =
  process.env.NEXT_PUBLIC_APP_ADRESI ?? "https://app.yonetiyor.com";

/** Tanitim sitesinin kendi kanonik adresi (metadata/OG icin). */
export const SITE_ADRESI =
  process.env.NEXT_PUBLIC_SITE_ADRESI ?? "https://yonetiyor.com";

/**
 * MAGAZA BAGLANTILARI.
 *
 * App Store numeric id'si HENUZ YOK (backend `settings.app_store_url` de
 * bos varsayilanli, ayni gerekce). Bos ise dugme CIZILMEZ — uydurma bir
 * id ile kirik baglanti gostermek, hic gostermemekten kotudur. Ayni kural
 * `admin-web/lib/magaza.ts`te de gecerli; uc yuzey ayni davranir.
 */
export const PLAY_ADRESI =
  process.env.NEXT_PUBLIC_PLAY_ADRESI ??
  "https://play.google.com/store/apps/details?id=com.app.yonetiyor";
export const APP_STORE_ADRESI = process.env.NEXT_PUBLIC_APP_STORE_ADRESI ?? "";

/** Iletisim — backend `tanitim_iletisim` ucuna giden formda kullanilir. */
export const ILETISIM_EPOSTA =
  process.env.NEXT_PUBLIC_ILETISIM_EPOSTA ?? "destek@yonetio.site";

// --------------------------------------------------------------------------
// BAYRAKLAR
// --------------------------------------------------------------------------
// `NEXT_PUBLIC_*` degiskenleri DERLEME ANINDA gomulur. Bu yuzden bayrak
// degistirmek imaji yeniden derlemeyi gerektirir; `docs/P177-dagitim.md`
// bunu adim olarak yaziyor. Calisma zamani okumasi icin sunucu tarafina
// tasimak gerekirdi ve o, istemci bileseninde okunamayacagi icin her
// bayragi prop olarak asagi tasimak demekti.

/** Ceviren: "1"/"true"/"evet" -> true. Bos/tanimsiz -> `varsayilan`. */
function bayrak(deger: string | undefined, varsayilan: boolean): boolean {
  if (deger === undefined || deger === "") return varsayilan;
  return ["1", "true", "evet", "acik"].includes(deger.toLowerCase());
}

/**
 * §3 — "Tanitim doneminde ucretsiz" rozeti. KARAR VERILDI: varsayilan
 * ACIK; tek satirla kapatilabilir.
 */
export const TANITIM_UCRETSIZ = bayrak(
  process.env.NEXT_PUBLIC_TANITIM_UCRETSIZ,
  true,
);

/**
 * §4 — TEKIL OTURUM ACMA saglayicilari.
 *
 * Google CALISIYOR (test istemcisi yapilandirilmis). Microsoft ve Apple
 * VARSAYILAN KAPALI: dugme gorunur ama tiklanamaz, uzerinde "Yakında"
 * rozeti olur. Saglayici hazir oldugunda YALNIZ BAYRAK acilir — bilesen
 * kodu degismez.
 */
export const SSO_GOOGLE = bayrak(process.env.NEXT_PUBLIC_SSO_GOOGLE, true);
export const SSO_MICROSOFT = bayrak(process.env.NEXT_PUBLIC_SSO_MICROSOFT, false);
export const SSO_APPLE = bayrak(process.env.NEXT_PUBLIC_SSO_APPLE, false);

/**
 * §0 — YENI KAYIT AKISI.
 *
 * BURADA BIR BAYRAK YOK ve bu bilincli bir karar (bkz.
 * docs/P177-kararlar.md). Kapi TEK YERDE, BACKEND'de:
 * `YENI_KAYIT_AKISI=false` iken yeni kayit uclari `503 kayit_akisi_kapali`
 * doner ve mevcut kimlik sistemi birebir bugunku gibi calisir.
 *
 * Ikinci bir istemci bayragi koymak, iki bayragin ayrisabilecegi bir
 * durum uretirdi: arayuz "acik" sanip form gonderir, backend reddeder —
 * ya da tersi, backend acikken arayuz formu gizler ve acilis fark
 * edilmez. Site backend'in yanitini OLDUGU GIBI gosterir.
 */
