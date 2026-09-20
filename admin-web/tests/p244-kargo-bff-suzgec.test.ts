// (P244 §8a) `/api/kargo` BFF SUZGECI — sayfa istedi diye ulasmis olmaz.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Backend `durum`, `unit_id`, `baslangic`, `bitis` suzgeclerini P126.4'ten
// beri destekliyor. BFF rotasi ise YALNIZ `limit`/`offset` tasiyordu.
// Sonuc: durum suzgeci sunucuya HIC ulasmaz, liste suzulmemis doner ve
// ozet sayaclari ("kac kargo bekliyor") ayni sayiyi uc kez gosterirdi.
//
// ===========================================================================
// NEDEN AYRI DOSYA — DOM TESTI BUNU OLCEMEZ
// ===========================================================================
// Sayfanin DOM testi `fetch`i taklit eder; rota islevi HIC CALISMAZ.
// P200/P213/P244 §6'da ayni ders uc kez cikti: taklit, olculmek istenen
// katmanin ALTINA konmali. Bu dosya rota islevini DOGRUDAN cagirip
// backend'e giden adresi okur.
import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const cagrilar: string[] = [];

vi.mock("@/lib/backend", () => ({
  proxyJson: (yol: string) => {
    cagrilar.push(yol);
    return new Response(JSON.stringify({ items: [], meta: { total: 0 } }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
}));

const { GET } = await import("@/app/api/kargo/route");

function istek(sorgu: string): NextRequest {
  return new NextRequest(`http://app.test/api/kargo?${sorgu}`);
}

describe("(P244 §8a) /api/kargo BFF suzgeci", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`durum` BACKEND'E ULASIR (bekleyen sayaci + suzgec)", async () => {
    await GET(istek("durum=bekliyor&limit=1&offset=0"));
    expect(cagrilar[0]).toContain("durum=bekliyor");
    expect(cagrilar[0]).toContain("limit=1");
  });

  it("`unit_id` ve tarih araligi BACKEND'E ULASIR", async () => {
    await GET(istek("unit_id=u1&baslangic=2026-09-01T00:00:00Z&bitis=2026-09-02T00:00:00Z"));
    expect(cagrilar[0]).toContain("unit_id=u1");
    expect(cagrilar[0]).toContain("baslangic=");
    expect(cagrilar[0]).toContain("bitis=");
  });

  it("BEYAZ LISTE DISINDAKI parametre GECMEZ", async () => {
    // Vekilin isi tasimak degil, TARIF EDILENI tasimak. `?` ile gelen
    // her seyi gecirmek, uce sozlesmede olmayan alanlar gondermekti.
    await GET(istek("durum=bekliyor&role=admin&tenant_id=x"));
    expect(cagrilar[0]).toContain("durum=bekliyor");
    expect(cagrilar[0]).not.toContain("role=");
    expect(cagrilar[0]).not.toContain("tenant_id=");
  });

  it("BOS suzgec parametre EKLEMEZ (tum durumlar)", async () => {
    // `durum=` bos gonderilirse backend enum dogrulamasina takilir ve
    // "tum durumlar" secenegi 422 uretirdi.
    await GET(istek("limit=50&offset=0"));
    expect(cagrilar[0]).not.toContain("durum=");
  });
});
