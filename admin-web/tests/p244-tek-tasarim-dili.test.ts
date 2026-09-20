// (P244 §4) TEK TASARIM DILI — karma sayfa BIRAKILMAZ.
//
// ===========================================================================
// OLCULEN DURUM
// ===========================================================================
// P160'ta bilincli bir gecis karari verilmisti: eski dil (`globals.css` +
// tailwind renkleri) korunsun, yeni `--yz-*` dili YANINA konsun. Gecis
// P244 asama 1'de %75'ti — 59 sayfa yalniz yeni dil, **18 karma**, 0
// yalniz eski.
//
// Asama 4 kalan 18'i temizledi. Bu kilit GERI DONMESINI engelliyor.
//
// ===========================================================================
// NEDEN MODUL YOLU OLCULUYOR
// ===========================================================================
// "Tasarim dili" gorsel bir seydir ve jsdom RENK COZMEZ — bir DOM testi
// eski dille cizilmis bir sayfayi sorunsuz bulur (P226'da olculdu).
// Olculebilecek en yakin YAPISAL sey, sayfanin hangi katmandan ithal
// ettigi. Asama 4'te modul sinirlari tasarim dili siniriyla ayni yere
// getirildi: gorsel ilkeller `components/ui/` altinda, eski dosyalarda
// yalniz forma ait olanlar kaldi.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

/** Eski tasarim dilinin GORSEL modulleri. */
const ESKI_MODULLER = [
  "@/components/tablo",
  "@/components/tasarim",
  "@/components/Liste",
  "@/components/Modal",
];

function sayfalar(): string[] {
  const cikti: string[] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) tara(tam);
      else if (ad === "page.tsx") cikti.push(tam);
    }
  };
  tara(join(KOK, "app", "(protected)"));
  return cikti;
}

describe("(P244 §4) tek tasarim dili", () => {
  const liste = sayfalar();

  it("TARAMA gercekten sayfa buluyor (vakum degil)", () => {
    // 79 sayfa olculmustu; sayi degisebilir ama sifir olamaz.
    expect(liste.length).toBeGreaterThan(50);
  });

  it("HICBIR korumali sayfa ESKI gorsel modulden ithal etmiyor", () => {
    const suclular: string[] = [];
    for (const p of liste) {
      const kaynak = readFileSync(p, "utf8");
      for (const mod of ESKI_MODULLER) {
        if (kaynak.includes(`from "${mod}"`)) {
          suclular.push(`${p.slice(KOK.length + 1)} -> ${mod}`);
        }
      }
    }
    expect(
      suclular,
      `karma dil kullanan sayfa:\n${suclular.join("\n")}`,
    ).toEqual([]);
  });

  it("ESKI `tasarim.tsx` ARTIK KIMSE TARAFINDAN kullanilmiyor", () => {
    // Bilgi amacli ve bilincli: dosya HENUZ silinmedi (asama 10) ama
    // kullanicisi kalmadiysa silinebilir hale geldi demektir. Biri onu
    // yeniden kullanmaya baslarsa bu iddia duser ve karar yeniden
    // verilir.
    const kullanan: string[] = [];
    const tara = (dizin: string) => {
      for (const ad of readdirSync(dizin)) {
        const tam = join(dizin, ad);
        if (statSync(tam).isDirectory()) {
          if (ad === "node_modules" || ad === ".next") continue;
          tara(tam);
          continue;
        }
        if (!ad.endsWith(".tsx") && !ad.endsWith(".ts")) continue;
        if (tam.endsWith("components/tasarim.tsx")) continue;
        if (readFileSync(tam, "utf8").includes('from "@/components/tasarim"')) {
          kullanan.push(tam.slice(KOK.length + 1));
        }
      }
    };
    tara(join(KOK, "app"));
    tara(join(KOK, "components"));
    expect(kullanan, `hâlâ kullanan: ${kullanan.join(", ")}`).toEqual([]);
  });
});
