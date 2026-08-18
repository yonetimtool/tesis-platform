// (P168 §4.1) SMS SAYACI — ISTEMCI TARAFI, CANLI.
//
// =========================================================================
// NEDEN ISTEMCIDE DE VAR — VE SUNUCU HALA OTORITE
// =========================================================================
// Brief "Kalan Karakter Sayısı: N — canlı sayaç" istiyor. Her tusa
// basista sunucuya sormak, yazarken saniyede on istek atmak olurdu.
//
// SUNUCU YOK SAYILMIYOR: gonderim oncesi onizleme ucu (`/mesajlar/
// onizleme`) hala cagriliyor ve GERCEK olcumu o veriyor. Buradaki sayac
// YAZARKEN gosterilen tahmindir; kaydettikten sonra gorulen sayi
// sunucunundur.
//
// AYRISMA RISKI VAR VE YAZILI: iki uygulama (Python `sms_olc` ve bu
// dosya) ayni kurali tasiyor. Kural DEGISIRSE ikisi de degismeli.
// Tek kaynak yapmanin yolu sunucudan bir "karakter tablosu" indirmekti;
// 128 karakterlik sabit bir kume icin bu, her sayfa acilisina bir istek
// eklemek olurdu.
//
// =========================================================================
// TURKCE TUZAGI — SAYACIN VARLIK SEBEBI
// =========================================================================
// `ç ö ü Ä Ö Ü` GSM-7'de VARDIR. `ı ğ ş İ Ğ Ş` YOKTUR.
// Yani "Sayin Ali Bey" 160 karakterlik bir SMS'ken, "Sayın Ali Bey"
// UCS-2'ye duser ve sinir 70'e iner — "biraz uzun" bir mesaj birden UC
// SMS olur ve fatura ikiye katlanir. Kullanici bunu gonderdikten SONRA
// degil YAZARKEN gormeli.

/** GSM-7 temel kumesi — `backend/app/mesajlasma.py:_GSM7` ile AYNI. */
const GSM7 = new Set(
  "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?" +
    "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà",
);
/** GSM-7'de IKI karakter yer kaplayan genisletilmis isaretler. */
const GSM7_CIFT = new Set("^{}\\[~]|€");

export const TEK_GSM7 = 160;
export const COK_GSM7 = 153; // coklu SMS'te basliga 7 karakter gider
export const TEK_UCS2 = 70;
export const COK_UCS2 = 67;

export interface SmsOlcum {
  karakter: number;
  unicodeMi: boolean;
  parca: number;
  kalan: number;
  /** UCS-2'ye DUSUREN karakterler — "neden 3 SMS oldu" sorusunun cevabi. */
  zorlayan: string[];
}

export function smsOlc(metin: string): SmsOlcum {
  const zorlayan: string[] = [];
  let uzunluk = 0;
  // `Array.from`: emoji gibi vekil ciftleri TEK karakter sayilsin —
  // `for (const ch of metin)` ile ayni davranis (Python tarafi da
  // kod noktasi bazinda sayiyor).
  for (const ch of Array.from(metin)) {
    if (GSM7.has(ch)) uzunluk += 1;
    else if (GSM7_CIFT.has(ch)) uzunluk += 2;
    else {
      if (!zorlayan.includes(ch)) zorlayan.push(ch);
      uzunluk += 1;
    }
  }

  const unicodeMi = zorlayan.length > 0;
  if (unicodeMi) uzunluk = Array.from(metin).length; // UCS-2'de her karakter 1 birim
  const tek = unicodeMi ? TEK_UCS2 : TEK_GSM7;
  const cok = unicodeMi ? COK_UCS2 : COK_GSM7;

  if (uzunluk <= tek) {
    // BOS METIN SIFIR PARCA: "1 SMS" demek, hicbir sey yazmamis
    // kullaniciya bir maliyet gostermek olurdu.
    return {
      karakter: uzunluk,
      unicodeMi,
      parca: uzunluk ? 1 : 0,
      kalan: tek - uzunluk,
      zorlayan,
    };
  }
  const parca = Math.ceil(uzunluk / cok);
  return { karakter: uzunluk, unicodeMi, parca, kalan: parca * cok - uzunluk, zorlayan };
}
