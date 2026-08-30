// Token cookie isimleri ve secenekleri. Edge middleware'den de import edilebilir
// olmasi icin next/headers gibi server-only modul KULLANMAZ.

export const ACCESS_COOKIE = "tesis_at";
export const REFRESH_COOKIE = "tesis_rt";

// /contracts/auth.md: access 15 dk, refresh 30 gun.
export const ACCESS_MAX_AGE = 15 * 60;
export const REFRESH_MAX_AGE = 30 * 24 * 60 * 60;

export interface CookieOptions {
  httpOnly: true;
  sameSite: "lax";
  secure: boolean;
  path: string;
  maxAge: number;
  domain?: string;
}

/**
 * (P191 §1) OTURUM CEREZI ALAN ADI — `panel.*` ve `app.*` AYNI OTURUMU
 * paylassin diye.
 *
 * OLCULEN KUSUR: cerezler KONAK-OZELdi (domain yok). P190 §1'de middleware
 * tesis rollerini `panel.*`tan `app.*`a tasimaya baslayinca su zincir
 * olustu: kullanici `panel.*`ta giris yapar -> cerez `panel.` konagina
 * yazilir -> middleware `app.*`a yollar -> orada CEREZ YOKTUR -> `/login`.
 * Yani "yanlis konaga dusen kullaniciyi dogru konaga tasi" duzeltmesi,
 * oturumu her seferinde dusuruyordu. Ayni sey SSO donusunde de olur:
 * `OAUTH_WEB_DONUS` tek bir konaktir, cerez orada yazilir.
 *
 * `COOKIE_DOMAIN=.yonetiyor.com` verilince cerez ust alan adina yazilir ve
 * iki yuzey tek oturumdur. BOS BIRAKILIRSA davranis BUGUNKUYLE AYNIDIR
 * (konak-ozel) — yerel gelistirme ve testler etkilenmez.
 *
 * GUVENLIK: cerezler `httpOnly` + `sameSite=lax` + prod'da `secure`.
 * Ust alan adina yazmak onlari kardes alt alanlara da gonderir; bu yuzden
 * degisken YALNIZ platformun kendi alt alanlarini barindirdigi alan adina
 * ayarlanmalidir (uctan uca ayni uygulama). Ucuncu tarafa acik bir alan
 * adinda KULLANMAYIN.
 *
 * Calisma zamani degiskenidir (`NEXT_PUBLIC_` DEGIL): cerezler yalniz BFF
 * route handler'larinda yazilir — imaj yeniden derlenmeden degistirilebilir.
 */
export function cookieDomain(): string | undefined {
  const d = (process.env.COOKIE_DOMAIN ?? "").trim().toLowerCase();
  if (!d || d === "localhost") return undefined;
  return d;
}

export function cookieOptions(maxAge: number): CookieOptions {
  const domain = cookieDomain();
  return {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge,
    ...(domain ? { domain } : {}),
  };
}
