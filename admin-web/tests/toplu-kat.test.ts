// (P162 §4.1) TOPLU KAT/DAIRE OLUSTURMA — KOK NEDEN KILIDI.
//
// SIKAYET: "toplu kat olusturma 'Bir hata olustu' veriyor."
//
// OLCULDU (tahmin edilmedi): sunucudaki `UnitBulkCreate.blok` alani
// `^[A-Za-z0-9]+$` kalibina bagli. Kullanici "A Blok" ya da "B-1"
// yazdiginda istek 422 donuyor. Sunucu bunu `error.details[]` icinde
// ACIKCA soyluyor ama istemci yalnizca `error.message`i okuyup gerisini
// atiyordu; ekranda kalan tek cumle genel bir hata oluyordu.
//
// KISITLAMA SUNUCUDA KALDI ve bu DOGRU: daire numarasi `{blok}-{n}` diye
// kuruluyor ve daire no kalibi (`^[A-Za-z0-9-]+$`) bosluk kabul etmiyor —
// yani bosluklu bir blok, gecersiz bir daire numarasi uretirdi. API
// sozlesmesi degistirilmedi (kilitli kural).
//
// BU DOSYA IKI SEYI KILITLER:
//   1. Istemcideki kalip ile SUNUCUDAKI kalip AYNI kalsin. Ayrisirlarsa
//      ya kullanici gereksiz yere engellenir ya da yine anlamsiz bir 422
//      alir.
//   2. Alan duzeyindeki sunucu ayrintisi EKRANA ULASSIN.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { ApiHatasi, alanliHataMetni } from "@/lib/client";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SUNUCU_SEMA = readFileSync(
  join(KOK, "..", "backend", "app", "schemas.py"),
  "utf8",
);
// (P163 §4) TOPLU OLUSTURMA BINA DUZENLEME'YE TASINDI. Kalip kontrolu de
// oraya bakiyor — testin niyeti (istemci ile sunucu kalibi AYNI kalsin)
// degismedi, yalnizca dosya degisti.
const UNITS_SAYFASI = readFileSync(
  join(KOK, "app", "(protected)", "building-editor", "page.tsx"),
  "utf8",
);

describe("(P162) blok kalibi — istemci ve sunucu AYNI", () => {
  it("sunucu kalibi hala `^[A-Za-z0-9]+$`", () => {
    // Kalip gevserse (or. bosluk serbest birakilirsa) bu test duser ve
    // istemcideki kopyanin da guncellenmesi gerektigi anlasilir.
    expect(SUNUCU_SEMA).toContain('_BLOK_PATTERN = r"^[A-Za-z0-9]+$"');
  });

  it("istemci AYNI kalibi tasir", () => {
    expect(UNITS_SAYFASI).toContain("const BLOK_KALIBI = /^[A-Za-z0-9]+$/;");
  });

  it("kalip GERCEK kullanici girdilerini dogru ayirir", () => {
    const kalip = /^[A-Za-z0-9]+$/;
    // Kullanicinin yazdigi tipik degerler — sikayetin kaynagi.
    expect(kalip.test("A Blok")).toBe(false);
    expect(kalip.test("B-1")).toBe(false);
    expect(kalip.test("Aş")).toBe(false);
    // Gecerli olanlar.
    expect(kalip.test("A")).toBe(true);
    expect(kalip.test("B2")).toBe(true);
  });

  it("istemci ISTEK ATMADAN uyarir (bos bir 422 turu daha az)", () => {
    // Dogrulama `apiSend` cagrisindan ONCE olmali; sonra olsaydi kullanici
    // yine sunucu hatasi gorurdu.
    const dogrulamaYeri = UNITS_SAYFASI.indexOf("BLOK_KALIBI.test");
    const istekYeri = UNITS_SAYFASI.indexOf('apiSend("/api/units/bulk"');
    expect(dogrulamaYeri).toBeGreaterThan(0);
    expect(istekYeri).toBeGreaterThan(0);
    expect(dogrulamaYeri).toBeLessThan(istekYeri);
  });
});

describe("(P162) sunucu ALAN hatasi ekrana ulasir", () => {
  it("alan ayrintisi varsa mesaja EKLENIR", () => {
    const hata = new ApiHatasi("İstek gövdesi geçersiz", "validation_error", 422, [
      { alan: "blok", mesaj: "String should match pattern '^[A-Za-z0-9]+$'" },
    ]);
    const metin = alanliHataMetni(hata, "yedek");
    // Kullanici HANGI ALAN oldugunu gormeli.
    expect(metin).toContain("blok");
    expect(metin).toContain("İstek gövdesi geçersiz");
  });

  it("BIRDEN COK alan hepsi gosterilir", () => {
    const hata = new ApiHatasi("gecersiz", "validation_error", 422, [
      { alan: "blok", mesaj: "a" },
      { alan: "kat_sayisi", mesaj: "b" },
    ]);
    const metin = alanliHataMetni(hata, "yedek");
    expect(metin).toContain("blok");
    expect(metin).toContain("kat_sayisi");
  });

  it("ayrinti YOKSA ust cumle korunur (gurultu eklenmez)", () => {
    const hata = new ApiHatasi("Yetkiniz yok", "forbidden", 403);
    expect(alanliHataMetni(hata, "yedek")).toBe("Yetkiniz yok");
  });

  it("ApiHatasi OLMAYAN hatalarda varsayilan metne duser", () => {
    expect(alanliHataMetni(new Error("ag koptu"), "yedek")).toBe("ag koptu");
    expect(alanliHataMetni("dize", "yedek")).toBe("yedek");
  });
});
