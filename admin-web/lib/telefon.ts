// (P123) TELEFON GIRISI — panel tarafi. Mobil `telefon_alani.dart` IKIZI.
//
// AYNI KURALLAR iki yuzeyde de gecerlidir: gruplama `0543 199 29 04`,
// yalniz rakam, SERT uzunluk siniri, `5` ile baslama zorunlulugu ve
// yapistirmanin cozulmesi. Iki yuzey ayrisirsa yonetici panelde kaydettigi
// numarayi mobilde farkli gorur ve hangisinin dogru oldugunu bilemez.
// `tests/telefon.test.ts` ile mobil testinin PAYLASILAN tablosu ayni.
//
// TEL BICIMI DEGISMEDI: sunucuya giden deger yine `normalize_phone`in
// kabul ettigi bicimdir (`telefonNormalle` E.164 uretir).

/** TR cep numarasi: `5` ile baslayan 10 hane (bastaki `0` haric). */
export const TELEFON_HANE_SAYISI = 10;

/** Ekranda gorunen gruplama: `0` + `543` `199` `29` `04`. */
const GRUPLAR = [3, 3, 2, 2];

/**
 * Ham girdiden YALNIZ haneleri cikarir ve TR yerel bicimine indirger.
 *
 * `+90`, `0090`, `90` ve bastaki `0` SOYULUR: kullanici numarayi nereden
 * yapistirirsa yapistirsin ayni 10 haneye iner.
 */
export function telefonHaneleri(ham: string): string {
  let s = (ham ?? "").replace(/\D/g, "");
  if (s.startsWith("0090")) {
    s = s.slice(4);
  } else if (s.startsWith("90") && s.length > TELEFON_HANE_SAYISI) {
    // `90` YALNIZ fazladan hane varken ulke kodu sayilir: `9053…` diye
    // baslayan bir numara yoktur ama `905431992904` (12 hane) vardir.
    s = s.slice(2);
  }
  if (s.startsWith("0")) s = s.slice(1);
  if (s.length > TELEFON_HANE_SAYISI) s = s.slice(0, TELEFON_HANE_SAYISI);
  return s;
}

/** Haneleri `0543 199 29 04` bicimine sokar (eksikse kismi). */
export function telefonBicimle(haneler: string): string {
  if (!haneler) return "";
  let out = "0";
  let i = 0;
  for (const uzunluk of GRUPLAR) {
    if (i >= haneler.length) break;
    const son = Math.min(i + uzunluk, haneler.length);
    if (i > 0) out += " ";
    out += haneler.slice(i, son);
    i = son;
  }
  return out;
}

/** Girdi kutusunun gostermesi gereken deger (yazma + yapistirma tek yol). */
export function telefonGiris(ham: string): string {
  return telefonBicimle(telefonHaneleri(ham));
}

/**
 * Sunucuya gidecek deger — E.164.
 *
 * Sunucu `0543…` bicimini de kabul eder; yine de normallestirilmis
 * gonderilir: ayni numaranin iki farkli yazimla iki kayit uretmesi, telefon
 * GLOBAL BENZERSIZ oldugu icin bir cakisma hatasina donusurdu.
 */
export function telefonNormalle(ham: string): string {
  const h = telefonHaneleri(ham);
  return h ? `+90${h}` : "";
}

/** Dogrulama sonucu — METIN DEGIL KIMLIK (cumle cizim katmaninda). */
export type TelefonHatasi = "bos" | "eksik" | "gecersizOnEk";

/**
 * `null` = gecerli. `zorunlu` false ise bos deger gecerlidir.
 *
 * Kural "kapali operator listesi" DEGIL, "5 ile baslamali"dir: BTK yeni
 * blok tahsis edebilir ve bilinmeyen bir blogu reddetmek, gercek bir
 * numarayi kaydettirmemek olurdu. Amac SABIT HATTI ayirmak — `0212…` bir
 * cep numarasi degildir ve SMS gitmez.
 */
export function telefonHatasi(
  ham: string,
  zorunlu = true,
): TelefonHatasi | null {
  const h = telefonHaneleri(ham);
  if (!h) return zorunlu ? "bos" : null;
  if (!h.startsWith("5")) return "gecersizOnEk";
  if (h.length < TELEFON_HANE_SAYISI) return "eksik";
  return null;
}
