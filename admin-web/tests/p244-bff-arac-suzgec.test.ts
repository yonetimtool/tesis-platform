// (P244 §6) `/api/vehicle-passes` BFF SUZGECI — "sayfa istedi" YETMEZ.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Sunucu `acik`, `plaka`, `baslangic`, `bitis` suzgeclerini P16'dan beri
// destekliyor ve sozlesme bunlari ACIKCA sayac tarifi olarak belgeliyor:
//   "Ana ekran sayaci: `?acik=true&limit=1` -> `meta.total`"
//   "Bugun N giris: `?baslangic=<gun basi>&limit=1` -> `meta.total`"
// BFF rotasi ise YALNIZ `limit`/`offset` tasiyordu. Yani web ne plakaya
// gore arayabiliyor ne de "iceride kac arac var" sorabiliyordu.
//
// ===========================================================================
// NEDEN AYRI DOSYA — DOM TESTI BUNU OLCEMEZ
// ===========================================================================
// KIRARAK OLCULDU: BFF'ten suzgeci kaldirdim ve sayfanin DOM testi
// SORUNSUZ GECTI. Sebep basit — DOM testi `fetch`i taklit ediyor, yani
// rota islevi HIC CALISMIYOR.
//
// P200/P213 dersi birebir tekrar: taklit, olculmek istenen katmanin
// ALTINA konmali. Bu dosya rota islevini DOGRUDAN cagirip backend'e
// giden adresi okuyor.
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

const { GET } = await import("@/app/api/vehicle-passes/route");

function istek(sorgu: string): NextRequest {
  return new NextRequest(`http://app.test/api/vehicle-passes?${sorgu}`);
}

describe("(P244 §6) /api/vehicle-passes BFF suzgeci", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`acik` BACKEND'E ULASIR (iceride sayaci)", async () => {
    await GET(istek("acik=true&limit=1&offset=0"));
    expect(cagrilar[0]).toContain("acik=true");
    expect(cagrilar[0]).toContain("limit=1");
  });

  it("`plaka` BACKEND'E ULASIR (arama sunucuda)", async () => {
    await GET(istek("plaka=34ABC&limit=50&offset=0"));
    expect(cagrilar[0]).toContain("plaka=34ABC");
  });

  it("`baslangic`/`bitis` BACKEND'E ULASIR (bugun sayaci)", async () => {
    await GET(istek("baslangic=2026-09-20T00%3A00%3A00.000Z&limit=1&offset=0"));
    expect(cagrilar[0]).toContain("baslangic=");
  });

  it("BOS suzgec EKLENMEZ (tumu listelenir)", async () => {
    // Bos dize `acik=` diye gitseydi backend onu bir deger sanardi.
    await GET(istek("acik=&plaka=&limit=50&offset=0"));
    expect(cagrilar[0]).not.toContain("acik=");
    expect(cagrilar[0]).not.toContain("plaka=");
  });

  it("BILINMEYEN parametre GECMEZ (beyaz liste)", async () => {
    // Sorgu dizesini oldugu gibi iletmek, istemcinin backend uclarina
    // serbestce parametre gecirmesine izin vermek olurdu.
    await GET(istek("plaka=34&tenant_id=baskasi&order=1"));
    expect(cagrilar[0]).not.toContain("tenant_id");
    expect(cagrilar[0]).not.toContain("order=");
    expect(cagrilar[0]).toContain("plaka=34");
  });
});
