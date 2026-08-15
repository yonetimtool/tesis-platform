// (P162 §4.2) XLSX OKUYUCU — GERCEK bir dosyayla.
//
// Sikayet: "Excel ice aktarma calismiyor". Kok neden: boru hattinin
// tamami vardi (sablon, kolon esleme, dogrulama, onizleme, hata raporu,
// kismi basari, geri alma) ama DOSYA OKUMA yoktu — sayfa yalnizca
// yapistirma kabul ediyordu.
//
// BU TEST SAHTE VERI KULLANMAZ: `tests/veri/ornek.xlsx` gercek bir ZIP
// icinde gercek SpreadsheetML'dir (`tools`la degil, standart `zipfile`
// ile uretildi). Okuyucu yalnizca kendi ayristirdigi bir bicimi degil,
// Excel'in yazdigi bicimi okumak zorunda.
//
// OLCULEN DAVRANISLAR — hepsi gercek bozulma siniflari:
//   * paylasilan dize tablosu (`t="s"`) cozulur,
//   * satir-ici dize (`t="inlineStr"`) cozulur,
//   * ZENGIN METIN (`<si>` icinde birden cok `<t>`) BIRLESTIRILIR,
//   * ATLANAN HUCRE hizalamayi bozmaz (XLSX bos hucreyi hic yazmaz),
//   * FORMUL DEGERLENDIRILMEZ — yalnizca onbelleklenmis deger okunur.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { sayfayiCoz, sutunIndeksi, xlsxSatirlari } from "@/lib/xlsx-oku";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const DOSYA = readFileSync(join(KOK, "tests", "veri", "ornek.xlsx"));

describe("sutunIndeksi", () => {
  it("harf sutunlarini sifir tabanli indekse cevirir", () => {
    expect(sutunIndeksi("A1")).toBe(0);
    expect(sutunIndeksi("B2")).toBe(1);
    expect(sutunIndeksi("Z9")).toBe(25);
    expect(sutunIndeksi("AA1")).toBe(26);
    expect(sutunIndeksi("BC12")).toBe(54);
  });
});

describe("sayfayiCoz", () => {
  it("ATLANAN HUCRE hizalamayi bozmaz", () => {
    // XLSX bos hucreyi HIC yazmaz. `A` ve `C` varsa `B` bos kalmali;
    // kaymasi butun kolon eslemesini sessizce yanlis yapardi.
    const xml =
      '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row>';
    expect(sayfayiCoz(xml, ["sol", "sag"])).toEqual([["sol", "", "sag"]]);
  });

  it("FORMUL DEGERLENDIRILMEZ — onbelleklenmis deger okunur", () => {
    const xml = '<row r="1"><c r="A1"><f>SUM(1,2)</f><v>3</v></c></row>';
    const satirlar = sayfayiCoz(xml, []);
    expect(satirlar[0][0]).toBe("3");
    // Formulun kendisi hucreye SIZMAMALI.
    expect(satirlar[0][0]).not.toContain("SUM");
  });

  it("XML VARLIKLARI cozulur ama OZEL varlik genisletilmez", () => {
    const xml = '<row r="1"><c r="A1" t="inlineStr"><is><t>a &amp; b</t></is></c></row>';
    expect(sayfayiCoz(xml, [])[0][0]).toBe("a & b");
  });
});

describe("xlsxSatirlari — gercek dosya", () => {
  it("ilk sayfanin butun satirlarini okur", async () => {
    const satirlar = await xlsxSatirlari(new Blob([DOSYA]));
    expect(satirlar).toHaveLength(4);
  });

  it("PAYLASILAN DIZE tablosu cozulur (baslik satiri)", async () => {
    const satirlar = await xlsxSatirlari(new Blob([DOSYA]));
    expect(satirlar[0]).toEqual(["blok", "no", "kat"]);
  });

  it("SAYI hucreleri metne cevrilir (kolon eslemesi metinle calisir)", async () => {
    const satirlar = await xlsxSatirlari(new Blob([DOSYA]));
    expect(satirlar[1]).toEqual(["A", "12", "3"]);
  });

  it("SATIR-ICI dize + ATLANAN hucre birlikte dogru", async () => {
    const satirlar = await xlsxSatirlari(new Blob([DOSYA]));
    // `A3` satir-ici "B", `B3` YOK, `C3` formullu hucre (degeri 7).
    expect(satirlar[2]).toEqual(["B", "", "7"]);
  });

  it("ZENGIN METIN parcalari BIRLESTIRILIR", async () => {
    const satirlar = await xlsxSatirlari(new Blob([DOSYA]));
    // `<si><t>Ç</t><t>ift</t></si>` -> tek bir "Çift".
    expect(satirlar[3][0]).toBe("Çift");
  });

  it("BOZUK dosya SESSIZ KALMAZ", async () => {
    await expect(xlsxSatirlari(new Blob([new Uint8Array(64)]))).rejects.toThrow();
  });
});
