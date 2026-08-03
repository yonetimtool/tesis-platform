// (P122) DAIRE TIPINE BAGLI RENK — bir kat bir bakista okunsun.
//
// Tasarimcida tip atandiktan sonra bilgi yalniz YAN PANELDE duruyordu;
// izgaraya bakan kisi hangi dairenin ne oldugunu ancak tek tek dokunarak
// gorebiliyordu. Kat planinin isi tam olarak budur: BAKISTA OKUNMAK.
//
// MOBILDEKI `daire_tipi_rengi.dart` ILE AYNI ALGORITMA VE AYNI PALET.
// Ayni tip iki yuzeyde AYNI rengi almalidir: yonetici panelde bakip mobilde
// dogruluyor; renk ayrisirsa iki ekrandan biri "yanlis" gorunur ve guven
// kaybi teknik bir hatadan daha pahaliya patlar. `daire-tipi-rengi.test.ts`
// iki tarafin ayni sonucu uretmesini KILITLIYOR.
//
// RENK AD'DAN TURETILIR, KAYITTA TUTULMAZ: tipe bir renk kolonu eklemek
// yoneticinin doldurmasi gereken bir alan daha demekti (ve doldurulmadiginda
// yine renksiz kalirdi). Turetilen renk her zaman vardir ve tutarlidir.

/** Tip renkleri — mobil `daireTipiPaleti` ile BIREBIR ayni sira. */
export const DAIRE_TIPI_PALETI = [
  "#3949AB", // indigo (mevcut varsayilan — tipsizle ayni aile)
  "#00897B", // teal
  "#8E24AA", // mor
  "#EF6C00", // turuncu
  "#43A047", // yesil
  "#00838F", // camgobegi
  "#C62828", // kirmizi
  "#5D4037", // kahve
] as const;

/**
 * Tip adi icin kararli renk. Bos/tanimsiz → varsayilan indigo.
 *
 * Karma DETERMINISTIK: JS'te de Dart'ta da ayni sonucu vermesi icin basit
 * ve sabit bir toplam kullanilir (dilin kendi hash'ine guvenilmez —
 * `String.hashCode` Dart'ta calismalar arasi degisebilir).
 *
 * `codePointAt` KULLANILIR, `charCodeAt` DEGIL: Dart tarafi `runes`
 * (kod NOKTALARI) uzerinde yuruyor. "🏠 Daire" gibi bir adda `charCodeAt`
 * vekil cifti (surrogate pair) iki ayri birim sayar ve iki taraf FARKLI
 * renk uretirdi.
 */
export function daireTipiRengi(tipAd?: string | null): string {
  const ad = (tipAd ?? "").trim();
  if (!ad) return DAIRE_TIPI_PALETI[0];
  let toplam = 0;
  for (const harf of ad.toLowerCase()) {
    // 31 carpani ve 16 bit maske: tasmayi onler, dagilimi korur.
    toplam = (toplam * 31 + (harf.codePointAt(0) ?? 0)) & 0xffff;
  }
  return DAIRE_TIPI_PALETI[toplam % DAIRE_TIPI_PALETI.length];
}

/**
 * Hucrede gosterilecek KISA tip etiketi (mobil `daireTipiKisa` ikizi).
 *
 * Tip adlari "2+1" gibi kisa olabildigi gibi "Dubleks Bahce Kati" gibi uzun
 * da olabilir. Kirpma secildi, bas harflere indirmek degil: "Dubleks…"
 * okunabilir, "DBK" degildir.
 */
export function daireTipiKisa(tipAd?: string | null, sinir = 7): string {
  const ad = (tipAd ?? "").trim();
  if (!ad) return "";
  // Kod NOKTASI sayilir: emoji/birlesik karakter ortadan bolunmemeli.
  const harfler = [...ad];
  if (harfler.length <= sinir) return ad;
  return `${harfler.slice(0, sinir - 1).join("")}…`;
}
