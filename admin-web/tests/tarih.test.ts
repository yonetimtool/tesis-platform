// Tarih bicimi DILE DUYARLI mi (tur 31)?
//
// Tur 17'de bulunmus, ayri alt is olarak kayda gecmisti: panel 7 dile
// acildi ama tarihler `toLocaleString("tr-TR")` ile sabitti — Almanca
// arayuzde tarih TR biciminde kaliyordu.
//
// PARA BUNUN DISINDADIR ve testte de ayrica dogrulanir: para politikasi
// "TL + Turkce gruplama, arayuz dili ne olursa olsun" der.
import { describe, expect, it } from "vitest";

import { tarihBicimi, tarihSaatBicimi, tarihSaatUzun } from "@/lib/tarih";
import { kurusToTL } from "@/lib/money";

const ISO = "2026-07-28T14:30:00.000Z";

describe("tarih bicimi", () => {
  it("dile gore DEGISIR (tr / en / de farkli)", () => {
    const bicimler = new Set(
      ["tr", "en", "de", "ru"].map((d) => tarihSaatBicimi(ISO, d)),
    );
    expect(bicimler.size).toBeGreaterThan(1);
  });

  it("en: ay adi/AM-PM bicimi; tr: gun.ay.yil", () => {
    expect(tarihSaatUzun(ISO, "en")).toMatch(/Jul/);
    expect(tarihSaatUzun(ISO, "tr")).toMatch(/Tem/);
    expect(tarihBicimi(ISO, "tr")).toMatch(/^\d{2}\.\d{2}\.\d{4}$/);
  });

  it("GECERSIZ girdi AYNEN doner (uydurma tarih yok)", () => {
    expect(tarihBicimi("bozuk")).toBe("bozuk");
    expect(tarihSaatBicimi("bozuk")).toBe("bozuk");
  });

  it("PARA dilden BAGIMSIZ: TL + Turkce gruplama", () => {
    // Politika geregi: arayuz Ingilizce olsa da tutar "1.250,00 ₺".
    expect(kurusToTL(125000)).toContain("1.250,00");
  });
});
