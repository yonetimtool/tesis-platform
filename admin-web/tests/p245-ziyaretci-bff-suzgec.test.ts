// (P245) `/api/visitors` BFF SUZGECI — ALTINCI KEZ AYNI KUSUR.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Arka uc `icerde`, `unit_id`, `baslangic` ve `bitis`i destekliyor
// (`list_visitors`) ama vekil yalniz `limit`/`offset` tasiyordu. Yani
// ekran "icerideki ziyaretciler" diye SUZEMIYORDU — ki bu, kapidaki
// gorevlinin en sik sordugu soru.
//
// AYNI KUSUR SINIFININ ALTINCI ORNEGI: P173, P189, P213 ve P244'te §6
// (araç geçişleri), §8a (kargo), §8c (görevler), P245 §3 (olaylar).
// Vekil GORUNMEZ oldugu icin sessizce yanlis olur; yalniz rota islevini
// DOGRUDAN cagiran bir test onu yakalar (DOM testi `fetch`i taklit eder
// ve rota HIC CALISMAZ — P200/P213 dersi).
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

const { GET } = await import("@/app/api/visitors/route");

function istek(sorgu: string): NextRequest {
  return new NextRequest(`http://app.test/api/visitors?${sorgu}`);
}

describe("(P245) /api/visitors BFF suzgeci", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`icerde` BACKEND'E ULASIR (kapida kac kisi var)", async () => {
    await GET(istek("icerde=true&limit=50&offset=0"));
    expect(cagrilar[0]).toContain("icerde=true");
  });

  it("`unit_id` ve tarih araligi BACKEND'E ULASIR", async () => {
    await GET(istek("unit_id=u1&baslangic=2026-09-01T00:00:00Z&bitis=2026-09-02T00:00:00Z"));
    expect(cagrilar[0]).toContain("unit_id=u1");
    expect(cagrilar[0]).toContain("baslangic=");
    expect(cagrilar[0]).toContain("bitis=");
  });

  it("BOS suzgec parametre EKLEMEZ", async () => {
    await GET(istek("limit=50&offset=0"));
    expect(cagrilar[0]).not.toContain("icerde=");
  });

  it("BEYAZ LISTE DISINDAKI parametre GECMEZ", async () => {
    await GET(istek("icerde=true&role=admin&tenant_id=x"));
    expect(cagrilar[0]).toContain("icerde=true");
    expect(cagrilar[0]).not.toContain("role=");
    expect(cagrilar[0]).not.toContain("tenant_id=");
  });
});
