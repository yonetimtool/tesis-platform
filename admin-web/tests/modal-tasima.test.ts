// (P161) MODAL TASIMASI — KILIT.
//
// Brief: "tum olusturma ve duzenleme islemleri ekranin ortasinda acilan
// bir modal icinde yapilacak, istisnasiz" ve "silme islemleri icin ayri
// bir onay diyalogu".
//
// Tasima bir kereye mahsus bir istir; KILIT olmazsa bir sonraki ekran
// yine sayfa icine form koyar ve dil ikiye bolunur. Bu dosya iki seyi
// olcer:
//
//   1. `app/(protected)` altinda `<form onSubmit>` YALNIZ bir `<Modal>`
//      icinde olabilir.
//   2. Yikici onaylar tarayicinin `confirm()`u ile SORULAMAZ — temayi
//      tanimaz, tehlikeyi anlatamaz, "ne silinecek"i bicimleyemez.
//
// Ikisi de kaynak tarama; calisan sunucuya ihtiyac yok.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = new URL("../app/(protected)", import.meta.url).pathname;

function sayfalar(dizin: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(dizin)) {
    const yol = join(dizin, ad);
    if (statSync(yol).isDirectory()) cikti.push(...sayfalar(yol));
    else if (ad.endsWith(".tsx")) cikti.push(yol);
  }
  return cikti;
}

const DOSYALAR = sayfalar(KOK);

/** Yorumlari cikarir — tarayici KODU olcer, kendi gerekcemizi degil. */
function yorumsuz(kaynak: string): string {
  // Uzunlugu KORUYARAK bosluga cevirir ki satir/sutun numaralari kaysin.
  return kaynak
    .replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, " "))
    .replace(/\/\/[^\n]*/g, (m) => " ".repeat(m.length));
}

/**
 * SAYFA ICINDE KALMASI DOGRU OLAN FORMLAR — gerekcesiyle.
 *
 * Brief "olusturma ve duzenleme" der. Asagidakiler ne kayit olusturur ne
 * de bir kaydi duzenler; sayfanin KENDISIDIR:
 *
 *   - `reports/*`  : rapor SUZGECI ("Calistir"). Modala almak, raporu
 *                    her daralttiginda diyalog acmak olurdu.
 *   - `settings`   : ayar sayfasinin govdesi zaten formdur; bir dugme
 *                    arkasina saklamak sayfayi bosaltirdi.
 */
const SAYFA_ICI_KALIR = new Set([
  "reports/dues/page.tsx",
  "reports/patrols/page.tsx",
  "reports/tasks/page.tsx",
  "settings/page.tsx",
]);

/** `i` konumundaki dugum bir `<Modal>` icinde mi? */
function modalIcinde(kaynak: string, i: number): boolean {
  return (
    kaynak.lastIndexOf("<Modal", 0 + i) > kaynak.lastIndexOf("</Modal>", 0 + i)
  );
}

describe("(P161) modal tasimasi kilidi", () => {
  it("EN AZ bir sayfa taranmis olmali (tarayici sessizce bosa dusmesin)", () => {
    expect(DOSYALAR.length).toBeGreaterThan(20);
  });

  it("SAYFA ICINDE form acilmaz — hepsi Modal icinde", () => {
    const bulgular: string[] = [];
    for (const yol of DOSYALAR) {
      const goreli = yol.slice(KOK.length + 1);
      if (SAYFA_ICI_KALIR.has(goreli)) continue;
      const kaynak = yorumsuz(readFileSync(yol, "utf8"));
      for (const m of kaynak.matchAll(/<form\b[^>]*onSubmit/g)) {
        if (modalIcinde(kaynak, m.index)) continue;
        bulgular.push(
          `${goreli}:${kaynak.slice(0, m.index).split("\n").length}`,
        );
      }
    }
    expect(bulgular, "sayfa ici form kaldi").toEqual([]);
  });

  it("YIKICI ONAY tarayicinin confirm()'u ile sorulmaz", () => {
    const bulgular: string[] = [];
    for (const yol of DOSYALAR) {
      const kaynak = yorumsuz(readFileSync(yol, "utf8"));
      for (const m of kaynak.matchAll(/\bconfirm\s*\(/g)) {
        // `setConfirmAd(` gibi adlar yakalanmasin: onunde nokta/harf yok.
        const onceki = kaynak[m.index - 1];
        if (onceki && /[\w$]/.test(onceki)) continue;
        bulgular.push(
          `${yol.slice(KOK.length + 1)}:${kaynak.slice(0, m.index).split("\n").length}`,
        );
      }
    }
    expect(bulgular, "yerel confirm() kaldi — useOnay kullanin").toEqual([]);
  });
});
