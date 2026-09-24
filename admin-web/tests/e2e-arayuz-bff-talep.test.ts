// (E2E 2026-09, ARAYUZ-15) /api/complaints BFF `oncelik` SUZGECINI DUSURUYORDU.
//
// Olculen: 8 acik "normal" talep varken ozet sayfasi "Açık talep 0 — 8
// yüksek öncelikli" diyordu. Sayfa `durum=acik&oncelik=yuksek` soruyor,
// vekil yalniz `limit/offset/durum`u tasiyor ve backend TUM acik talepleri
// sayiyordu. (P226 tenants, P245 §7 visitors ile ayni sinif.) Rota islevi
// DOGRUDAN cagrilip backend'e giden adres okunur.
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

const { GET } = await import("@/app/api/complaints/route");

const istek = (sorgu: string) =>
  new NextRequest(`http://panel.test/api/complaints?${sorgu}`);

describe("(ARAYUZ-15) /api/complaints sorgu gecisi", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`oncelik` BACKEND'E ULASIR", async () => {
    await GET(istek("limit=1&offset=0&durum=acik&oncelik=yuksek"));
    expect(cagrilar[0]).toContain("durum=acik");
    expect(cagrilar[0]).toContain("oncelik=yuksek");
  });

  it("`unit_id` de gecer; bilinmeyen parametre GECMEZ (beyaz liste)", async () => {
    await GET(istek("unit_id=u-1&tenant_id=baskasi"));
    expect(cagrilar[0]).toContain("unit_id=u-1");
    expect(cagrilar[0]).not.toContain("tenant_id");
  });

  it("BOS deger suzgec sayilmaz", async () => {
    await GET(istek("oncelik=&durum="));
    expect(cagrilar[0]).not.toContain("oncelik");
    expect(cagrilar[0]).not.toContain("durum");
  });
});
