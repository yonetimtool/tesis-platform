// (P213 §6) BFF SUZGEC GECISI — "istemci gonderdi" YETMEZ.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// §4'te Ozet sayfasi `/api/cameras?ana_ekranda=true` istemeye basladi ve
// DOM testi bunu dogruladi. Ama `app/api/cameras/route.ts` yalnizca
// `limit` ve `offset`i tasiyordu: suzgec BFF'te DUSUYOR, backend TUM
// kameralari donduruyordu. Ozet "calisiyor" gorunuyordu cunku dondurulen
// listenin ilk kameralari zaten dogruydu.
//
// P200 DERSI birebir tekrar etti: taklit, olculmek istenen katmanin
// ALTINA konmali. Bu dosya rota islevini DOGRUDAN cagirip backend'e
// giden adresi okuyor — arada cizim katmani yok.
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

const { GET } = await import("@/app/api/cameras/route");

function istek(sorgu: string): NextRequest {
  return new NextRequest(`http://app.test/api/cameras?${sorgu}`);
}

describe("(P213 §6) /api/cameras BFF suzgeci", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`ana_ekranda` BACKEND'E ULASIR", async () => {
    await GET(istek("ana_ekranda=true&limit=10&offset=0"));
    expect(cagrilar).toHaveLength(1);
    expect(cagrilar[0]).toContain("ana_ekranda=true");
    expect(cagrilar[0]).toContain("limit=10");
  });

  it("suzgec VERILMEZSE eklenmez (yonetim listesi tumunu gorur)", async () => {
    await GET(istek("limit=50&offset=0"));
    expect(cagrilar[0]).not.toContain("ana_ekranda");
  });

  it("BILINMEYEN parametre GECMEZ (beyaz liste)", async () => {
    // Sorgu dizesini oldugu gibi iletmek, istemcinin backend uclarina
    // serbestce parametre gecirmesine izin vermek olurdu.
    await GET(istek("ana_ekranda=true&tenant_id=baskasi&order=1"));
    expect(cagrilar[0]).not.toContain("tenant_id");
    expect(cagrilar[0]).not.toContain("order=");
    expect(cagrilar[0]).toContain("ana_ekranda=true");
  });

  it("varsayilanlar korunur", async () => {
    await GET(istek(""));
    expect(cagrilar[0]).toContain("limit=50");
    expect(cagrilar[0]).toContain("offset=0");
  });
});
