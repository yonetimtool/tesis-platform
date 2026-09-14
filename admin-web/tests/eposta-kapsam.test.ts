// (P233 §4) E-POSTA KAPSAM KILIDI — dogrulamasiz bir e-posta alani
// BASARISIZLIKTIR.
//
// OLCULEN DURUM: backend `EmailStr` ZATEN yerel>64, toplam>254 ve bozuk
// bicimi reddediyordu (olculdu). Yani kural vardi; eksik olan kuralin
// KULLANICIYA SOYLENMESIYDI — alti web alaninin hicbirinde uzunluk siniri
// ve alan-ici hata yoktu. Kullanici formu doldurup GONDERDIKTEN sonra
// jenerik bir hata goruyordu.
//
// KABUL EDILEN IKI YOL (ucuncusu YOK):
//   1. `<EpostaAlani>` — ortak bilesen.
//   2. `epostaHataMetni(...)` cagrisi — bileseni oturmayan ozel duzenler
//      (profil: yanda rozet + altta kod kutusu; giris: kendi stil dili).
//
// Neden ikisi de: bileseni HER YERE dayatmak, `AlanSarmal`in tek-cocuk
// sozlesmesine sigmayan duzenleri bozardi; yalniz cagriyi kabul etmek ise
// yeni formlarda yine unutulurdu.
import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";

/**
 * `//` VE `/* *​/` yorumlarini siler.
 *
 * BLOK YORUMLARI DA: ilk yazimda yalniz `//` soyuluyordu ve `GirisFormu`
 * YANLIS ALARM verdi — orada `type="email"` bir BLOK YORUMUN icinde
 * geciyor ("`type="text"` BILINCLI: `type="email"` tarayicinin kendi
 * bicim denetimini devreye sokar..."). Yani kilit gercek olmayan bir
 * kusur bildiriyordu.
 */
function yorumsuz(s: string): string {
  return s
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .split("\n")
    .map((l) => l.replace(/\s*\/\/.*$/, ""))
    .join("\n");
}

/**
 * Bir dosyadaki dogrulamasiz e-posta girdileri.
 *
 * Mantik AYRI fonksiyonda: kasitli kusurlu bir ornekle sinanabilsin diye.
 * Depoda ihlal kalmadigi icin "gecen" bir tarama calistigini KANITLAMAZ.
 */
export function epostaIhlalleri(kaynak: string, yol: string): string[] {
  const temiz = yorumsuz(kaynak);
  const bulgular: string[] = [];
  const korumali =
    /epostaHataMetni|epostaHatasi|EpostaAlani/.test(temiz);
  for (const m of temiz.matchAll(/type="email"|inputMode="email"/g)) {
    if (korumali) continue;
    const satir = temiz.slice(0, m.index).split("\n").length;
    bulgular.push(`${yol}:${satir}  e-posta alani DOGRULAMASIZ`);
  }
  return bulgular;
}

describe("(P233 §4) e-posta alani kapsami", () => {
  it("DEDEKTOR: tarama KASITLI kusuru gorur", () => {
    expect(
      epostaIhlalleri('<input type="email" value={x} />', "ornek.tsx"),
    ).toHaveLength(1);
    expect(
      epostaIhlalleri(
        '<input type="email" value={x} onBlur={() => epostaHataMetni(x, true, t)} />',
        "ornek.tsx",
      ),
    ).toHaveLength(0);
    expect(
      epostaIhlalleri("<EpostaAlani deger={x} />", "ornek.tsx"),
    ).toHaveLength(0);
    expect(
      epostaIhlalleri('// ornek: type="email"', "ornek.tsx"),
    ).toHaveLength(0);
    // BLOK YORUM da bulgu sayilmaz (GirisFormu yanlis alarmi).
    expect(
      epostaIhlalleri('/* aciklama: type="email" kullanmiyoruz */', "ornek.tsx"),
    ).toHaveLength(0);
  });

  it("HER e-posta alani dogrulamaya bagli", () => {
    const bulgular = taranacakDosyalar(["app", "components"]).flatMap((f) =>
      epostaIhlalleri(readFileSync(f, "utf8"), f),
    );
    expect(
      bulgular,
      `Dogrulamasiz e-posta alani kaldi:\n${bulgular.join("\n")}`,
    ).toEqual([]);
  });

  it("EN AZ DORT alan olculuyor (bos kume 'temiz' sayilmasin)", () => {
    // Kapsam kilidinin en sinsi bozulma bicimi: desen degisir, tarama
    // hicbir sey bulamaz ve "gecti" der.
    const metin = taranacakDosyalar(["app", "components"])
      .map((f) => yorumsuz(readFileSync(f, "utf8")))
      .join("\n");
    const bilesen = metin.match(/<EpostaAlani\b/g)?.length ?? 0;
    const cagri = metin.match(/epostaHataMetni\(/g)?.length ?? 0;
    expect(bilesen + cagri).toBeGreaterThanOrEqual(4);
    expect(bilesen).toBeGreaterThanOrEqual(3);
  });
});
