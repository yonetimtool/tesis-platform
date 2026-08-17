// (P167 Asama 4) FINANSAL ISLEMLER — SEKIZ SAYFA, kume duzeyinde.
//
// Brief §4: "Her biri AYRI sayfa, alt baslik olarak menude."
//
// EN PAHALI SONUCLAR:
//  1. MENUDE GORUNUP ACILMAYAN SAYFA. Rota `TESIS_ROTALARI`na eklenmezse
//     `rotaYuzeyi` `null` doner ve oge HICBIR ROLDE gorunmez — sessizce.
//     Tersi de mumkun: rota eklenip `ROTA_ROLLERI`ye yazilmazsa sayfa
//     gorunmez ama dosya durur ve kimse fark etmez.
//  2. YETKI SIZINTISI. Sekizi de YAZMA ekrani; denetciye acilmalari, ona
//     basamayacagi dugmelerle dolu bir ekran gostermek olurdu.
//  3. ESKI SORGU ROTALARININ SESSIZCE OLMESI. P154'un `/finans?tip=...`
//     satirlari kalkti; yerlerine gercek sayfalar geldi.
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { menuGruplari, ogeBaglantisi } from "@/lib/menu";
import { ROTA_ROLLERI, TESIS_ROTALARI, rotaRoldeGorunur, rotaYuzeyi } from "@/lib/yuzey";

const KOK = resolve(__dirname, "..");

/** Brief §4'un sekiz sayfasi — rota + dosya yolu. */
const SAYFALAR = [
  { rota: "/finans/borclandirmalar", dizin: "borclandirmalar" },
  { rota: "/finans/tahsilatlar", dizin: "tahsilatlar" },
  { rota: "/finans/giderler", dizin: "giderler" },
  { rota: "/finans/gelirler", dizin: "gelirler" },
  { rota: "/finans/virman", dizin: "virman" },
  { rota: "/finans/iade", dizin: "iade" },
  { rota: "/finans/acilis", dizin: "acilis" },
  // §4.8 ICRA zaten kendi sayfasindaydi (P154); brief'in ekledigi sey
  // OLUSTURMA akisiydi, sayfa degil.
  { rota: "/icra", dizin: null },
] as const;

describe("(P167 §4) sekiz sayfa GERCEKTEN var", () => {
  it("her rotanin DOSYASI var", () => {
    for (const s of SAYFALAR) {
      if (!s.dizin) continue;
      const yol = join(KOK, "app", "(protected)", "finans", s.dizin, "page.tsx");
      expect(existsSync(yol), s.rota).toBe(true);
    }
  });

  it("her rota TESIS YUZEYINDE bildirilmis", () => {
    // Eksikse `rotaYuzeyi` `null` doner ve oge HICBIR ROLDE gorunmez.
    for (const s of SAYFALAR) {
      expect(rotaYuzeyi(s.rota), s.rota).toBe("tesis");
    }
  });

  it("her rotanin ROL KUMESI bildirilmis", () => {
    for (const s of SAYFALAR) {
      expect(ROTA_ROLLERI[s.rota], s.rota).toBeTruthy();
    }
  });

  it("hepsi MENUDE, FINANS bolumunun altinda", () => {
    const finans = menuGruplari("tesis", "yonetici").find((g) => g.id === "finans");
    const hrefler = (finans?.ogeler ?? []).map((o) => o.href);
    for (const s of SAYFALAR) {
      expect(hrefler, s.rota).toContain(s.rota);
    }
  });
});

describe("(P167 §4) yetki", () => {
  it("YONETICI ve ADMIN gorur", () => {
    for (const s of SAYFALAR) {
      if (s.rota === "/icra") continue; // icra denetciye de acik (P154)
      expect(rotaRoldeGorunur(s.rota, "yonetici"), s.rota).toBe(true);
      expect(rotaRoldeGorunur(s.rota, "admin"), s.rota).toBe(true);
    }
  });

  it("DENETCI GORMEZ — sekizi de YAZMA ekrani", () => {
    // Sekizi de "+ Yeni" dugmesi tasiyan YAZMA ekrani; denetciye acmak,
    // basamayacagi dugmelerle dolu bir sayfa gostermek olurdu.
    for (const s of SAYFALAR) {
      if (s.rota === "/icra") continue;
      expect(rotaRoldeGorunur(s.rota, "denetci"), s.rota).toBe(false);
    }
  });

  it("DENETCININ MALI OKUMA YOLU ACIK KALDI", () => {
    // Bu testin isi yukaridakini DENGELEMEK: "denetci gormez" tek basina
    // olculseydi, ona hicbir mali ekran vermemek de gecerdi ve rol ise
    // yaramaz hale gelirdi.
    //
    // OLCULEN GERCEK: denetci `/raporlar` (12 raporluk katalog) ve
    // `/icra`yi gorur. `/finans` ONA KAPALI ve bu P154'ten beri boyle —
    // bu tur o karari DEGISTIRMEDI. (Uc `/finans/hareketler` denetciye
    // acik; kapali olan yalnizca MENU girisi. Ayrimi burada not etmek
    // gerekiyor cunku ikisi kolayca karistiriliyor.)
    expect(rotaRoldeGorunur("/raporlar", "denetci")).toBe(true);
    expect(rotaRoldeGorunur("/icra", "denetci")).toBe(true);
    expect(rotaRoldeGorunur("/finans", "denetci")).toBe(false);
  });

  it("SAKIN ve SAHA rolleri GORMEZ", () => {
    for (const rol of ["resident", "security", "tesis_gorevlisi"]) {
      for (const s of SAYFALAR) {
        expect(rotaRoldeGorunur(s.rota, rol), `${rol}/${s.rota}`).toBe(false);
      }
    }
  });
});

describe("(P167 §4) eski sorgu rotalari kalkti", () => {
  it("`/finans?tip=...` satirlari MENUDE YOK", () => {
    // P154'te bunlar tek sayfanin suzgecleriydi. Brief §4 onlari gercek
    // sayfalara cevirdi; ikisini birden tutmak, ayni listeye iki farkli
    // yoldan giden bir menu olurdu.
    const hepsi = menuGruplari("tesis", "yonetici").flatMap((g) =>
      g.ogeler.map(ogeBaglantisi),
    );
    for (const tip of ["tahsilat", "gelir", "gider", "virman", "iade", "acilis"]) {
      expect(hepsi, tip).not.toContain(`/finans?tip=${tip}`);
    }
  });

  it("`/finans` TUM HAREKETLER defteri olarak KALDI", () => {
    // Eski yer imleri kirilmasin ve butun hareketleri tek listede gormek
    // hala anlamli olsun diye.
    expect(menuGruplari("tesis", "yonetici")
      .flatMap((g) => g.ogeler.map((o) => o.href))).toContain("/finans");
    expect((TESIS_ROTALARI as readonly string[])).toContain("/finans");
  });
});
