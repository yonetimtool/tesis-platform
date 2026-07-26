// Istemci mutasyon yardimcisi + sayfali cekme + idempotency anahtari.
// `fetchAllItems` raporlarda TUM kayitlari toplar; durma kosulu yanlissa ya
// eksik rapor uretir ya SONSUZ dongude kalir — bu yuzden sinirlar burada
// kilitli.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { apiSend, fetchAllItems, genIdempotencyKey } from "@/lib/client";

interface SahteYanit {
  status?: number;
  body?: unknown;
  ok?: boolean;
  patlat?: boolean;
}

/** Sirayla verilen yanitlari donduren `fetch` stub'u; cagri listesini verir. */
function stubFetchSeq(yanitlar: SahteYanit[]): unknown[][] {
  let i = 0;
  const f = vi.fn(async (...args: unknown[]) => {
    const y = yanitlar[Math.min(i++, yanitlar.length - 1)];
    const status = y.status ?? 200;
    return {
      status,
      ok: y.ok ?? (status >= 200 && status < 300),
      headers: { get: () => null },
      json: async () => {
        if (y.patlat) throw new Error("bozuk govde");
        return y.body ?? null;
      },
    };
  });
  vi.stubGlobal("fetch", f);
  return f.mock.calls;
}

function stubWindow(): { location: { href: string } } {
  const w = { location: { href: "" } };
  vi.stubGlobal("window", w);
  return w;
}

describe("apiSend", () => {
  beforeEach(() => vi.unstubAllGlobals());
  afterEach(() => vi.unstubAllGlobals());

  it("govde VARSA Content-Type eklenir ve JSON'a cevrilir", async () => {
    const cagrilar = stubFetchSeq([{ status: 200, body: { id: "1" } }]);
    await apiSend("/api/units", "POST", { no: "A-12" });
    const init = cagrilar[0][1] as { method: string; headers: Record<string, string>; body: string };
    expect(init.method).toBe("POST");
    expect(init.headers["Content-Type"]).toBe("application/json");
    expect(JSON.parse(init.body)).toEqual({ no: "A-12" });
  });

  it("govde YOKSA Content-Type EKLENMEZ ve headers undefined kalir", async () => {
    const cagrilar = stubFetchSeq([{ status: 200, body: {} }]);
    await apiSend("/api/x/1/cancel", "POST");
    const init = cagrilar[0][1] as { headers?: Record<string, string>; body?: string };
    expect(init.headers).toBeUndefined();
    expect(init.body).toBeUndefined();
  });

  it("ek basliklar (orn. Idempotency-Key) korunur", async () => {
    const cagrilar = stubFetchSeq([{ status: 200, body: {} }]);
    await apiSend("/api/dues/pay", "POST", { kurus: 1 }, { "Idempotency-Key": "k-1" });
    const init = cagrilar[0][1] as { headers: Record<string, string> };
    expect(init.headers["Idempotency-Key"]).toBe("k-1");
    expect(init.headers["Content-Type"]).toBe("application/json");
  });

  it("204: govde OKUNMAZ, undefined doner (DELETE deseni)", async () => {
    stubFetchSeq([{ status: 204, patlat: true }]); // json() patlarsa da sorun yok
    await expect(apiSend("/api/x/1", "DELETE")).resolves.toBeUndefined();
  });

  it("401: LOGIN'e yonlendirir ve firlatir", async () => {
    const w = stubWindow();
    stubFetchSeq([{ status: 401 }]);
    await expect(apiSend("/api/x", "POST", {})).rejects.toThrow("Oturum süresi doldu.");
    expect(w.location.href).toBe("/login");
  });

  it("hata zarfindaki sunucu mesajini tasir; yoksa genel mesaj", async () => {
    stubFetchSeq([{ status: 409, body: { error: { message: "Ayni ad zaten var." } } }]);
    await expect(apiSend("/api/x", "POST", {})).rejects.toThrow("Ayni ad zaten var.");

    stubFetchSeq([{ status: 500, body: null }]);
    await expect(apiSend("/api/x", "POST", {})).rejects.toThrow("Bir hata oluştu.");
  });
});

describe("fetchAllItems (sayfali toplama)", () => {
  beforeEach(() => vi.unstubAllGlobals());
  afterEach(() => vi.unstubAllGlobals());

  it("tek sayfa: limit/offset eklenir, ? ayiricisi kullanilir", async () => {
    const cagrilar = stubFetchSeq([{ body: { items: [{ id: 1 }], meta: { total: 1 } } }]);
    const out = await fetchAllItems<{ id: number }>("/api/units");
    expect(out).toHaveLength(1);
    expect(cagrilar[0][0]).toBe("/api/units?limit=200&offset=0");
  });

  it("URL'de zaten sorgu varsa & ile eklenir (sorgu bozulmaz)", async () => {
    const cagrilar = stubFetchSeq([{ body: { items: [], meta: { total: 0 } } }]);
    await fetchAllItems("/api/tasks?durum=acik");
    expect(cagrilar[0][0]).toBe("/api/tasks?durum=acik&limit=200&offset=0");
  });

  it("meta.total'a gore SAYFA SAYFA ilerler ve hepsini biriktirir", async () => {
    const sayfa = (n: number) => ({
      body: { items: Array.from({ length: n }, (_, i) => ({ i })), meta: { total: 5 } },
    });
    const cagrilar = stubFetchSeq([sayfa(3), sayfa(2)]);
    const out = await fetchAllItems<{ i: number }>("/api/x", 3);
    expect(out).toHaveLength(5);
    expect(cagrilar.map((c) => c[0])).toEqual([
      "/api/x?limit=3&offset=0",
      "/api/x?limit=3&offset=3",
    ]);
  });

  it("BOS sayfa geldiginde durur — meta.total yanlis olsa bile SONSUZ DONGU yok",
    async () => {
      // total=999 diyor ama ikinci sayfa bos -> durmali.
      const cagrilar = stubFetchSeq([
        { body: { items: [{ i: 0 }], meta: { total: 999 } } },
        { body: { items: [], meta: { total: 999 } } },
      ]);
      const out = await fetchAllItems<{ i: number }>("/api/x", 1);
      expect(out).toHaveLength(1);
      expect(cagrilar).toHaveLength(2);
    });

  it("meta YOKSA tek turda durur (total = toplanan sayisi)", async () => {
    const cagrilar = stubFetchSeq([{ body: { items: [{ i: 0 }, { i: 1 }] } }]);
    const out = await fetchAllItems<{ i: number }>("/api/x", 200);
    expect(out).toHaveLength(2);
    expect(cagrilar).toHaveLength(1);
  });

  it("401: LOGIN'e yonlendirir ve firlatir (sayfalarin ortasinda da)", async () => {
    const w = stubWindow();
    stubFetchSeq([
      { body: { items: [{ i: 0 }], meta: { total: 4 } } },
      { status: 401 },
    ]);
    await expect(fetchAllItems("/api/x", 1)).rejects.toThrow("Oturum süresi doldu.");
    expect(w.location.href).toBe("/login");
  });

  it("hata: zarf mesaji yoksa 'Hata' ile firlatir", async () => {
    stubFetchSeq([{ status: 500, body: null }]);
    await expect(fetchAllItems("/api/x")).rejects.toThrow("Hata");
  });
});

describe("genIdempotencyKey", () => {
  beforeEach(() => vi.unstubAllGlobals());
  afterEach(() => vi.unstubAllGlobals());

  it("crypto.randomUUID varsa onu kullanir", () => {
    vi.stubGlobal("crypto", { randomUUID: () => "uuid-sabit" });
    expect(genIdempotencyKey()).toBe("uuid-sabit");
  });

  it("crypto YOKSA yedek uretici calisir ve ANAHTARLAR TEKRARLANMAZ", () => {
    vi.stubGlobal("crypto", undefined);
    const kumeler = new Set(Array.from({ length: 50 }, () => genIdempotencyKey()));
    expect(kumeler.size).toBe(50);
    expect([...kumeler][0]).toMatch(/^k-\d+-/);
  });
});
