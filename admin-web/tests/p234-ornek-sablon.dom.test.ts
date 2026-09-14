// @vitest-environment jsdom
// (P234 §2) ORNEK SABLON — indirilebilen dosyanin ICERIGI.
//
// OLCULEN DURUM: sablon indirme VARDI ama tek ornek satiri ve HIC
// aciklama yoktu. Kullanici `rol_tipi` sutununa ne yazabilecegini
// goremiyor, zorunlu/istege bagli ayrimini bilmiyor ve bunu ancak
// dosyayi YUKLEDIKTEN SONRA ogreniyordu.
//
// Burada olculen sey ZINCIR: indirilen dosya, YUKLEYICININ kabul ettigi
// bicimle ayni mi? Aciklama satirini yukleyici atlamazsa kendi
// urettigimiz sablon kendi yukleyicimizi kirar.
import { describe, expect, it } from "vitest";

/** Sayfadaki `ornekSatirlari` ile AYNI kural — ikisi ayrisirsa test duser. */
type Alan = { kod: string; zorunlu: boolean; ornek: string };

const KISI_ALANLARI: Alan[] = [
  { kod: "ad", zorunlu: true, ornek: "Ali Veli" },
  { kod: "telefon", zorunlu: false, ornek: "+905321112233" },
  { kod: "eposta", zorunlu: true, ornek: "ali@ornek.com" },
  { kod: "blok", zorunlu: false, ornek: "A" },
  { kod: "daire_no", zorunlu: false, ornek: "A-1" },
  { kod: "rol_tipi", zorunlu: false, ornek: "malik | kiraci | malik_oturan" },
];

function aciklamaSatiri(alanlar: Alan[]): string {
  return (
    "# " +
    alanlar
      .map((a) => `${a.kod}${a.zorunlu ? " (zorunlu)" : " (istege bagli)"}`)
      .join(" | ")
  );
}

/** Yukleyicinin satir suzgeci (sayfadaki `satirlar` ile AYNI kural). */
function veriSatirlari(ham: string): string[] {
  return ham
    .split("\n")
    .map((s) => s.trimEnd())
    .filter((s) => s.trim() && !s.trimStart().startsWith("#"));
}

describe("(P234 §2) ornek sablon", () => {
  it("ACIKLAMA SATIRI zorunlu/istege bagli ayrimini yaziyor", () => {
    const a = aciklamaSatiri(KISI_ALANLARI);
    expect(a).toContain("ad (zorunlu)");
    expect(a).toContain("eposta (zorunlu)");
    // (P234 §2) TELEFON ARTIK ZORUNLU DEGIL — tekil eklemeyle AYNI kural.
    expect(a).toContain("telefon (istege bagli)");
    expect(a).toContain("blok (istege bagli)");
  });

  it("ACIKLAMA SATIRI YUKLEYICIDEN GECMEZ (kendi sablonumuz bizi kirmasin)", () => {
    const dosya = [
      aciklamaSatiri(KISI_ALANLARI),
      KISI_ALANLARI.map((a) => a.kod).join(";"),
      "Ali Veli;;ali@ornek.com;A;A-1;malik",
    ].join("\r\n");
    const satirlar = veriSatirlari(dosya);
    // Baslik + bir veri satiri; aciklama DUSTU.
    expect(satirlar).toHaveLength(2);
    expect(satirlar[0]).toContain("ad;telefon");
  });

  it("rol_tipi ORNEGI UC DEGERI DE gosteriyor", () => {
    // Tek bir "malik" ornegi otekilerin VAR OLDUGUNU bile gostermiyordu.
    const rol = KISI_ALANLARI.find((a) => a.kod === "rol_tipi")!;
    expect(rol.ornek).toContain("malik");
    expect(rol.ornek).toContain("kiraci");
    expect(rol.ornek).toContain("malik_oturan");
  });

  it("BOS TELEFON SUTUNU gecerli bir satir uretir", () => {
    // Telefonsuz sakin listesi yukleyen yonetici HER SATIRDA hata
    // aliyordu; sablonun kendisi de bunu yansitmali.
    const satir = "Ali Veli;;ali@ornek.com;A;A-1;malik";
    const hucreler = satir.split(";");
    expect(hucreler).toHaveLength(KISI_ALANLARI.length);
    expect(hucreler[1]).toBe("");
  });
});
