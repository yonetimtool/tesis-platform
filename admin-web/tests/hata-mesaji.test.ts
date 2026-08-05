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

import { taranacakDosyalar } from "./tarama";


describe("hata metni hijyeni", () => {
  it("hata nesnesi String() ile EKRANA YAZILMAZ", () => {
    // `String(err)` / `String(error)` / `String(hata)` / `String(exc)`
    const kalip = /String\(\s*(err|error|hata|exc|e)\b/;
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
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

describe("bos-durum iddiasi", () => {
  // (P61) "YUKLENIYOR DEGIL" ile "HATA YOK" AYNI SEY DEGILDIR.
  //
  // Iki sayfa bos-durum metnini yalniz `!isLoading` ile kosullamisti.
  // Istek dustugunde `isLoading` false olur ve liste bostur; sonuc:
  // hata kutusu ile "kayit yok" YAN YANA cikardi. Haritada durum daha
  // da acikti — baslikta "3 acik sikayet" yazarken altta "Acik sikayet
  // yok".
  //
  // KILIDIN SINIRI ACIK: yalniz `isLoading` ile kosullanmis bos-durum
  // ifadelerini yakalar. `building-editor`daki ikinci ornek TUREV bir
  // listeden geliyordu (`data?.items ?? []`) ve hicbir statik kural onu
  // yakalamazdi — o OKUYARAK bulundu. Yakalayamadigi seyi yakalıyormus
  // gibi anlatan bir kilit, yanlis guven verir.
  it("bos-durum kosulu YALNIZ isLoading'e dayanmaz", () => {
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      readFileSync(yol, "utf8")
        .split("\n")
        .forEach((satir, i) => {
          if (!/\.length === 0/.test(satir)) return;
          if (!/isLoading/.test(satir)) return;
          if (/error/i.test(satir)) return;
          sizanlar.push(`${yol}:${i + 1} ${satir.trim()}`);
        });
    }
    expect(sizanlar).toEqual([]);
  });
});
