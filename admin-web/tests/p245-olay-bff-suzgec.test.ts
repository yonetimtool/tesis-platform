// (P245) `/api/violations` BFF SUZGECI — BESINCI KEZ AYNI KUSUR.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Arka uc `durum`u destekliyor (`list_violations`: ViolationDurum) ama
// vekil yalniz `limit`/`offset` tasiyordu. Yani ekrana bir durum
// suzgeci eklendigi anda SESSIZCE calismayacakti: kullanici
// "Kapatilmis" secer, liste aynen kalirdi.
//
// AYNI KUSUR SINIFININ BESINCI ORNEGI: P173, P189, P213 ve P244'te
// §6 (araç geçişleri), §8a (kargo), §8c (görevler). Bu kadar tekrar
// edince artik kaza degil — vekil GORUNMEZ oldugu icin sessizce yanlis
// olur ve yalniz rota islevini DOGRUDAN cagiran bir test onu yakalar.
//
// DOM testi bunu olcemez: `fetch` taklit edilir, rota islevi HIC
// CALISMAZ (P200/P213 dersi).
import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const cagrilar: string[] = [];

vi.mock("@/lib/backend", () => ({
  proxyJson: (yol: string) => {
    cagrilar.push(yol);
    return new Response(JSON.stringify({ items: [] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
}));

const { GET } = await import("@/app/api/violations/route");

function istek(sorgu: string): NextRequest {
  return new NextRequest(`http://app.test/api/violations?${sorgu}`);
}

describe("(P245) /api/violations BFF suzgeci", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`durum` BACKEND'E ULASIR", async () => {
    await GET(istek("durum=kapatildi&limit=50&offset=0"));
    expect(cagrilar[0]).toContain("durum=kapatildi");
    expect(cagrilar[0]).toContain("limit=50");
  });

  it("BOS suzgec parametre EKLEMEZ (tum durumlar)", async () => {
    // `durum=` bos gonderilirse backend enum dogrulamasina takilir ve
    // "tum durumlar" secenegi 422 uretirdi.
    await GET(istek("limit=50&offset=0"));
    expect(cagrilar[0]).not.toContain("durum=");
  });

  it("BEYAZ LISTE DISINDAKI parametre GECMEZ", async () => {
    await GET(istek("durum=yeni&role=admin&tenant_id=x"));
    expect(cagrilar[0]).toContain("durum=yeni");
    expect(cagrilar[0]).not.toContain("role=");
    expect(cagrilar[0]).not.toContain("tenant_id=");
  });
});
