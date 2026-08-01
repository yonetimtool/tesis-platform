// Rol modeli contracts/auth.md §4'un UI aynasidir. Buradaki sapma kullanici
// yonetimi/gorev atama ekranlarinda YANLIS rol sunar; yetki karari backend'de
// olsa da kullaniciya yapamayacagi bir sey teklif edilmis olur.
import { describe, expect, it } from "vitest";

import { ROLE_OPTIONS, ROLE_STYLE, SAHA_ROLLERI, rolAdi, roleAnahtari } from "@/lib/roles";
import { SOZLUKLER } from "@/lib/i18n/sozluk";
import type { UserRole } from "@/lib/types";

/** Sozlesmedeki BILINEN 6 rol (auth.md §4; P35 ile guvenlik_amiri eklendi). */
const BILINEN_ROLLER: UserRole[] = [
  "admin",
  "yonetici",
  "security",
  "tesis_gorevlisi",
  "resident",
  "guvenlik_amiri",
];

describe("ROLE_OPTIONS", () => {
  it("bilinen 6 rolun TAMAMINI ve fazlasini DEGIL icerir", () => {
    expect(ROLE_OPTIONS.map((r) => r.value).sort()).toEqual(
      [...BILINEN_ROLLER].sort(),
    );
  });

  it("her rolun TEKIL bir sozluk ANAHTARI var (metin degil kimlik)", () => {
    const anahtarlar = ROLE_OPTIONS.map((r) => r.anahtar);
    expect(new Set(anahtarlar).size).toBe(anahtarlar.length);
    // Anahtarlar 7 dilde de bos olmayan, TEKIL metin verir.
    for (const dil of ["tr", "en", "ar"] as const) {
      const etiketler = anahtarlar.map((a) => SOZLUKLER[dil][a]);
      expect(etiketler.every((l) => l.trim().length > 0), dil).toBe(true);
      expect(new Set(etiketler).size, dil).toBe(etiketler.length);
    }
  });

  it("ROLE_STYLE her rol icin bir sinif tasir (rozet renksiz kalmaz)", () => {
    for (const r of BILINEN_ROLLER) {
      expect(ROLE_STYLE[r], r).toBeTruthy();
    }
  });
});

describe("rolAdi (tur 17: kimlik -> aktif dil)", () => {
  const t = (a: keyof (typeof SOZLUKLER)["tr"]) => SOZLUKLER.en[a];

  it("bilinen rolu AKTIF DILDEKI adina cevirir", () => {
    expect(roleAnahtari("admin")).toBe("rolPlatformAdmin");
    expect(rolAdi(t, "admin")).toBe(SOZLUKLER.en.rolPlatformAdmin);
    expect(rolAdi((a) => SOZLUKLER.tr[a], "tesis_gorevlisi")).toBe(
      "Tesis Görevlisi",
    );
  });

  it("BILINMEYEN rol: ham deger gosterilir (bos/undefined DEGIL)", () => {
    // Backend yeni bir rol eklerse panel patlamaz, tel degerini gosterir.
    expect(roleAnahtari("gelecek_rol")).toBeNull();
    expect(rolAdi(t, "gelecek_rol")).toBe("gelecek_rol");
    expect(rolAdi(t, "")).toBe("");
  });
});

describe("SAHA_ROLLERI (gorev atanabilir roller)", () => {
  it("YALNIZ security + tesis_gorevlisi", () => {
    expect([...SAHA_ROLLERI].sort()).toEqual(["security", "tesis_gorevlisi"]);
  });

  it("yonetici gorev ALMAZ (atar), resident ve admin de alamaz", () => {
    for (const r of ["yonetici", "resident", "admin"] as UserRole[]) {
      expect(SAHA_ROLLERI).not.toContain(r);
    }
  });

  it("saha rolleri bilinen roller kumesinin alt kumesidir", () => {
    for (const r of SAHA_ROLLERI) expect(BILINEN_ROLLER).toContain(r);
  });
});

// (P80) ROL LISTESI SUNUCUYLA ORTUSUR — capraz bag.
//
// `ROLE_OPTIONS` panelin rol listesidir: acilir menuleri doldurur ve
// `rolAdi` cevirisini saglar. Sunucu `user_role` enum'una YENI bir deger
// eklerse ve bu liste guncellenmezse iki sey birden bozulur:
//   * yeni rol acilir menude HIC gorunmez (yonetici o rolu ATAYAMAZ),
//   * mevcut kayitlarda rol adi HAM tel degeriyle cizilir — P66'da
//     denetim kaydinda tam bu oldu.
// Ikisi de SESSIZDIR: hicbir sey patlamaz, panel eksik calisir.
//
// Bag tek yonlu DEGIL: fazladan bir deger de sizintidir (sunucunun
// tanimadigi bir rol atanmaya calisilirsa istek 422 doner ve kullanici
// nedenini anlamaz).
import { readFileSync } from "node:fs";
import { join } from "node:path";

describe("rol listesi sunucu enum'uyla ortusur (P80)", () => {
  it("ROLE_OPTIONS degerleri = backend USER_ROLE degerleri", () => {
    const kaynak = readFileSync(
      join(__dirname, "..", "..", "backend", "app", "models.py"),
      "utf8",
    );
    const blok = /USER_ROLE = ENUM\(([\s\S]*?)name="user_role"/.exec(kaynak);
    expect(blok, "backend/app/models.py icinde USER_ROLE bulunamadi").not.toBeNull();

    // Yorum satirlari atilir; kalanlardan tirnak icindeki degerler alinir.
    const sunucu = (blok as RegExpExecArray)[1]
      .split("\n")
      .filter((l) => !/^\s*#/.test(l))
      .join("\n")
      .match(/"([a-z_]+)"/g)!
      .map((x) => x.slice(1, -1));

    expect([...ROLE_OPTIONS.map((r) => r.value)].sort()).toEqual(
      [...sunucu].sort(),
    );
  });
});
