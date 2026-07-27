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

/// `Accept-Language` basligini desteklenen tek dile indirger (RFC 9110).
/// Sunucu tarafiyla AYNI zincir: bolge eki duser, q'ya gore ilk desteklenen
/// dil kazanir, hicbiri yoksa Turkce.
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
  for (const a of adaylar) if (dilMi(a.dil)) return a.dil;
  return VARSAYILAN_DIL;
}

/// Istegin dili: KULLANICI SECIMI (cookie) -> tarayici dili -> Turkce.
export function istekDili(
  cookieDegeri: string | undefined,
  acceptLanguage?: string | null,
): Dil {
  if (dilMi(cookieDegeri)) return cookieDegeri;
  return acceptLanguageCoz(acceptLanguage);
}
