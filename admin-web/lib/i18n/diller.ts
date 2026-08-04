// Panel dilleri — mobil uygulama ve icerik cevirisiyle AYNI kume (tur 17).
//
// Edge middleware'den de import edilebilir olmasi icin `next/headers` gibi
// server-only modul KULLANMAZ (bkz. lib/cookies.ts ile ayni kural).

export const DILLER = ["tr", "en", "ar", "ru", "de", "fr", "es"] as const;
export type Dil = (typeof DILLER)[number];

export const VARSAYILAN_DIL: Dil = "tr";

/// Dil secicide gosterilen ad — HER ZAMAN kendi dilinde. Cevrilirse secici
/// islevini yitirir: kullanici anlamadigi dilde kendi dilini arayamaz
/// (mobil `AppDil.adKendiDilinde` ile ayni karar).
export const DIL_ADLARI: Record<Dil, string> = {
  tr: "Türkçe",
  en: "English",
  ar: "العربية",
  ru: "Русский",
  de: "Deutsch",
  fr: "Français",
  es: "Español",
};

/// Sagdan sola yazilan diller (yalniz Arapca).
export function rtlMi(dil: Dil): boolean {
  return dil === "ar";
}

export function yon(dil: Dil): "rtl" | "ltr" {
  return rtlMi(dil) ? "rtl" : "ltr";
}

export function dilMi(deger: string | undefined | null): deger is Dil {
  return DILLER.includes(deger as Dil);
}

/// Secilen dilin saklandigi cookie. `httpOnly` DEGILDIR: istemci de okur
/// (secici anlik tepki verir) ve sunucu da (ilk boyamada `<html lang>` +
/// BFF'in `Accept-Language` basligi). localStorage yeterli olmazdi — sunucu
/// bileseni onu goremez, ilk kare yanlis dilde boyanirdi.
export const DIL_COOKIE = "ui.locale";
export const DIL_COOKIE_MAX_AGE = 365 * 24 * 60 * 60;

/// INGILIZCE BIR TERCIH SAYILMAZ — bilincli karar (P126 sonrasi).
///
/// Chrome/Edge kurulumlarinin cogu, kullanici hicbir sey secmemis olsa bile
/// `Accept-Language: en-US,en;q=0.9` gonderir: Turkiye'deki bir sakinin
/// tarayicisi da bunu gonderir. Yani `en` bir TERCIH degil, KURULUM
/// VARSAYILANIDIR ve onu tercih saymak Turkce urunu Ingilizce acardi
/// (Kerem app.*'i ilk actiginda tam olarak bu oldu).
///
/// Diger bes dil boyle degil: tarayicisini Arapca/Rusca/Almanca/Fransizca/
/// Ispanyolca'ya AYARLAMIS biri bunu bilerek yapmistir — o sinyal korunur.
/// Ingilizce isteyen kullanici dil seciciyle (kalici cerez) ya da `?lang=en`
/// ile bir tikta alir.
const TARAYICIDAN_KABUL_EDILMEYEN: ReadonlySet<string> = new Set(["en"]);

/// `Accept-Language` basligini desteklenen tek dile indirger (RFC 9110).
/// Bolge eki duser, q'ya gore ilk desteklenen dil kazanir; hicbiri yoksa
/// (ya da yalnizca Ingilizce varsa) Turkce.
export function acceptLanguageCoz(header: string | null | undefined): Dil {
  if (!header) return VARSAYILAN_DIL;
  const adaylar: { dil: string; q: number; sira: number }[] = [];
  header.split(",").forEach((parca, sira) => {
    const bolumler = parca.trim().split(";");
    const etiket = bolumler[0]?.trim().toLowerCase();
    if (!etiket || etiket === "*") return;
    let q = 1;
    for (const b of bolumler.slice(1)) {
      const m = /^\s*q\s*=\s*([0-9.]+)\s*$/.exec(b);
      if (m) q = Number(m[1]);
    }
    if (!Number.isFinite(q) || q <= 0) return;
    adaylar.push({ dil: etiket.split("-")[0], q, sira });
  });
  adaylar.sort((a, b) => b.q - a.q || a.sira - b.sira);
  for (const a of adaylar) {
    if (TARAYICIDAN_KABUL_EDILMEYEN.has(a.dil)) continue;
    if (dilMi(a.dil)) return a.dil;
  }
  return VARSAYILAN_DIL;
}

/// Istegin dili: KULLANICI SECIMI (cookie) -> tarayici dili (Ingilizce
/// HARIC, yukariya bkz.) -> Turkce.
export function istekDili(
  cookieDegeri: string | undefined,
  acceptLanguage?: string | null,
): Dil {
  if (dilMi(cookieDegeri)) return cookieDegeri;
  return acceptLanguageCoz(acceptLanguage);
}

/// Tarayicida KAYITLI tercih (yoksa `null`).
///
/// `tarayiciDili()`den farki: o her zaman bir dil dondurur (geri dususlerle);
/// bu ise "kullanici SECMIS mi?" sorusunu yanitlar. `?lang` isleme sirasi
/// bunu bilmek zorunda — kayitli tercih ONCE gelir.
export function kayitliDil(): Dil | null {
  if (typeof document === "undefined") return null;
  const m = new RegExp(`(?:^|; )${DIL_COOKIE}=([^;]+)`).exec(document.cookie);
  return dilMi(m?.[1]) ? (m?.[1] as Dil) : null;
}

/// Tarayicida cookie'den aktif dil (React DISI kod icin: fetcher, api
/// sarmalayici). Sunucuda `document` yoktur -> varsayilan dil.
export function tarayiciDili(): Dil {
  if (typeof document === "undefined") return VARSAYILAN_DIL;
  const m = new RegExp(`(?:^|; )${DIL_COOKIE}=([^;]+)`).exec(document.cookie);
  const secim = m?.[1];
  return dilMi(secim)
    ? secim
    : acceptLanguageCoz(
        typeof navigator === "undefined" ? null : navigator.language,
      );
}
