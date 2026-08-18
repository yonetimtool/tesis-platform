"use client";

/**
 * (P170 §1) "BENI HATIRLA" — PAROLA NEREDE DURUR.
 *
 * =========================================================================
 * PAROLA UYGULAMA DEPOSUNA YAZILMAZ
 * =========================================================================
 * `localStorage`/`sessionStorage`/cerez hepsi AYNI SINIFTIR: ayni kokende
 * calisan her betik okuyabilir, tarayici gelistirici araclarinda duz metin
 * gorunur ve cihazi eline geciren biri icin tek tiklik istir. Bir XSS
 * acigi, o an ekranda olan bir kullanicinin degil TUM KAYITLI parolalarin
 * sizmasina donerdi. KVKK acisindan da savunulacak bir tarafi yok.
 *
 * Bu dosya parolayi HICBIR YERDE saklamaz. Sakladigi tek sey GIZLI OLMAYAN
 * tanimlayicilardir (tesis kodu, e-posta, telefon) — form ON-DOLDURMA icin.
 *
 * =========================================================================
 * PAROLAYI PLATFORMUN KENDI DEPOSU TUTAR
 * =========================================================================
 * Iki mekanizma birlikte calisir ve ikisi de tarayicinin kendi kimlik
 * deposuna (isletim sistemi anahtarligi) yazar:
 *
 *   1. FORM ISARETLEMESI — gercek `<form>`, `autocomplete="username"` /
 *      `"current-password"`, `name` ve `id`. Butun tarayicilarin parola
 *      yoneticisi bu isaretlemeyi okur; kaydetmeyi TEKLIF eder ve sonraki
 *      giriste ikisini birden doldurur. Calisan taban budur.
 *
 *   2. CREDENTIAL MANAGEMENT API (`navigator.credentials.store`) — tek
 *      sayfali uygulamalarda (1) YETMEZ: Chromium ailesi kaydetme teklifini
 *      cogunlukla GERCEK BIR GEZINMEYE bagliyor, bizde ise `preventDefault`
 *      + istemci tarafi yonlendirme var. Bu API teklifi ACIKCA tetikler.
 *      Firefox ve Safari desteklemez; orada (1) devrede kalir. Bu yuzden
 *      ikisi ALTERNATIF degil KATMANLIDIR.
 *
 * =========================================================================
 * "BENI HATIRLA" KAPALIYSA HICBIR SEY YAZILMAZ
 * =========================================================================
 * Kutu isaretsizse ne tanimlayici saklanir ne de `credentials.store`
 * cagrilir. Cikista ikisi de temizlenir ve `preventSilentAccess` ile
 * tarayicinin SESSIZ oturum acmasi kapatilir — ortak bir bilgisayarda
 * "cikis yaptim" demek, bir sonraki kisinin tek tikla girememesi demektir.
 */

const RM_TENANT = "yonetio.rememberMe.tenant";
const RM_EMAIL = "yonetio.rememberMe.email";
const RM_TELEFON = "yonetio.rememberMe.telefon";

/** Saklanan GIZLI OLMAYAN tanimlayicilar. Parola BURADA YOK ve olmayacak. */
export interface Tanimlayicilar {
  telefon?: string;
  tenantSlug?: string;
  email?: string;
}

export function tanimlayiciOku(telefonla: boolean): Tanimlayicilar | null {
  try {
    if (telefonla) {
      const telefon = localStorage.getItem(RM_TELEFON);
      return telefon === null ? null : { telefon };
    }
    const tenantSlug = localStorage.getItem(RM_TENANT);
    const email = localStorage.getItem(RM_EMAIL);
    if (tenantSlug === null || email === null) return null;
    return { tenantSlug, email };
  } catch {
    // Depolama erisilemezse (ozel kip vb.) on-doldurma yok — hata degil.
    return null;
  }
}

export function tanimlayiciYaz(d: Tanimlayicilar): void {
  try {
    if (d.telefon !== undefined) localStorage.setItem(RM_TELEFON, d.telefon);
    if (d.tenantSlug !== undefined) localStorage.setItem(RM_TENANT, d.tenantSlug);
    if (d.email !== undefined) localStorage.setItem(RM_EMAIL, d.email);
  } catch {
    // Depolama yoksa giris yine de basarili sayilir.
  }
}

export function tanimlayiciSil(): void {
  try {
    localStorage.removeItem(RM_TELEFON);
    localStorage.removeItem(RM_TENANT);
    localStorage.removeItem(RM_EMAIL);
  } catch {
    // yoksay
  }
}

/**
 * Tarayicinin kimlik deposuna kaydetmeyi TEKLIF ettirir.
 *
 * `PasswordCredential` yoksa (Firefox/Safari) sessizce doner: orada form
 * isaretlemesi zaten devrede ve ikinci bir yol denemek, kullaniciya iki
 * farkli teklif gostermek olurdu.
 *
 * HATA YUTULUR VE BU DOGRU: kimlik deposuna yazamamak GIRISI bozmaz.
 * Kullanici iceri girdi; "parolan kaydedilemedi" diye bir hata gostermek,
 * basarili bir islemi basarisiz gibi okuturdu.
 */
export async function kimligiSakla(
  kullanici: string,
  parola: string,
): Promise<void> {
  try {
    const K = (
      globalThis as unknown as {
        PasswordCredential?: new (d: {
          id: string;
          password: string;
        }) => Credential;
      }
    ).PasswordCredential;
    if (!K || !navigator.credentials?.store) return;
    await navigator.credentials.store(new K({ id: kullanici, password: parola }));
  } catch {
    // yoksay — bkz. yukarisi
  }
}

/**
 * Cikista: saklanan tanimlayicilari siler ve tarayicinin SESSIZ oturum
 * acmasini kapatir.
 */
export async function kimligiUnut(): Promise<void> {
  tanimlayiciSil();
  try {
    await navigator.credentials?.preventSilentAccess?.();
  } catch {
    // yoksay
  }
}
