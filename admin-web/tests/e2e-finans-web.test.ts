// (E2E 2026-09) FINANS web kilitleri — FINANS-20/21, ARAYUZ-16.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { tr } from "@/lib/i18n/sozluk/tr";
import { saltTarihBicimi } from "@/lib/tarih";

const kok = join(__dirname, "..");
const oku = (yol: string) => readFileSync(join(kok, yol), "utf8");

describe("(E2E 2026-09) finans web", () => {
  it("ARAYUZ-16: salt tarih GUN KAYMADAN ve SAATSIZ yazilir", () => {
    // UTC gece yarisi yorumu UTC- bolgede 22.09'a kayiyordu.
    expect(saltTarihBicimi("2026-09-23", "tr-TR")).toBe("23.09.2026");
    expect(saltTarihBicimi("2026-01-01", "tr-TR")).toBe("01.01.2026");
    // Bozuk girdi uydurulmaz.
    expect(saltTarihBicimi("abc", "tr-TR")).toBe("abc");
  });

  it("FINANS-21: iptal tipi ve reddedildi/iptal edildi durumlari cevrili", () => {
    expect(tr.finansTip_iptal).toBeTruthy();
    expect(tr.finansDurumReddedildi).toBeTruthy();
    expect(tr.finansDurumIptalEdildi).toBeTruthy();
  });

  it("FINANS-21: hareket listesinde iptal edilmis/reddedilmis satira 'Iptal et' cizilmez", () => {
    const k = oku("components/finans/hareket-sayfasi.tsx");
    expect(k).toMatch(/h\.iptal_edildi \|\| h\.durum === DURUM_REDDEDILDI/);
    expect(k).toMatch(/saltTarihBicimi\(h\.tarih\)/);
  });

  it("FINANS-20: yaslandirma grafigine TL verilir (kurus degil)", () => {
    const k = oku("app/(protected)/finans/borclular/page.tsx");
    expect(k).toMatch(/deger: k\.kalan_kurus \/ 100/);
  });

  it("ARAYUZ-16: /finans hareket tablosu saatli bicimleyici kullanmaz", () => {
    const k = oku("app/(protected)/finans/page.tsx");
    expect(k).not.toMatch(/formatDateTime\(h\.tarih\)/);
  });
});
