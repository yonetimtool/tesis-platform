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

/** 75000 -> "750,00 ₺" (integer bolme/mod; float yok). */
export function kurusToTL(kurus: number): string {
  const neg = kurus < 0;
  const abs = Math.abs(kurus);
  const lira = Math.floor(abs / 100);
  const kr = abs % 100;
  return `${neg ? "-" : ""}${lira.toLocaleString("tr-TR")},${String(kr).padStart(2, "0")} ₺`;
}
