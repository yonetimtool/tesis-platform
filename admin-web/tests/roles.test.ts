// Rol modeli contracts/auth.md §4'un UI aynasidir. Buradaki sapma kullanici
// yonetimi/gorev atama ekranlarinda YANLIS rol sunar; yetki karari backend'de
// olsa da kullaniciya yapamayacagi bir sey teklif edilmis olur.
import { describe, expect, it } from "vitest";

import { ROLE_OPTIONS, ROLE_STYLE, SAHA_ROLLERI, roleLabel } from "@/lib/roles";
import type { UserRole } from "@/lib/types";

/** Sozlesmedeki BILINEN 5 rol (auth.md §4). */
const BILINEN_ROLLER: UserRole[] = [
  "admin",
  "yonetici",
  "security",
  "tesis_gorevlisi",
  "resident",
];

describe("ROLE_OPTIONS", () => {
  it("bilinen 5 rolun TAMAMINI ve fazlasini DEGIL icerir", () => {
    expect(ROLE_OPTIONS.map((r) => r.value).sort()).toEqual(
      [...BILINEN_ROLLER].sort(),
    );
  });

  it("her rolun bos olmayan, TEKIL bir etiketi var", () => {
    const etiketler = ROLE_OPTIONS.map((r) => r.label);
    expect(etiketler.every((l) => l.trim().length > 0)).toBe(true);
    expect(new Set(etiketler).size).toBe(etiketler.length);
  });

  it("ROLE_STYLE her rol icin bir sinif tasir (rozet renksiz kalmaz)", () => {
    for (const r of BILINEN_ROLLER) {
      expect(ROLE_STYLE[r], r).toBeTruthy();
    }
  });
});

describe("roleLabel", () => {
  it("bilinen rolu Turkce etiketine cevirir", () => {
    expect(roleLabel("admin")).toBe("Platform Admin");
    expect(roleLabel("tesis_gorevlisi")).toBe("Tesis Görevlisi");
  });

  it("BILINMEYEN rol: ham deger gosterilir (bos/undefined DEGIL)", () => {
    // Backend yeni bir rol eklerse panel patlamaz, tel degerini gosterir.
    expect(roleLabel("gelecek_rol")).toBe("gelecek_rol");
    expect(roleLabel("")).toBe("");
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
