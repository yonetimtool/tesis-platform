// SWR fetcher'i: 401 davranisi (oturum bitti -> /login) ve hata zarfindan
// ({error:{message}}) kullaniciya gosterilecek mesajin cikarilmasi. Bu iki
// davranis panelin TUM veri ekranlarinda paylasilir.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { formatDateTime, jsonFetcher } from "@/lib/fetcher";

/** Verilen yanitla tek seferlik `fetch` stub'u. */
function stubFetch(status: number, body: unknown, ok?: boolean): void {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => ({
      status,
      ok: ok ?? (status >= 200 && status < 300),
      json: async () => body,
    })),
  );
}

/** Tarayici benzeri `window` — kod yalniz `location.href`'e yazar. */
function stubWindow(): { location: { href: string } } {
  const w = { location: { href: "" } };
  vi.stubGlobal("window", w);
  return w;
}

describe("jsonFetcher", () => {
  beforeEach(() => vi.unstubAllGlobals());
  afterEach(() => vi.unstubAllGlobals());

  it("200: govdeyi tiplenmis olarak doner", async () => {
    stubFetch(200, { items: [{ id: "a" }], meta: { total: 1 } });
    const d = await jsonFetcher<{ items: { id: string }[] }>("/api/units");
    expect(d.items[0].id).toBe("a");
  });

  it("Accept: application/json basligi gonderilir", async () => {
    stubFetch(200, {});
    await jsonFetcher("/api/x");
    const cagri = (fetch as unknown as { mock: { calls: unknown[][] } }).mock.calls[0];
    expect(cagri[0]).toBe("/api/x");
    expect((cagri[1] as { headers: Record<string, string> }).headers.Accept).toBe(
      "application/json",
    );
  });

  it("401: LOGIN'e yonlendirir VE firlatir (SWR'a hata dusmeli)", async () => {
    const w = stubWindow();
    stubFetch(401, null);
    await expect(jsonFetcher("/api/units")).rejects.toThrow("Oturum süresi doldu.");
    expect(w.location.href).toBe("/login");
  });

  it("401 + window YOK (sunucu tarafi): yonlendirmeye CALISMAZ, yalniz firlatir",
    async () => {
      stubFetch(401, null); // window stub'lanmadi -> undefined
      await expect(jsonFetcher("/api/units")).rejects.toThrow("Oturum süresi doldu.");
    });

  it("hata zarfindaki SUNUCU mesajini kullaniciya tasir", async () => {
    stubFetch(422, { error: { code: "validation_error", message: "Tarih gecersiz." } });
    await expect(jsonFetcher("/api/x")).rejects.toThrow("Tarih gecersiz.");
  });

  it("zarf yok / govde bozuk: DURUM + REFERANS yazar (undefined gostermez)",
    async () => {
    // (P175 §4) IDDIA YON DEGISTIRDI — ESKI HALI "Bir hata olustu." BEKLIYORDU.
    //
    // O cumle hicbir sey soylemiyordu: bir ekran birden fazla uc
    // cagirdiginda kullanici da destek de HANGI cagrinin patladigini
    // bilemiyordu. Kurulum sihirbazi ornegi tam buydu.
    //
    // Korunan sey AYNI: `undefined` GOSTERILMEZ, govde bozuk olsa bile
    // anlamli bir cumle cikar. Eklenen sey teshis: durum kodu + referans.
    // Referans yalniz METOT + YOL — sorgu dizesi ATILIR, cunku hata
    // metni bir sizinti yuzeyi degildir.
    stubFetch(500, null);
    const h1 = await jsonFetcher("/api/x?gizli=deger").catch((e) => e as Error);
    expect(h1.message).toContain("500");
    expect(h1.message).toContain("GET /api/x");
    expect(h1.message).not.toContain("undefined");
    expect(h1.message).not.toContain("gizli");

    // json() patlarsa da ayni: catch(() => null) devreye girer.
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => ({
        status: 503,
        ok: false,
        json: async () => {
          throw new Error("bozuk govde");
        },
      })),
    );
    const h2 = await jsonFetcher("/api/x").catch((e) => e as Error);
    expect(h2.message).toContain("503");
    expect(h2.message).not.toContain("undefined");
  });

  it("404/405 SURUM AYRISMASINI soyler ve 'tekrar dene' DEMEZ", async () => {
    // (P173) Bu ikisi tekrar denemekle DEGISMEZ; kullaniciyi bekletmek
    // yerine ne oldugunu soylemek gerekir. (P175) Referans da eklendi.
    stubFetch(404, null);
    const h = await jsonFetcher("/api/panel/yok").catch((e) => e as Error);
    expect(h.message).toContain("/api/panel/yok");
    expect(h.message.toLowerCase()).not.toContain("tekrar dene");
    // HTTP DURUMU HATAYA ILISTIRILIR: yeniden deneme karari buna bakiyor.
    expect((h as Error & { durum?: number }).durum).toBe(404);
  });
});

describe("formatDateTime", () => {
  it("ISO -> tr-TR kisa tarih + saat", () => {
    const s = formatDateTime("2026-07-02T10:05:00.000Z");
    // Kosucunun saat dilimine bagli oldugu icin BICIM dogrulanir, deger degil.
    // tr-TR "short" gun/ay basina sifir KOYMAZ ("2.7.2026" da gecerlidir).
    expect(s).toMatch(/^\d{1,2}\.\d{1,2}\.\d{4} \d{2}:\d{2}$/);
  });

  it("GECERSIZ girdi ekrani bozmaz: ham deger ya da 'Invalid Date' doner",
    () => {
      // Sozlesme: patlamaz. (V8 gecersiz tarihte "Invalid Date" verir.)
      expect(() => formatDateTime("tarih-degil")).not.toThrow();
      expect(() => formatDateTime("")).not.toThrow();
    });
});
