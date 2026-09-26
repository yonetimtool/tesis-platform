// (P248 §3a) METIN GIRDISI TARAYICISI — `girdi-maxlength-tarama.test.ts`
// kilidinin cekirdegi. Ayri dosya: kilit testi hem gercek kaynagi hem
// sahte (gecici ihlalli) ornegi AYNI kodla olcer.
//
// JSX etiketi COK SATIRLI olabilir; etiket `>`ya kadar `{}` derinligi ve
// dize/sablon tirnaklari izlenerek okunur (ok fonksiyonundaki `=>` ya da
// `a > b` ifadesi etiketi erken kapatmaz).

/** Metin OLMAYAN input tipleri: uzunluk siniri anlamsiz. */
export const METIN_DISI_TIPLER = new Set([
  "number", "date", "time", "datetime-local", "month", "week", "checkbox",
  "radio", "file", "color", "range", "hidden", "submit", "button", "reset",
  "image",
  // (P248) TELEFON: §2'nin ortak telefon kurali; bu bolum dokunmaz.
  "tel",
]);

export const ETIKETLER = ["input", "textarea", "Alan", "CokSatir"] as const;

export interface Bulgu {
  satir: number;
  etiket: string;
  metin: string;
}

function etiketSonu(kaynak: string, bas: number): number {
  let derin = 0;
  let tirnak: string | null = null;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (tirnak) {
      if (c === "\\") {
        i++;
        continue;
      }
      if (c === tirnak) tirnak = null;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") {
      // Nitelik degeri disindaki JSX metninde tirnak olmaz; derinlik 0'da
      // yalniz nitelik dizesi (`a="..."`) acar.
      tirnak = c;
      continue;
    }
    if (c === "{") derin++;
    else if (c === "}") derin--;
    else if (c === ">" && derin === 0) return i;
  }
  return kaynak.length - 1;
}

/** maxLength'siz metin girdileri. */
export function sinirsizGirdiler(ham: string): Bulgu[] {
  const out: Bulgu[] = [];
  // Blok yorumlar (`/* */`, JSX `{/* */}`) ayni uzunlukta bosluga cevrilir:
  // icindeki "`<input>` birakmak" gibi sozler girdi DEGIL; satir numarasi
  // korunur.
  const kaynak = ham.replace(/\/\*[\s\S]*?\*\//g, (y) => y.replace(/[^\n]/g, " "));
  const desen = new RegExp(`<(${ETIKETLER.join("|")})(?=[\\s/>])`, "g");
  for (const m of kaynak.matchAll(desen)) {
    const bas = m.index ?? 0;
    // Yorum icindeki `<input>` sozu girdi degildir (`//`, `*`, `{/*`).
    const satirBasi = kaynak.lastIndexOf("\n", bas) + 1;
    const onu = kaynak.slice(satirBasi, bas);
    if (/(^|[^:])\/\/|^\s*\*|\/\*/.test(onu)) continue;
    const son = etiketSonu(kaynak, bas + m[0].length);
    const metin = kaynak.slice(bas, son + 1);
    if (/\bmaxLength\b/.test(metin)) continue;
    // Salt okunur alana yazilamaz.
    if (/\sreadOnly(\s|=\{true\}|\/?>)/.test(metin)) continue;
    // TELEFON (§2): inputMode="tel" / autoComplete="tel".
    if (/inputMode="tel"|autoComplete="tel/.test(metin)) continue;
    const tip = metin.match(/\stype="([a-z-]+)"/);
    if (tip && METIN_DISI_TIPLER.has(tip[1])) continue;
    out.push({
      satir: kaynak.slice(0, bas).split("\n").length,
      etiket: m[1],
      metin: metin.replace(/\s+/g, " ").slice(0, 160),
    });
  }
  return out;
}
