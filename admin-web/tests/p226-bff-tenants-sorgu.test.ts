// (P226) /api/tenants BFF SORGU GECISI — SINIFIN UCUNCU TEKRARI.
//
// ===========================================================================
// OLCULEN KUSUR (PROD)
// ===========================================================================
// Panelde arama kutusuna "oltu" yazildi ve SEKIZ TESISIN HEPSI listede
// kaldi. Sebep: `app/api/tenants/route.ts` icindeki imza
//
//     export async function GET(): Promise<NextResponse>
//
// istegi HIC ALMIYORDU. Tarayici `?q=oltu` gonderiyor, BFF onu SESSIZCE
// DUSURUYOR, backend suzgecsiz listeyi donduruyordu. `?kurulum=` ve
// `?arsivli=` de ayni sekilde hic ulasmiyordu — yani ARSIV GORUNUMU de
// bozuktu ve bunu kimse fark etmemisti.
//
// ===========================================================================
// IKI OLCUM DE DOGRUYDU, ARADAKI HALKA OLCULMEMISTI
// ===========================================================================
// Backend testi: ucu DOGRUDAN cagirdi (`/tenants?q=...`) -> suzuyor. ✓
// Web testi:    `fetch`i TARAYICI sinirinda taklit etti, istegin
//               `q=` tasidigini dogruladi. ✓
// Hicbiri TARAYICI -> BFF -> BACKEND zincirinin ORTA halkasini olcmedi.
//
// P200 dersi (taklidi olculecek katmanin ALTINA koy) ve P213 §6 birebir
// tekrar etti. Bu dosya rota islevini DOGRUDAN cagirip backend'e giden
// adresi okuyor.
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

const { GET } = await import("@/app/api/tenants/route");

function istek(sorgu = ""): NextRequest {
  return new NextRequest(
    `http://panel.test/api/tenants${sorgu ? `?${sorgu}` : ""}`,
  );
}

describe("(P226) /api/tenants sorgu gecisi", () => {
  beforeEach(() => {
    cagrilar.length = 0;
  });

  it("`q` BACKEND'E ULASIR — prod'da DUSUYORDU", async () => {
    await GET(istek("q=oltu"));
    expect(cagrilar).toHaveLength(1);
    expect(cagrilar[0]).toContain("q=oltu");
  });

  it("TURKCE karakterli sorgu KODLANARAK gecer", async () => {
    await GET(istek(`q=${encodeURIComponent("Arıköy")}`));
    expect(decodeURIComponent(cagrilar[0])).toContain("q=Arıköy");
  });

  it("`kurulum` ve `arsivli` de gecer", async () => {
    await GET(istek("kurulum=false"));
    expect(cagrilar[0]).toContain("kurulum=false");
    cagrilar.length = 0;
    await GET(istek("arsivli=true"));
    expect(cagrilar[0]).toContain("arsivli=true");
  });

  it("SORGU YOKSA temiz yol gider (gereksiz `?` eklenmez)", async () => {
    await GET(istek());
    expect(cagrilar[0]).toBe("/tenants");
  });

  it("BOS DEGER SUZGEC SAYILMAZ", async () => {
    // Kullanici arama kutusunu temizleyince `q=` bos gider; bunu backend'e
    // iletmek `%%` ile her satiri eslemek (ya da 422) demekti.
    await GET(istek("q=&kurulum="));
    expect(cagrilar[0]).toBe("/tenants");
  });

  it("BILINMEYEN parametre GECMEZ (beyaz liste)", async () => {
    // Ham yeniden yayin, ileride eklenen bir uc parametresini de
    // farkinda olmadan acmak olurdu (P213 §3 dersi).
    await GET(istek("q=oltu&limit=9999&tenant_id=baskasi"));
    expect(cagrilar[0]).toContain("q=oltu");
    expect(cagrilar[0]).not.toContain("limit");
    expect(cagrilar[0]).not.toContain("tenant_id");
  });
});
