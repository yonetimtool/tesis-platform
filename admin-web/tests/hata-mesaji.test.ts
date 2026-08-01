// (P60) HATA METNI HIJYENI — sinif kilidi.
//
// `jsonFetcher` ag hatasini, oturum bitisini ve sunucu zarfini ozenle
// CEVIRIR ve `Error(message)` olarak atar. Ama cagri yerinde
// `String(hata)` yazmak bu emegi bozar: `String(new Error("Baglanti
// yok."))` **"Error: Baglanti yok."** verir ve kullanici teknik onekli
// bir metin gorur. Olculdu: panelde iki yerde vardi (destek ve tanimlar).
//
// Kilit dar TUTULUR: yalniz `String(<hata-benzeri>)` kaliplari. Cunku
// `String(sayi)` gibi kullanimlar dogru ve yaygin.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (ad.endsWith(".tsx") || ad.endsWith(".ts")) cikti.push(yol);
  }
  return cikti;
}

describe("hata metni hijyeni", () => {
  it("hata nesnesi String() ile EKRANA YAZILMAZ", () => {
    // `String(err)` / `String(error)` / `String(hata)` / `String(exc)`
    const kalip = /String\(\s*(err|error|hata|exc|e)\b/;
    const sizanlar: string[] = [];
    for (const yol of [...dosyalar("app"), ...dosyalar("components")]) {
      readFileSync(yol, "utf8")
        .split("\n")
        .forEach((satir, i) => {
          // Yorum satirlari kapsam disi: kilidin GEREKCESI de bu kalibi
          // anlatmak zorunda ve kendi acikamasina takilan bir kilit,
          // yazilmasi imkansiz bir kilittir.
          if (/^\s*(\/\/|\*|\{\/\*)/.test(satir)) return;
          // KORUMALI BICIM DOGRUDUR: `e instanceof Error ? e.message :
          // String(e)` — `String` dali yalniz Error OLMAYAN bir firlatma
          // icin kosar (bir dizge, bir nesne). Onu da yasaklamak, geriye
          // hicbir secenek birakmazdi.
          if (/instanceof Error/.test(satir)) return;
          if (kalip.test(satir)) sizanlar.push(`${yol}:${i + 1} ${satir.trim()}`);
        });
    }
    expect(sizanlar).toEqual([]);
  });
});
