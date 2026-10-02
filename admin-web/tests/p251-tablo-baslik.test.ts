// (P251 §4) TABLO BASLIKLARI TEK KAYNAKTAN — kaynak taramasi.
//
// Basliklar uc yerde elle yaziliyordu (12 px, ikincil renk, normal
// kalinlik). Simdi ortak `yz-tablo-baslik` sinifi (tasarim-sistemi.css):
// kalin, `--yz-fs-sm` (Buyuk modda buyur), ana metin rengi. Bu kilit:
//   1. sinif CSS'te istenen degerlerle tanimli,
//   2. `Th` ilkeli ve `VeriTablosu` baslik hucresi sinifi tasiyor,
//   3. `TabloBasligi` artik yazi boyu/rengi DAYATMIYOR,
//   4. ui/ disinda ham `<th>` yazan her dosya sinifi tasiyor ya da
//      gerekceli istisna listesinde.
import { readFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { taranacakKaynaklar } from "./tarama";

const KOK = resolve(__dirname, "..");
const oku = (p: string) => readFileSync(join(KOK, p), "utf8");

/** Gerekceli istisnalar: ham `<th>` kullanan ama tablo basligi olmayan yerler. */
const ISTISNA: Record<string, string> = {
  // Vardiya dongusu ONIZLEME izgarasi: pencere icinde sikisik bir matris;
  // satir basliklari kisi adlari, sutunlar gun numaralari. Buyuk punto
  // pencereyi tasirirdi; veri tablosu degil.
  "components/vardiya/dongu-modali.tsx": "onizleme izgarasi",
};

describe("(P251 §4) tablo basligi tek kaynak", () => {
  it("CSS sinifi: kalin, sm punto, ana metin rengi", () => {
    const css = oku("app/tasarim-sistemi.css");
    const m = /\.yz-tablo-baslik\s*\{([^}]*)\}/.exec(css);
    expect(m, "yz-tablo-baslik tanimli degil").not.toBeNull();
    const govde = m![1];
    expect(govde).toMatch(/font-weight:\s*600/);
    expect(govde).toMatch(/font-size:\s*var\(--yz-fs-sm\)/);
    expect(govde).toMatch(/color:\s*var\(--yz-text\)/);
  });

  it("Th ve VeriTablosu basligi ortak sinifi tasir; TabloBasligi stil dayatmaz", () => {
    const ilkel = oku("components/ui/tablo-ilkelleri.tsx");
    expect(ilkel).toMatch(/className=\{`yz-tablo-baslik relative /);
    const thead = /export function TabloBasligi[\s\S]*?<\/thead>/.exec(ilkel)![0];
    expect(thead).not.toMatch(/fontSize|color:/);
    const veri = oku("components/ui/veri-tablosu.tsx");
    expect(veri).toMatch(/BASLIK_SINIFI = "yz-tablo-baslik"/);
    expect(/function BaslikHucresi[\s\S]*?<\/th>/.exec(veri)![0]).toMatch(/BASLIK_SINIFI/);
  });

  it("ui/ disindaki ham <th> ortak sinifi tasir (ya da gerekceli istisna)", () => {
    const ihlal: string[] = [];
    const kokler = [join(KOK, "app"), join(KOK, "components")];
    for (const [yol, kaynak] of taranacakKaynaklar(kokler)) {
      const goreli = relative(KOK, yol).replace(/\\/g, "/");
      if (goreli.startsWith("components/ui/") || ISTISNA[goreli]) continue;
      for (const e of kaynak.matchAll(/<th\b[^>]*>/g)) {
        if (!e[0].includes("yz-tablo-baslik")) ihlal.push(`${goreli}: ${e[0].slice(0, 60)}`);
      }
    }
    expect(ihlal, "ham <th> ortak stil disinda").toEqual([]);
  });
});
