// (P244 §8c) `/api/tasks` BFF SUZGECI — DORDUNCU KEZ AYNI KUSUR.
//
// ===========================================================================
// OLCULEN KUSUR — bu bir tasarim eksigi degil, CALISMAYAN BIR OZELLIK
// ===========================================================================
// Gorevler sayfasinin kategori suzgeci HICBIR SEY YAPMIYORDU:
//
//   * sayfa `kategori_id`yi sorguya EKLIYORDU,
//   * arka uc `kategori_id`yi DESTEKLIYOR (UUID veya "diger"),
//   * ama BFF rotasi yalnizca `limit`/`offset`/`aktif`/`atanan_user_id`
//     tasiyordu — `kategori_id` ve `durum` sessizce dusuyordu.
//
// Yani kullanici bir kategori seciyor ve liste AYNEN kaliyordu.
// Sayfadaki yorum "SUZGEC ARTIK GERCEK" diyor; arka uc icin dogruydu,
// YOL icin degildi.
//
// `durum` (P230 §4: atandi | baslandi | tamamlandi | gecikti) da ayni
// sekilde dusuyordu — ve webde onu kuracak bir kontrol de yoktu.
//
// Ayni kusur sinifinin depoda DORDUNCU ornegi: P173, P189, P213 ve bu
// turda §6 (araç geçişleri) ile §8a (kargo).
//
// ===========================================================================
// NEDEN AYRI DOSYA
// ===========================================================================
// Sayfanin DOM testi `fetch`i taklit eder; rota islevi HIC CALISMAZ. Bu
// dosya rota islevini DOGRUDAN cagirip backend'e giden adresi okur.
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

const { GET } = await import("@/app/api/tasks/route");

function istek(sorgu: string): NextRequest {
  return new NextRequest(`http://app.test/api/tasks?${sorgu}`);
}

describe("(P244 §8c) /api/tasks BFF suzgeci", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`kategori_id` BACKEND'E ULASIR (suzgec gercekten suzer)", async () => {
    await GET(istek("kategori_id=abc-123&limit=25&offset=0"));
    expect(cagrilar[0]).toContain("kategori_id=abc-123");
  });

  it("`kategori_id=diger` (kategorisiz) da ULASIR", async () => {
    // "diger" bir UUID degil, arka ucun tanidigi ozel bir degerdir;
    // beyaz liste onu da gecirmeli.
    await GET(istek("kategori_id=diger"));
    expect(cagrilar[0]).toContain("kategori_id=diger");
  });

  it("`durum` BACKEND'E ULASIR (geciken/tamamlanan sayaclari)", async () => {
    await GET(istek("durum=gecikti&limit=1&offset=0"));
    expect(cagrilar[0]).toContain("durum=gecikti");
    expect(cagrilar[0]).toContain("limit=1");
  });

  it("ONCEDEN CALISAN suzgecler BOZULMADI", async () => {
    await GET(istek("aktif=true&atanan_user_id=u1"));
    expect(cagrilar[0]).toContain("aktif=true");
    expect(cagrilar[0]).toContain("atanan_user_id=u1");
  });

  it("BEYAZ LISTE DISINDAKI parametre GECMEZ", async () => {
    await GET(istek("durum=gecikti&role=admin&tenant_id=x"));
    expect(cagrilar[0]).toContain("durum=gecikti");
    expect(cagrilar[0]).not.toContain("role=");
    expect(cagrilar[0]).not.toContain("tenant_id=");
  });
});
