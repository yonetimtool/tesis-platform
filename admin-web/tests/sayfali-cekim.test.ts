// (P65) TUM-KAYIT CEKIMI: UST SINIR VAR ve SESSIZ DEGIL.
//
// `fetchAllItems` dongusu `meta.total`a kadar kosuyordu. 200.000 odemesi
// olan bir sitede bu, TARAYICIDAN 1.000 ARDISIK ISTEK demektir: sayfa
// dakikalarca kilitli gorunur ve kullanici raporun hesaplandigini sanir.
//
// Ust sinir koymak tek basina YETMEZ — sessiz kirpma, eksik bir raporu
// TAM sanmak demektir. Bu yuzden `fetchAllPaged` `kesildi` bayragini
// doner ve cagiran onu kullaniciya soylemek zorundadir.
import { afterEach, describe, expect, it, vi } from "vitest";

import { fetchAllPaged } from "@/lib/client";

/** `total` kadar kaydi sayfa sayfa donen sahte uc. */
function sahteUc(total: number): number {
  let cagri = 0;
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    cagri += 1;
    const url = new URL(String(girdi), "http://x");
    const limit = Number(url.searchParams.get("limit"));
    const offset = Number(url.searchParams.get("offset"));
    const kalan = Math.max(0, Math.min(limit, total - offset));
    return new Response(
      JSON.stringify({
        meta: { limit, offset, total },
        items: Array.from({ length: kalan }, (_, i) => ({ id: `k${offset + i}` })),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }) as typeof fetch;
  return cagri;
}

afterEach(() => vi.restoreAllMocks());

describe("fetchAllPaged", () => {
  it("sinira ULASMAYAN veride hepsini ceker ve kirpmaz", async () => {
    sahteUc(450);
    const r = await fetchAllPaged<{ id: string }>("/api/x", { pageSize: 200 });
    expect(r.items).toHaveLength(450);
    expect(r.kesildi).toBe(false);
  });

  it("UST SINIRDA durur ve kirpildigini SOYLER", async () => {
    sahteUc(200_000);
    const r = await fetchAllPaged<{ id: string }>("/api/x", {
      pageSize: 200,
      enCok: 1000,
    });
    expect(r.items.length).toBeLessThanOrEqual(1000);
    // ASIL SEY: sessizce kirpmiyor.
    expect(r.kesildi).toBe(true);
  });

  it("bos uc tek istekte biter", async () => {
    sahteUc(0);
    const r = await fetchAllPaged<{ id: string }>("/api/x");
    expect(r.items).toHaveLength(0);
    expect(r.kesildi).toBe(false);
  });
});
