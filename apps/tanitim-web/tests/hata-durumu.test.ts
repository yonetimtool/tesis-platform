import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

import { HataDurumu } from "@/components/HataDurumu";

/**
 * (P177 §7) "HataDurumu bileşenini kullanacaksan P175 kusurunu
 * TEKRARLAMA: mesaj null veya boş ise bileşen HİÇBİR ŞEY çizmeyecek.
 * Her çağrı yerini boş mesajla test et."
 *
 * IKI AYRI SEY DOGRULANIYOR:
 *   1. BILESENIN KENDISI bos girdide `null` donuyor mu,
 *   2. HER CAGRI YERI gercekten bos gecebilecek bir deger veriyor mu —
 *      yani kimse `mesaj="Bir hata olustu"` gibi SABIT bir metin
 *      gecmiyor. P175'teki kusur tam olarak buydu: bilesen bos girdide
 *      genel bir metne DUSUYORDU ve cagiranlar bunu bilmiyordu.
 */
describe("HataDurumu — bos mesaj hicbir sey cizmez", () => {
  it("null / undefined / bos / bosluk -> null", () => {
    expect(HataDurumu({ mesaj: null })).toBeNull();
    expect(HataDurumu({})).toBeNull();
    expect(HataDurumu({ mesaj: "" })).toBeNull();
    expect(HataDurumu({ mesaj: "   " })).toBeNull();
    expect(HataDurumu({ mesaj: "\n\t" })).toBeNull();
  });

  it("dolu mesaj -> ogeye donusur", () => {
    const cikti = HataDurumu({ mesaj: "Parolalar aynı değil." });
    expect(cikti).not.toBeNull();
    expect(JSON.stringify(cikti)).toContain("Parolalar aynı değil.");
  });

  it("YEDEK METIN YOK — bilesende sabit bir hata cumlesi bulunmamali", () => {
    // P175'te sahte hatayi ureten sey, bilesenin icindeki genel
    // "Veriler yuklenemedi." yedegiydi. Burada oyle bir yedek OLMAMALI.
    const kaynak = readFileSync(
      new URL("../components/HataDurumu.tsx", import.meta.url),
      "utf-8",
    );
    const govde = kaynak.slice(kaynak.indexOf("export function"));
    expect(govde).not.toMatch(/yüklenemedi|Bir hata oluştu/i);
  });

  it("TUM CAGRI YERLERI bos gecebilen bir deger veriyor", () => {
    // `mesaj={hata}` kalibi — `hata` durumu `null` baslar. Sabit metin
    // gecen bir cagri yeri bu testi dusurur.
    for (const dosya of ["KayitFormu.tsx", "IletisimFormu.tsx"]) {
      const kaynak = readFileSync(
        new URL(`../components/${dosya}`, import.meta.url),
        "utf-8",
      );
      const cagrilar = kaynak.match(/<HataDurumu[^/]*\/>/g) ?? [];
      expect(cagrilar.length).toBeGreaterThan(0);
      for (const c of cagrilar) expect(c).toContain("mesaj={hata}");
      // Durumun baslangici `null` olmali ki ilk karede kart cizilmesin.
      expect(kaynak).toContain("useState<string | null>(null)");
    }
  });
});
