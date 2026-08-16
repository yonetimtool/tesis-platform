// (P166 §2) SAYFA ARAMASI — "aidat" yazan kullanici Aidat SAYFASINI bulur.
//
// EN PAHALI SONUC bu dosyada YETKI SIZINTISIDIR: aramanin, kullanicinin
// menude goremedigi bir sayfayi listelemesi. Sizinti sessizdir — kimse
// "arama bana fazla sey gosterdi" diye sikayet etmez, yalnizca gosterir.
// Bu yuzden testin agirligi oradadir.
//
// Ikinci olculen sey, aramanin ISE YARAMASI: Turkce aksan yazmayan
// kullanici ("guvenlik") aksanli basligi ("Güvenlik") bulabilmeli, ve
// sonuclarda once SAYFA ADI eslesenler gelmeli.
import { describe, expect, it } from "vitest";

import { SOZLUKLER, type SozlukAnahtari } from "@/lib/i18n/sozluk";
import {
  menuGruplari,
  ogeBaglantisi,
  profilGorunur,
  sayfaAra,
  PROFIL_OGESI,
} from "@/lib/menu";
import type { Yuzey } from "@/lib/yuzey";

/** Aktif dil TR — cizimde `useT` neyi cozuyorsa test de onu cozer. */
const t = (a: SozlukAnahtari): string => SOZLUKLER.tr[a];

function hrefler(yuzey: Yuzey, rol: string | null, q: string): string[] {
  return sayfaAra(yuzey, rol, q, t, 50).map((s) => ogeBaglantisi(s.oge));
}

describe("(P166 §2) sayfa aramasi calisiyor", () => {
  it("'aidat' Aidat sayfasini bulur", () => {
    expect(hrefler("tesis", "yonetici", "aidat")).toContain("/dues");
  });

  it("'devriye' Devriye Planlari'ni bulur", () => {
    expect(hrefler("tesis", "yonetici", "devriye")).toContain("/patrol-plans");
  });

  it("AKSANSIZ yazim da bulur ('guvenlik' -> 'Güvenlik')", () => {
    // Klavyesinde Turkce harf olmayan ya da acele eden kullanici aksan
    // yazmaz. Bulamamak, aramayi olmayan bir ozellige cevirirdi.
    expect(hrefler("tesis", "yonetici", "guvenlik").length).toBeGreaterThan(0);
  });

  it("BUYUK HARF fark etmez ('AIDAT')", () => {
    expect(hrefler("tesis", "yonetici", "AIDAT")).toContain("/dues");
  });

  it("SORGULU oge de bulunur ve baglantisi sorguyu TASIR", () => {
    // "gelirler" yazan kullanici `/finans?tip=gelir` satirini bulmali;
    // sorgusuz `/finans`a gitmek onu yanlis suzgece dusururdu.
    const vurus = sayfaAra("tesis", "yonetici", "gelirler", t, 50)[0];
    expect(vurus).toBeTruthy();
    expect(ogeBaglantisi(vurus.oge)).toBe("/finans?tip=gelir");
  });

  it("TEK HARF arama yapmaz (gurultu)", () => {
    expect(hrefler("tesis", "yonetici", "a")).toEqual([]);
    expect(hrefler("tesis", "yonetici", " ")).toEqual([]);
  });

  it("ADI ESLESEN, yalniz BOLUMU eslesenden ONCE gelir", () => {
    // "finans" hem `/finans` sayfasinin ADI hem de bir bolum basligi.
    // Sayfa once gelmeli; yoksa kullanici aradigi satiri listenin
    // dibinde arardi.
    expect(hrefler("tesis", "yonetici", "finans")[0]).toBe("/finans");
  });

  it("SINIR uygulanir (ust bar acilir listesi tasmaz)", () => {
    expect(sayfaAra("tesis", "yonetici", "ar", t).length).toBeLessThanOrEqual(6);
  });
});

/** Rolde menude GORUNEN rotalar — sizinti testinin tabani. */
function rolMenusu(yuzey: Yuzey, rol: string | null): Set<string> {
  // Bilerek `menuGruplari` uzerinden: taban, kenar cubugunun cizdigi
  // kumenin ta kendisi olmali.
  const kume = new Set(
    menuGruplari(yuzey, rol).flatMap((g) => g.ogeler.map((o) => o.href)),
  );
  if (profilGorunur(yuzey, rol)) kume.add(PROFIL_OGESI.href);
  return kume;
}

/**
 * Genis tarama icin iki harflik parcalar. Amac tek tek sayfa saymak degil,
 * aramanin donebilecegi kumeyi mumkun oldugunca DOLDURMAK.
 */
const PARCALAR = [
  "ar", "er", "in", "an", "la", "ka", "de", "ta", "ma", "ne", "ri", "si",
  "ge", "ba", "ku", "yo", "od", "fi", "ai", "ra", "pa", "gu", "te", "il",
  "ol", "vi", "se", "bi", "da", "so", "ay", "et", "ic", "uy", "ze", "ka",
];

describe("(P166 §2) YETKI SIZINTISI YOK", () => {
  it("SAKIN, yonetim sayfalarini aramada GORMEZ", () => {
    for (const q of ["kullanici", "denetim", "kvkk", "yetki", "tesisler"]) {
      const sonuc = hrefler("tesis", "resident", q);
      for (const h of ["/users", "/audit", "/kvkk", "/yetki", "/tenants"]) {
        expect(sonuc, `${q} -> ${h}`).not.toContain(h);
      }
    }
  });

  it("ARAMA KUMESI, MENU KUMESININ ALT KUMESIDIR — her rol icin", () => {
    // Tek tek sayfa saymaktan daha guclu bir kilit: aramanin
    // dondurebilecegi HER sonuc menude de gorunmek zorunda. Yeni bir
    // sayfa eklendiginde bu test kendiliginden onu da kapsar.
    const ciftler: readonly (readonly [Yuzey, string | null])[] = [
      ["tesis", "yonetici"],
      ["tesis", "denetci"],
      ["tesis", "resident"],
      ["tesis", "gorevli"],
      ["tesis", null],
      ["platform", "admin"],
      ["platform", "yonetici"],
    ];

    for (const [yuzey, rol] of ciftler) {
      const izinli = rolMenusu(yuzey, rol);
      for (const parca of PARCALAR) {
        for (const s of sayfaAra(yuzey, rol, parca, t, 200)) {
          expect(
            izinli.has(s.oge.href),
            `${yuzey}/${rol} aramada sizan sayfa: ${s.oge.href}`,
          ).toBe(true);
        }
      }
    }
  });

  it("TARAMA GERCEKTEN BIR SEY BULUYOR (test bos gecmesin)", () => {
    // Yukaridaki alt-kume testi, arama HIC sonuc dondurmese de gecerdi.
    let n = 0;
    for (const parca of PARCALAR) {
      n += sayfaAra("tesis", "yonetici", parca, t, 200).length;
    }
    expect(n).toBeGreaterThan(30);
  });
});
