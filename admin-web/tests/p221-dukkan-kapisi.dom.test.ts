// @vitest-environment jsdom
// (P221) DUKKAN YUZEYI SUNUCU BAYRAGINA BAGLI — web tarafi.
//
// =========================================================================
// KILITLENEN KARAR
// =========================================================================
// Dukkan pazar yeri henuz dolu degil. Yuzeyi TAMAMEN kaldirmak yerine
// yer tutucu gostermeyi sectik; ama karar SUNUCUDA yasiyor: acmak icin
// yeni bir web dagitimi degil, tek bir ortam degiskeni yetiyor (mobilde
// ayni bayrak magaza turundan kurtariyor).
//
// VARSAYILAN KAPALI. Olculen sey tam da bu: bayrak eksik gelirse, uc
// 500 donerse, govde bozuksa ya da yanit henuz gelmemisse — HEPSINDE
// "yakinda" gorunur. "Bilmiyorsak acalim", hazir olmayan bos bir pazar
// yerini kullaniciya gostermek olurdu.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import YerelIsletmeler from "@/app/(protected)/yerel-isletmeler/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/yerel-isletmeler",
  useSearchParams: () => new URLSearchParams(),
}));

// SAHTE, HTTP KATMANINA KONUR (P200 dersi): `useDukkanAcik`i taklit
// etmek, bayragi okuyan katmani hic olcmezdi.
function sahtele(ozellikYaniti: () => Response) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    if (url.includes("/api/ozellikler")) return ozellikYaniti();
    const cevap = (govde: unknown) =>
      new Response(JSON.stringify(govde), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    if (url.includes("/lokasyon/il")) return cevap([]);
    if (url.includes("/kategori")) return cevap([]);
    return cevap({ items: [], meta: { total: 0 } });
  }) as typeof fetch;
}

const json = (govde: unknown, status = 200) =>
  new Response(JSON.stringify(govde), {
    status,
    headers: { "Content-Type": "application/json" },
  });

afterEach(() => vi.restoreAllMocks());

const YAKINDA = "Yerel işletmeler hazırlanıyor";
const SUZGEC = "İl";

describe("P221 web dukkan kapisi", () => {
  it("bayrak KAPALI gelirse YAKINDA gorunur, pazar yeri GORUNMEZ", async () => {
    sahtele(() => json({ dukkan: false }));
    ciz(YerelIsletmeler);
    expect(await screen.findByText(YAKINDA)).toBeInTheDocument();
    expect(screen.queryByLabelText(SUZGEC)).toBeNull();
  });

  it("ALAN HIC YOKSA (eski sunucu) yine KAPALI", async () => {
    sahtele(() => json({}));
    ciz(YerelIsletmeler);
    expect(await screen.findByText(YAKINDA)).toBeInTheDocument();
  });

  it("UC 500 donerse KAPALI — hata acik varsayilana DUSMEZ", async () => {
    sahtele(() => json({ detail: "bozuk" }, 500));
    ciz(YerelIsletmeler);
    expect(await screen.findByText(YAKINDA)).toBeInTheDocument();
  });

  it("AG HATASINDA KAPALI", async () => {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      if (String(girdi).includes("/api/ozellikler")) throw new Error("ag");
      return json({ items: [], meta: { total: 0 } });
    }) as typeof fetch;
    ciz(YerelIsletmeler);
    expect(await screen.findByText(YAKINDA)).toBeInTheDocument();
  });

  it("BEKLENMEDIK TIP (dukkan: 'evet') KAPALI sayilir", async () => {
    sahtele(() => json({ dukkan: "evet" }));
    ciz(YerelIsletmeler);
    expect(await screen.findByText(YAKINDA)).toBeInTheDocument();
  });

  // TERS YON: kapi gercekten aciliyor mu? Bu olmadan, sayfayi bastan
  // silmek de testi gecerdi.
  it("bayrak ACIK gelirse PAZAR YERI gorunur", async () => {
    sahtele(() => json({ dukkan: true }));
    ciz(YerelIsletmeler);
    await waitFor(() =>
      expect(screen.getByLabelText(SUZGEC)).toBeInTheDocument(),
    );
    expect(screen.queryByText(YAKINDA)).toBeNull();
  });

  it("YAKINDA metninde TARIH TAAHHUDU yok", async () => {
    sahtele(() => json({ dukkan: false }));
    ciz(YerelIsletmeler);
    const metin = (await screen.findByText(YAKINDA)).parentElement?.textContent ?? "";
    for (const yasak of [
      "gün", "hafta", "ay içinde", "2026", "2027", "yakında açılıyor",
    ]) {
      expect(metin.toLowerCase()).not.toContain(yasak.toLowerCase());
    }
  });
});
