// Para = KURUS (integer minor units). Backend hep kurus verir/alir.
// UI'da TL<->kurus donusumu TAM SAYI aritmetigiyle yapilir; float kullanilmaz.
//
// (P55) GRUPLAMA BURADA DEGIL `lib/sayi.ts`te: ayni kural para olmayan
// sayilarda da gerekiyor (metrekare) ve iki kopya tutmak, birinin
// duzeltilip digerinin unutulmasi demekti.
import { binlikAyir } from "./sayi";

/** "750" / "750,50" / "750.5" / "1.250,00" -> kurus. Gecersizse null.
 *
 * (P50) BINLIK AYIRICI KABUL EDILIR. Onceki surum `replace(",", ".")` +
 * `^\d+(\.\d{1,2})?$` ile calisiyordu ve `1.250,00` girdisini
 * REDDEDIYORDU — oysa panelin kendisi ayni tutari [kurusToTL] ile
 * `1.250,00 ₺` diye GOSTERIYOR. Yani uygulama, gosterdigi bicimi geri
 * kabul etmiyordu; kullanici gordugu sayiyi yazip "gecersiz tutar"
 * aliyordu. (Mobil tarafta ayni kusur P49'da bulundu; kural burada da
 * AYNIDIR — iki istemcinin ayni metni farkli ayristirmasi, ayni sitede
 * farkli tutar girilebilmesi demekti.)
 *
 * AYIRICI KURALI (Turkce yazim):
 *   * Virgul VARSA: virgul ONDALIK, nokta BINLIK.
 *   * Virgul YOKSA ve TEK nokta + en fazla iki hane: nokta ONDALIK
 *     (sayisal klavyeden gelen `1250.00`).
 *   * Aksi halde nokta BINLIK (`1.250` = 1250).
 */
export function tlToKurus(input: string): number | null {
  // Para birimi jetonu ve UC BOSLUKLARI temizlenir; ICERIDEKI bosluk
  // BIRAKILIR ve asagida reddedilir: `1 000` Turkce yazimda bir sayi
  // DEGILDIR ve icerideki bosluklari silmek `1 2 3`u de kabul etmek olurdu.
  const s = input.replace(/[₺]|TL/g, "").trim();
  if (/\s/.test(s)) return null;
  if (s === "" || s.startsWith("-")) return null;

  let tam: string;
  let ondalik = "";
  if (s.includes(",")) {
    const parts = s.split(",");
    // ONDALIK AYIRICI VARSA ARDINDA HANE OLMALI: `750,` YARIM bir
    // giristir ve sessizce 750,00 saymak, kullanicinin yazmayi bitirmedigi
    // bir tutari kaydetmek olurdu.
    // Ayiricinin ONUNDE de hane olmali: `,50` yine YARIM bir giristir
    // (kullanici lira kismini yazmadi) ve 0,50 saymak onun adina karar
    // vermek olurdu.
    if (parts.length !== 2 || parts[1] === "" || parts[0] === "") return null;
    tam = parts[0].replace(/\./g, "");
    ondalik = parts[1];
  } else {
    const son = s.lastIndexOf(".");
    if (
      son !== -1 &&
      s.length - son - 1 >= 1 &&
      s.length - son - 1 <= 2 &&
      s.indexOf(".") === son
    ) {
      if (son === 0) return null; // `.50` — yarim giris
      tam = s.slice(0, son);
      ondalik = s.slice(son + 1);
    } else if (son === s.length - 1) {
      return null; // `750.` — yarim giris (yukaridaki gerekce)
    } else {
      tam = s.replace(/\./g, "");
    }
  }
  if (ondalik.length > 2) return null;
  if (tam === "" && ondalik === "") return null;
  if (!/^\d*$/.test(tam) || !/^\d*$/.test(ondalik)) return null;
  const lira = parseInt(tam === "" ? "0" : tam, 10);
  const kr = ondalik === "" ? 0 : parseInt(ondalik.padEnd(2, "0"), 10);
  if (Number.isNaN(lira) || Number.isNaN(kr)) return null;
  return lira * 100 + kr;
}

/** 75000 -> "750,00 ₺" (integer bolme/mod; float yok). */
export function kurusToTL(kurus: number): string {
  const neg = kurus < 0;
  const abs = Math.abs(kurus);
  const lira = Math.floor(abs / 100);
  const kr = abs % 100;
  return `${neg ? "-" : ""}${binlikAyir(lira)},${String(kr).padStart(2, "0")} ₺`;
}
