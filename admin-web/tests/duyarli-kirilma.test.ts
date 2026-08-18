// (P169 §1) KIRILMA NOKTASI SISTEMI — TEK KAYNAK KILIDI.
//
// =========================================================================
// KILITLENEN KUSUR SINIFI
// =========================================================================
// Kirilma noktalari IKI YERDE yasiyor: Tailwind sinif onekleri ve JS
// davranisi (`useBant`). Ikisi ayrisirsa, tablo 639 px'te kart moduna
// gecer ama izgara 640'ta kirilir — arada bir bantta ekran BOZUK gorunur
// ve sebebini bulmak icin iki ayri dosyayi karsilastirmak gerekir.
//
// Bu test o esitligi `tailwind.config.ts` KAYNAGINDAN okuyarak kilitler.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  BANTLAR,
  BANT_ESIGI,
  bantCoz,
  bantSorgusu,
} from "@/lib/kirilma-noktasi";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** Tailwind'in ETKIN kirilma noktalari: varsayilanlar + `extend.screens`. */
function tailwindEsikleri(): Record<string, number> {
  const kaynak = readFileSync(join(KOK, "tailwind.config.ts"), "utf8");
  // Tailwind VARSAYILANLARI (v3): degistirilmeyenler bunlardir.
  const etkin: Record<string, number> = { sm: 640, md: 768, lg: 1024, xl: 1280 };
  // SUSLU PARANTEZ DENGELENIR: `screens` blogu ic icine giren girisler
  // tasiyor (`coarse: { raw: "..." }`). Tembel bir `[\s\S]*?` ILK ic
  // parantezde durur ve ondan SONRAKI esikleri hic gormez — testi
  // sessizce yanlis yapardi (ilk yazimda tam bu oldu).
  const bas = kaynak.indexOf("screens: {");
  if (bas >= 0) {
    let derinlik = 0;
    let son = bas;
    for (let i = kaynak.indexOf("{", bas); i < kaynak.length; i++) {
      if (kaynak[i] === "{") derinlik++;
      else if (kaynak[i] === "}") {
        derinlik--;
        if (derinlik === 0) {
          son = i;
          break;
        }
      }
    }
    for (const m of kaynak.slice(bas, son).matchAll(/(\w+):\s*"(\d+)px"/g)) {
      etkin[m[1]] = Number(m[2]);
    }
  }
  return etkin;
}

describe("(P169 §1) kirilma noktasi sistemi", () => {
  it("olcum BOSA DUSMUYOR — config okunabiliyor", () => {
    expect(Object.keys(tailwindEsikleri()).length).toBeGreaterThanOrEqual(4);
  });

  it("BRIEF'IN SINIRLARI: 640 · 1024 · 1440", () => {
    expect(BANT_ESIGI.sm).toBe(0);
    expect(BANT_ESIGI.md).toBe(640);
    expect(BANT_ESIGI.lg).toBe(1024);
    expect(BANT_ESIGI.xl).toBe(1440);
  });

  it("JS ile TAILWIND ayni sayilari tasir", () => {
    // Bu testin ASIL isi: iki kaynagin ayrismasini imkansiz kilmak.
    const tw = tailwindEsikleri();
    expect(tw.sm).toBe(BANT_ESIGI.md); // `sm:` oneki 640'ta baslar
    expect(tw.lg).toBe(BANT_ESIGI.lg);
    expect(tw.xl).toBe(BANT_ESIGI.xl);
  });

  it("bant cozumlemesi brief'in bantlariyla ayni", () => {
    // Brief'in test genislikleri.
    expect(bantCoz(360)).toBe("sm");
    expect(bantCoz(390)).toBe("sm");
    expect(bantCoz(430)).toBe("sm");
    expect(bantCoz(639)).toBe("sm");
    expect(bantCoz(640)).toBe("md");
    expect(bantCoz(768)).toBe("md");
    expect(bantCoz(1023)).toBe("md");
    expect(bantCoz(1024)).toBe("lg");
    expect(bantCoz(1439)).toBe("lg");
    expect(bantCoz(1440)).toBe("xl");
  });

  it("bantlar BITISIK — arada bosluk YOK", () => {
    // Bir piksellik bosluk, o genislikte HICBIR bandin eslesmemesi ve
    // duzenin tanimsiz kalmasi demekti.
    const artan = [...BANTLAR].reverse();
    for (let i = 0; i < artan.length - 1; i++) {
      const sorgu = bantSorgusu(artan[i]);
      const ust = /max-width: (\d+)px/.exec(sorgu);
      expect(ust, artan[i]).not.toBeNull();
      expect(Number(ust![1]) + 1).toBe(BANT_ESIGI[artan[i + 1]]);
    }
  });

  it("en genis bandin UST SINIRI YOK", () => {
    expect(bantSorgusu("xl")).toBe("(min-width: 1440px)");
  });

  it("en dar bant `max-width` ile sorulur", () => {
    // `min-width: 0` yazsaydik sorgu HER ZAMAN eslesirdi ve bant
    // cozumlemesi anlamsizlasirdi.
    expect(bantSorgusu("sm")).toBe("(max-width: 639px)");
  });
});
