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
