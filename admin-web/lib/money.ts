// Para = KURUS (integer minor units). Backend hep kurus verir/alir.
// UI'da TL<->kurus donusumu TAM SAYI aritmetigiyle yapilir; float kullanilmaz.

/** "750", "750,50", "750.5" -> 75000 / 75050 / 75050 (kurus). Gecersizse null. */
export function tlToKurus(input: string): number | null {
  const t = input.trim().replace(",", ".");
  if (!/^\d+(\.\d{1,2})?$/.test(t)) return null;
  const [intPart, fracPart = ""] = t.split(".");
  const frac = (fracPart + "00").slice(0, 2);
  return parseInt(intPart, 10) * 100 + parseInt(frac, 10);
}

/** Binlik ayirici — KENDIMIZ koyariz, `toLocaleString` KULLANMAYIZ.
 *
 * (P48) NEDEN: `toLocaleString("tr-TR")` ICU verisine baglidir. TAM ICU'lu
 * bir calisma zamaninda `5.000` verir; **kucuk-ICU** ile derlenmis bir
 * Node/tarayicida `tr-TR` desteklenmez ve `en-US`a duser: `5,000`. O
 * durumda para `5,000,00 ₺` gorunurdu — hem yanlis hem OKUNAMAZ, ve hata
 * yalniz BAZI ortamlarda ciktigi icin gelistirmede fark edilmezdi.
 *
 * Uc haneli gruplama dilden bagimsiz basit bir kuraldir; ICU'ya bagimli
 * olmak, kazanci olmayan bir ortam riski almakti.
 */
function binlikAyir(tamsayi: number): string {
  const s = String(tamsayi);
  let out = "";
  for (let i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 === 0) out += ".";
    out += s[i];
  }
  return out;
}

/** 75000 -> "750,00 ₺" (integer bolme/mod; float yok). */
export function kurusToTL(kurus: number): string {
  const neg = kurus < 0;
  const abs = Math.abs(kurus);
  const lira = Math.floor(abs / 100);
  const kr = abs % 100;
  return `${neg ? "-" : ""}${binlikAyir(lira)},${String(kr).padStart(2, "0")} ₺`;
}
