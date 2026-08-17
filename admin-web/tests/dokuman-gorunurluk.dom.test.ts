// @vitest-environment jsdom
// (P167 ek) DOKUMAN GORUNURLUGU — "sakin gorur mu" kilidi.
//
// =========================================================================
// KILITLENEN KARAR
// =========================================================================
// `tenant_dokuman` TEK BIR ARSIVDIR ve icinde ne oldugu sozlesmede belirli
// DEGIL: yonetim plani ve butce de olabilir, personel sozlesmesi, hukuki
// yazisma veya bir sakinin borc dosyasi da.
//
// Bu yuzden gorunurluk bir BAYRAKTIR ve VARSAYILANI KAPALIDIR. Acik
// varsayilan, yoneticinin farkina varmadan bir dosyayi yayina cikarmasi
// demekti — ve geri almak, o arada indirilmis dosyayi geri getirmezdi.
//
// Test bu varsayilani ve "acarken onay, kapatirken onaysiz" asimetrisini
// olcer.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DokumanlarPage from "@/app/(protected)/dokumanlar/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/dokumanlar",
  useSearchParams: () => new URLSearchParams(),
}));

interface Cagri {
  url: string;
  metot: string;
  govde: Record<string, unknown> | null;
}

const KAPALI = {
  id: "d-1",
  ad: "Personel Sozlesmesi",
  obje_anahtari: "t/dokuman/a.pdf",
  boyut_bayt: 2048,
  yukleyen_ad: "Yonetici A",
  created_at: "2026-03-12T00:00:00Z",
  sakine_acik: false,
};
const ACIK = { ...KAPALI, id: "d-2", ad: "Yonetim Plani", sakine_acik: true };

function sahtele(cagrilar: Cagri[], items = [KAPALI, ACIK]) {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = init?.method ?? "GET";
    if (metot !== "GET") {
      cagrilar.push({
        url,
        metot,
        govde: init?.body ? JSON.parse(String(init.body)) : null,
      });
    }
    const cevap = (govde: unknown) =>
      new Response(JSON.stringify(govde), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    if (url.includes("/api/panel/dokumanlar")) {
      return cevap({ meta: { limit: 25, offset: 0, total: items.length }, items });
    }
    return cevap({});
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("dokuman gorunurlugu", () => {
  it("her satir GORUNURLUK durumunu gosterir", async () => {
    sahtele([]);
    ciz(DokumanlarPage);
    await screen.findByText("Personel Sozlesmesi");
    // Kapali/acik AYRI ROZETLER: yalnizca dugme metnine bakmak,
    // kullanicinin "bu belge simdi nerede" sorusunu tabloyu okuyarak
    // yanitlamasini engellerdi.
    expect(screen.getByText("Kapalı")).toBeInTheDocument();
    expect(screen.getByText("Açık")).toBeInTheDocument();
  });

  it("ACMA onay ISTER ve onaysiz istek GITMEZ", async () => {
    // Acmak bir YAYIN kararidir; geri almak, o arada indirilmis dosyayi
    // geri getirmez.
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    ciz(DokumanlarPage);
    await screen.findByText("Personel Sozlesmesi");

    await userEvent.click(screen.getByRole("button", { name: "Sakine aç" }));
    const diyalog = await screen.findByRole("dialog");
    // Onay diyalogunu IPTAL et. Sorgu DIYALOGA DARALTILIR: "Sakine aç"
    // hem satirda hem diyalogda var ve genis sorgu ikisini karistirirdi.
    await userEvent.click(within(diyalog).getByRole("button", { name: "İptal" }));

    await waitFor(() => expect(cagrilar).toEqual([]));
  });

  it("onaylanan ACMA `sakine_acik: true` GONDERIR", async () => {
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    ciz(DokumanlarPage);
    await screen.findByText("Personel Sozlesmesi");

    await userEvent.click(screen.getByRole("button", { name: "Sakine aç" }));
    const diyalog = await screen.findByRole("dialog");
    await userEvent.click(
      within(diyalog).getByRole("button", { name: "Sakine aç" }),
    );

    await waitFor(() => expect(cagrilar.length).toBe(1));
    expect(cagrilar[0].metot).toBe("PATCH");
    expect(cagrilar[0].url).toContain("/api/panel/dokumanlar/d-1");
    expect(cagrilar[0].govde).toEqual({ sakine_acik: true });
  });

  it("KAPATMA onay SORMAZ — guvenli yon zahmetsiz olmali", async () => {
    // Kapatmak geri donulebilir bir DARALTMADIR. Her daraltmada onay
    // sormak, guvenli yonu zahmetli kilar ve kullaniciyi acik birakmaya
    // iterdi.
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    ciz(DokumanlarPage);
    await screen.findByText("Yonetim Plani");

    await userEvent.click(screen.getByRole("button", { name: "Sakine kapat" }));

    await waitFor(() => expect(cagrilar.length).toBe(1));
    expect(cagrilar[0].govde).toEqual({ sakine_acik: false });
  });

  it("YUKLEME kutusu KAPALI baslar ve secim govdeye gider", async () => {
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    ciz(DokumanlarPage);
    await screen.findByText("Personel Sozlesmesi");

    await userEvent.click(screen.getByRole("button", { name: "Dosya Yükle" }));
    const kutu = await screen.findByLabelText(
      "Sakinler bu dokümanı görebilsin",
    );
    // VARSAYILAN KAPALI — bu testin asil olctugu sey.
    expect((kutu as HTMLInputElement).checked).toBe(false);
  });
});
