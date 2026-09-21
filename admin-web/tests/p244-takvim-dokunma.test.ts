// (P244 §10e) AY TAKVIMI — 48x48 DOKUNMA HEDEFI, ISTISNASIZ.
//
// ===========================================================================
// ONCEKI DURUM BIR ACIK MADDEYDI
// ===========================================================================
// Bilesen yuksekligi 48 tutuyor ama GENISLIK dayatmiyordu. Dosyanin
// kendi yorumu bunu yaziyordu: yedi sutunlu izgarada gun hucresi
// 320/360/390 px ekranda 33.1 / 38.9 / 43.1 px'e dusuyor — yani 44 bile
// tutulmuyordu; "olculebilir iyilesme" denip birakilmisti.
//
// Erisilebilirlik hedefi istisna kabul etmez (kullanici karari).
//
// ===========================================================================
// SECILEN COZUM ve REDDEDILEN ALTERNATIF
// ===========================================================================
// * HAFTA GORUNUMUNE DUSMEK reddedildi: 48'i tutardi ama AYI
//   gostermezdi. Takvimin tek varlik sebebi "ayin tamamini bir bakista
//   gormek"; dar ekranda bunu kaldirmak, kucuk ekranda BASKA bir urun
//   sunmak olurdu.
// * YATAY KAYDIRMA secildi: izgara aynen kalir, yalniz 320-375 px
//   araliginda yana kayar. Depoda bu desen zaten var (`VeriTablosu`).
//
// ===========================================================================
// NEDEN KAYNAK TARAMASI
// ===========================================================================
// jsdom YERLESIM HESAPLAMAZ: `getBoundingClientRect` her sey icin 0
// doner ve bir DOM testi 48px'i ASLA olcemez (P226'nin renk dersinin
// olcu karsiligi). Olculebilecek en yakin YAPISAL sey, izgaranin
// asgari sutun genisligini TASIYIP tasimadigi.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KAYNAK = readFileSync(
  join(__dirname, "..", "components", "ui", "ay-takvimi.tsx"),
  "utf8",
);

describe("(P244 §10e) ay takvimi 48x48", () => {
  it("SUTUN GENISLIGI en az 3rem (48px)", () => {
    // `grid-cols-7` esit boler ve DARALTIR; `minmax(3rem, 1fr)` ise
    // tabani sabitler.
    expect(KAYNAK).toContain("repeat(7, minmax(3rem, 1fr))");
    expect(KAYNAK, "esit bolen sinif geri gelmis").not.toContain("grid-cols-7");
  });

  it("HUCRE YUKSEKLIGI en az 3rem (48px)", () => {
    expect(KAYNAK).toContain('minHeight: "3rem"');
  });

  it("IZGARA ASGARI GENISLIGI 7 sutunu KALDIRIR", () => {
    // 7 x 48 + 6 x 4 bosluk = 360px = 22.5rem. Daha kucuk bir taban,
    // sutunlari yine ezerdi.
    expect(KAYNAK).toContain('IZGARA_ASGARI = "22.5rem"');
    expect(KAYNAK).toContain("minWidth: IZGARA_ASGARI");
  });

  it("KAP KAYDIRILABILIR ve KLAVYEYLE erisilebilir", () => {
    // Yalniz `overflow-x-auto` yetmez: kaydirilabilir bir bolge klavye
    // ile de kaydirilabilmeli (WCAG 2.1.1) ve adsiz bir `region`
    // erisilebilirlik agacinda anlamsiz bir bolge birakir.
    expect(KAYNAK).toContain("overflow-x-auto");
    expect(KAYNAK).toContain("tabIndex={0}");
    expect(KAYNAK).toContain('role="region"');
    expect(KAYNAK).toContain('aria-label={t("takvimBolgesi")}');
  });

  it("HAFTA GORUNUMUNE DUSULMUYOR (ay her ekranda AY kalir)", () => {
    // Reddedilen alternatifi GORUNUR tutar: biri dar ekran icin ayri
    // bir hafta izgarasi eklerse, karar yeniden verilmeli.
    expect(KAYNAK).not.toMatch(/repeat\(7, minmax\(3rem, 1fr\)\)[\s\S]*repeat\(1,/);
  });
});
