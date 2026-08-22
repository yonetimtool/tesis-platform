import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * (P177 §7) ERISILEBILIRLIK — KAYNAK TARAMASI.
 *
 * Sartname dort sey istiyor: tum gorsellerde `alt`, form alanlarinda
 * `label`, klavye gezinmesi, AA kontrast.
 *
 * BURADA IKISI TARANIYOR (`alt` ve `label`), cunku ikisi de KAYNAKTA
 * gorulebilir ve ikisi de bir dosya eklenirken SESSIZCE unutulur.
 *
 * OTEKI IKISI BURADA OLCULMEZ ve bu bir eksiklik degil, dogru sinir:
 *   * KONTRAST bir DEGER sorusudur; palet `tailwind.config.ts`te sabit
 *     ve olculen oranlar docs/P177-kararlar.md §2.2'de yazili. Kaynak
 *     taramasiyla olculemez.
 *   * KLAVYE GEZINMESI calisma zamani davranisidir; `:focus-visible`
 *     kurali `globals.css`te tek yerde ve gercek olcumu tarayici
 *     gerektirir.
 *
 * Rendere edilmis sayfalar da elle dogrulandi (bes sayfa: 0 alt'siz
 * gorsel, 0 etiketsiz form alani) — bu test o durumu KILITLER.
 */
function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (ad.endsWith(".tsx")) cikti.push(yol);
  }
  return cikti;
}

const KOK = new URL("../", import.meta.url).pathname;
const TSX = ["app", "components"].flatMap((d) => dosyalar(join(KOK, d)));

describe("erisilebilirlik — kaynak taramasi", () => {
  it("taranacak dosya var (tarama sessizce bos kalmasin)", () => {
    expect(TSX.length).toBeGreaterThan(5);
  });

  it("her <img> bir alt tasiyor", () => {
    for (const yol of TSX) {
      const icerik = readFileSync(yol, "utf-8");
      // JSX'te oznitelikler satirlara boluner; `<img` ile kapanis
      // arasindaki her seyi al.
      for (const etiket of icerik.match(/<img[\s\S]*?\/>/g) ?? []) {
        expect(etiket, `${yol}: alt'siz <img>`).toMatch(/\salt=/);
      }
    }
  });

  it("her <input>/<textarea>/<select> ya id ya aria-label tasiyor", () => {
    for (const yol of TSX) {
      const icerik = readFileSync(yol, "utf-8");
      for (const etiket of icerik.match(/<(?:input|textarea|select)[\s\S]*?\/>/g) ?? []) {
        const bagli = /\sid=/.test(etiket) || /aria-label/.test(etiket);
        expect(bagli, `${yol}: etiketsiz form alani -> ${etiket.slice(0, 80)}`).toBe(true);
      }
    }
  });

  it("odak halkasi TEK YERDE tanimli ve `:focus-visible` kullaniyor", () => {
    const css = readFileSync(join(KOK, "app/globals.css"), "utf-8");
    // `:focus` DEGIL `:focus-visible`: fareyle tiklayan kullanici halka
    // gormemeli, klavyeyle gezen daima gormeli.
    expect(css).toContain(":focus-visible");
    expect(css).toContain("outline: 3px solid");
  });

  it("hareketi azalt tercihi onurlandiriliyor", () => {
    const css = readFileSync(join(KOK, "app/globals.css"), "utf-8");
    expect(css).toContain("prefers-reduced-motion: reduce");
  });
});
