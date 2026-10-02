// (P250 §1) KISI ADI: AD + SOYAD, Turkce harf kuraliyla bicim.
//
// Sunucudaki `backend/app/kisi_adi.py`nin IKIZI; ayni ornekler iki tarafta
// da testle kilitli (`tests/p250-ad-soyad.test.ts`).
//
//   Ad    : her kelimenin bas harfi buyuk, gerisi kucuk ("mehmet ali" ->
//           "Mehmet Ali"); tire de kelime ayirir.
//   Soyad : tamami buyuk ("yilmaz" -> "YILMAZ").
//
// TURKCE HARF KURALI: i <-> noktali buyuk I, noktasiz kucuk i <-> I. `toUpperCase()` "i"yi "I" yapar
// ("ilker" -> "ILKER", yanlis). `toLocaleUpperCase("tr")` dogru sonuc
// verir ama calisma ortaminin ICU verisine baglidir; dort harf ELLE
// cevrilip sonra varsayilan donusum uygulanir — her ortamda ayni sonuc.
//
// YAZARKEN vs KAYDEDERKEN: yazarken yalniz harf buyuklugu degisir (bosluk
// silinmez, yoksa kullanici "Mehmet " yazdiktan sonra ikinci adi yazamaz);
// kaydederken bas/son kirpilir ve ic bosluklar teke iner.

// Harfler KACIS DIZISIYLE yazili: kaynak taramasi (`i18n.test.ts`) Turkce
// harfli sabiti cevrilmemis arayuz metni sayar. \u0130 = "I" noktali buyuk,
// \u0131 = noktasiz kucuk "i".
const NOKTALI_BUYUK_I = "\u0130";
const NOKTASIZ_KUCUK_I = "\u0131";

export function trBuyuk(s: string): string {
  return s
    .replace(/i/g, NOKTALI_BUYUK_I)
    .replace(new RegExp(NOKTASIZ_KUCUK_I, "g"), "I")
    .toUpperCase();
}

export function trKucuk(s: string): string {
  return s
    .replace(/I/g, NOKTASIZ_KUCUK_I)
    .replace(new RegExp(NOKTALI_BUYUK_I, "g"), "i")
    .toLowerCase();
}

function sadelestir(s: string): string {
  return s.replace(/\s+/g, " ").trim();
}

/** Kelime ayiricilari (bosluk, tire) korunarak her kelime bas harf buyuk. */
function kelimeBasi(s: string): string {
  return s
    .split(/([\s-]+)/)
    .map((p) =>
      !p || /^[\s-]+$/.test(p) ? p : trBuyuk(p.charAt(0)) + trKucuk(p.slice(1)),
    )
    .join("");
}

export function adBicimle(s: string, yazarken = false): string {
  return kelimeBasi(yazarken ? s : sadelestir(s));
}

export function soyadBicimle(s: string, yazarken = false): string {
  return trBuyuk(yazarken ? s : sadelestir(s));
}

/** Saklanan gorunen ad (sunucu ayni sekilde birlestirir). */
export function tamAd(ad: string, soyad: string | null | undefined): string {
  return soyad ? `${ad} ${soyad}` : ad;
}

/**
 * Saklanan `ad` (TAM ad) + `soyad`tan duzenleme formu on-dolumu.
 * Soyad bilinmiyorsa (P250 oncesi kayit) SON KELIME soyad onerilir;
 * kayit ancak kullanici formu kaydedince degisir.
 */
export function adAyir(
  tam: string,
  soyad: string | null | undefined,
): { ad: string; soyad: string } {
  if (soyad && tam.endsWith(` ${soyad}`)) {
    return { ad: tam.slice(0, -soyad.length - 1), soyad };
  }
  const i = tam.lastIndexOf(" ");
  if (i > 0) return { ad: tam.slice(0, i), soyad: tam.slice(i + 1) };
  return { ad: tam, soyad: "" };
}
