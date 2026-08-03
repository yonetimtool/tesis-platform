// (P123) KAPSAM KILIDI (panel) — maskesiz kalan telefon girdisi BASARISIZLIKTIR.
//
// Mobil tarafin `telefon_alani_kapsam_test.dart` ikizi. Boyle bir gocun
// tipik eksik kalma bicimi: uc girdiden ikisi tasinir, ucuncusu gozden
// kacar ve hicbir test dusmez — cunku o sayfa zaten "calisiyordur".
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

/** `app/` altindaki tum tsx dosyalari. */
function kaynaklar(kok = "app"): string[] {
  const out: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) out.push(...kaynaklar(yol));
    else if (yol.endsWith(".tsx")) out.push(yol);
  }
  return out;
}

/** `//` yorumlarini siler (yorumdaki ornek bulgu sayilmasin). */
const yorumsuz = (s: string) =>
  s
    .split("\n")
    .map((l) => l.replace(/\s*\/\/.*$/, ""))
    .join("\n");

/**
 * Bir dosyadaki telefon girdisi ihlalleri.
 *
 * Mantik AYRI fonksiyonda: kasitli kusurlu bir ornekle sinanabilsin diye.
 * Depoda ihlal kalmadigi icin "gecen" bir tarama calistigini KANITLAMAZ.
 */
export function telefonIhlalleri(kaynak: string, yol: string): string[] {
  const temiz = yorumsuz(kaynak);
  const bulgular: string[] = [];
  // `value={...telefon...}` tasiyan her `<input`.
  const desen = /value=\{[^}]*(?:telefon|phone)[^}]*\}/gi;
  let m: RegExpExecArray | null;
  while ((m = desen.exec(temiz)) !== null) {
    if (m[0].includes("telefonGiris")) continue;
    const satir = temiz.slice(0, m.index).split("\n").length;
    bulgular.push(`${yol}:${satir}  telefon girdisi MASKESIZ`);
  }
  return bulgular;
}

describe("telefon girdisi kapsami", () => {
  it("DEDEKTOR: tarama KASITLI kusuru gorur", () => {
    expect(
      telefonIhlalleri('<input value={form.telefon} />', "ornek.tsx"),
    ).toHaveLength(1);
    expect(
      telefonIhlalleri(
        "<input value={telefonGiris(form.telefon)} />",
        "ornek.tsx",
      ),
    ).toHaveLength(0);
    expect(
      telefonIhlalleri("// ornek: value={form.telefon}", "ornek.tsx"),
    ).toHaveLength(0);
  });

  it("HER telefon girdisi paylasilan bicimlendiriciyi kullanir", () => {
    const bulgular = kaynaklar().flatMap((f) =>
      telefonIhlalleri(readFileSync(f, "utf8"), f),
    );
    expect(bulgular, `Maskesiz telefon girdisi kaldi:\n${bulgular.join("\n")}`)
      .toEqual([]);
  });

  it("EN AZ UC girdi olculuyor (bos kume 'temiz' sayilmasin)", () => {
    // Kapsam kilidinin en sinsi bozulma bicimi: desen degisir, tarama
    // hicbir sey bulamaz ve "gecti" der.
    const sayi = kaynaklar()
      .map((f) => yorumsuz(readFileSync(f, "utf8")))
      .join("\n")
      .match(/value=\{[^}]*(?:telefon|phone)[^}]*\}/gi)?.length ?? 0;
    expect(sayi).toBeGreaterThanOrEqual(3);
  });
});
