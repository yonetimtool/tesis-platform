import { readFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { sinirsizGirdiler } from "./girdi-tarayici";
import { taranacakDosyalar } from "./tarama";

// =========================================================================
// (P248 §3a) KILIT — maxLength'SIZ METIN GIRDISI KALMASIN.
// =========================================================================
// Kullanici: "Metin alanlarina istenildigi kadar yazilabiliyor." Sunucu
// fazlasini 422 ile reddeder (asil koruma, backend test_p248_girdi_siniri),
// ama kullanici bunu ancak KAYDEDERKEN ogrenirdi. Istemci `maxLength`
// fazlasini yazdirmaz.
//
// TARANAN: app/ ve components/ altindaki her .tsx'te `<input>` (metin
// tipli ya da tipsiz), `<textarea>`, `<Alan>`, `<CokSatir>`. `Alan` ve
// `CokSatir`in VARSAYILAN siniri olsa da cagiranin ACIK deger vermesi
// istenir: varsayilan (200/2000) cogu alan icin sunucudan farklidir ve
// alanin gercek sinirini dusunmeden gecmek kilidin amacini bosa cikarir.
//
// TELEFON girdileri (`type="tel"`, `inputMode="tel"`) taranmaz: telefon
// uzunlugu P248 §2'nin ortak telefon bileseninde (TelefonAlani).
//
// DEGER: `lib/girdi-siniri.ts` (`SINIR` sunucuyla birebir — girdi-siniri
// kilidi) ya da semadaki ozel sayi + `// sunucu: Sema.alan` yorumu.

const KOK = resolve(__dirname, "..");

/** Gerekceli istisnalar: dosya -> neden. */
const ISTISNALAR: Record<string, string> = {
  "components/ui/tarih-araligi.tsx":
    "`type={tip}` yalniz `date` | `datetime-local` (AralikTipi) — metin degil.",
};


const DOSYALAR = taranacakDosyalar(["app", "components"]);

describe("(P248 §3a) metin girdisi maxLength kilidi", () => {
  it("her metin girdisinin maxLength'i var (istisnalar gerekceli)", () => {
    const bulgular: string[] = [];
    for (const yol of DOSYALAR) {
      const goreli = relative(KOK, yol);
      if (goreli in ISTISNALAR) continue;
      for (const b of sinirsizGirdiler(readFileSync(yol, "utf8"))) {
        bulgular.push(`${goreli}:${b.satir} ${b.metin}`);
      }
    }
    expect(bulgular, "maxLength'siz metin girdisi (lib/girdi-siniri.ts)").toEqual([]);
  });

  it("istisna listesi bayat degil (dosya var ve hala istisna gerektiriyor)", () => {
    for (const d of Object.keys(ISTISNALAR)) {
      const kaynak = readFileSync(join(KOK, d), "utf8");
      expect(sinirsizGirdiler(kaynak).length, d).toBeGreaterThan(0);
    }
  });

  it("tarayici gercekten tariyor: sahte ihlal yakalanir, dogru ornekler gecer", () => {
    const kaynak = [
      "<Alan {...b} value={x} onChange={(e) => set(e.target.value)} />",
      '<input type="date" value={t} />',
      '<input type="tel" value={t} />',
      "<CokSatir\n  rows={3}\n  maxLength={SINIR.NOT}\n  value={y}\n/>",
      "{/* duz bir `<input>` birakmak */}",
      "// `<textarea>` yedegi",
      "<textarea value={z} onChange={(e) => (e.target.value.length > 3 ? a() : b())} />",
    ].join("\n");
    const b = sinirsizGirdiler(kaynak);
    expect(b.map((x) => x.satir)).toEqual([1, 11]);
  });

  it("kapsam: tarama yuzlerce girdi goruyor (bos tarama bir sey kilitlemez)", () => {
    let toplam = 0;
    for (const yol of DOSYALAR) {
      const s = readFileSync(yol, "utf8");
      toplam += (s.match(/<(input|textarea|Alan|CokSatir)(?=[\s/>])/g) ?? []).length;
    }
    expect(toplam).toBeGreaterThan(250);
  });
});
