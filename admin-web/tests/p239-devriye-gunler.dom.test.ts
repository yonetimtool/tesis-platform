// @vitest-environment jsdom
// (P239 §4) DEVRIYE PLANINDA HAFTALIK GUN SECIMI + BIR KERELIK EK GUNLER.
//
// ===========================================================================
// NEDEN TAKVIM DEGIL CIP
// ===========================================================================
// Devriye plani TEKRAR EDEN bir seydir. Somut tarih listesi plani
// tekrarsizlastirir ve ufuk dolunca elle beslenmesi gerekirdi. Somut
// tarih secimi VARDIYA planinin isidir. Bu yuzden haftalik secim CIP,
// bir kerelik ek gunler ise TARIH listesi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import PatrolPlansPage from "@/app/(protected)/patrol-plans/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/patrol-plans",
  useSearchParams: () => new URLSearchParams(),
}));

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

function plan(over: Record<string, unknown> = {}) {
  return {
    id: "p1",
    ad: "Gece devriyesi",
    shift_id: null,
    baslangic_saat: "22:00",
    bitis_saat: "06:00",
    periyot_dakika: 60,
    gunler: null,
    ek_tarihler: null,
    aktif: true,
    created_at: "2026-08-01T00:00:00Z",
    ...over,
  };
}

function sahtele(planlar: unknown[] = [plan()]) {
  const cagrilar: { url: string; metot: string; govde?: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      metot: init?.method ?? "GET",
      govde: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const yanit = (govde: unknown) =>
      ({ ok: true, status: 200, json: async () => govde }) as Response;
    if (/\/api\/patrol-plans\/[^/]+\/checkpoints/.test(url)) return yanit([]);
    if (url.includes("/api/patrol-plans")) {
      return yanit({ meta: { limit: 25, offset: 0, total: planlar.length }, items: planlar });
    }
    return yanit({ meta: { limit: 25, offset: 0, total: 0 }, items: [] });
  }) as typeof fetch;
  return cagrilar;
}

async function formuAc() {
  await userEvent.click(await screen.findByRole("button", { name: "Yeni plan" }));
  await screen.findByRole("dialog");
}

afterEach(() => vi.restoreAllMocks());

describe("(P239 §4) devriye gun secimi", () => {
  it("HICBIR GUN SECILI DEGILKEN 'her gün' YAZAR", async () => {
    // Bos bir satir "secmedim mi, yoksa hicbir gun mu" sorusunu
    // dogururdu — ikisi cok farkli seyler.
    sahtele();
    ciz(PatrolPlansPage);
    await formuAc();
    expect(el("devriye-gun-her-gun")).toBeTruthy();
  });

  it("SECILEN GUNLER govdeye ISO NUMARASIYLA ve SIRALI gider", async () => {
    // JS getDay() 0=Pazar der; veritabani ve Python ISO kullanir
    // (1=Pazartesi). Cevrim tek yerde yapilmali.
    const cagrilar = sahtele();
    ciz(PatrolPlansPage);
    await formuAc();
    await userEvent.type(screen.getByLabelText(/Ad/), "Yeni plan");
    // ONCE persembe, SONRA pazartesi: siralama istemcide yapilmali.
    await userEvent.click(el("devriye-gun-4") as HTMLElement);
    await userEvent.click(el("devriye-gun-1") as HTMLElement);
    expect(el("devriye-gun-her-gun")).toBeNull();

    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.metot === "POST");
      expect(post, "POST atilmadi").toBeTruthy();
      expect((post!.govde as Record<string, unknown>).gunler).toEqual([1, 4]);
    });
  });

  it("GUN SECILMEZSE null gider — BOS DIZI DEGIL", async () => {
    // Bos dizi sunucuda 422 ve dogru: plan aktif gorunurken hicbir
    // pencere uretmeyen sessiz bir kapali hal olurdu.
    const cagrilar = sahtele();
    ciz(PatrolPlansPage);
    await formuAc();
    await userEvent.type(screen.getByLabelText(/Ad/), "Yeni plan");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.metot === "POST");
      expect(post).toBeTruthy();
      expect((post!.govde as Record<string, unknown>).gunler).toBeNull();
    });
  });

  it("CIP TEKRAR TIKLANINCA secim KALKAR", async () => {
    sahtele();
    ciz(PatrolPlansPage);
    await formuAc();
    await userEvent.click(el("devriye-gun-1") as HTMLElement);
    expect((el("devriye-gun-1") as HTMLElement).getAttribute("aria-pressed")).toBe("true");
    await userEvent.click(el("devriye-gun-1") as HTMLElement);
    expect((el("devriye-gun-1") as HTMLElement).getAttribute("aria-pressed")).toBe("false");
    expect(el("devriye-gun-her-gun")).toBeTruthy();
  });

  it("DUZENLEMEDE mevcut gunler FORMA YUKLENIR", async () => {
    // Yuklenmeseydi kaydet'e basmak, plani sessizce "her gun"e
    // cevirirdi.
    sahtele([plan({ gunler: [2, 5] })]);
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getAllByRole("button", { name: "Düzenle" })[0]);
    await screen.findByRole("dialog");
    expect((el("devriye-gun-2") as HTMLElement).getAttribute("aria-pressed")).toBe("true");
    expect((el("devriye-gun-5") as HTMLElement).getAttribute("aria-pressed")).toBe("true");
    expect((el("devriye-gun-1") as HTMLElement).getAttribute("aria-pressed")).toBe("false");
  });

  it("EK TARIH eklenir, tekrar EKLENEMEZ, silinir ve govdeye girer", async () => {
    const cagrilar = sahtele();
    ciz(PatrolPlansPage);
    await formuAc();
    await userEvent.type(screen.getByLabelText(/Ad/), "Yeni plan");

    const girdi = el("devriye-ek-tarih-girdi") as HTMLInputElement;
    await userEvent.type(girdi, "2026-08-30");
    await userEvent.click(el("devriye-ek-tarih-ekle") as HTMLElement);
    await waitFor(() => expect(el("devriye-ek-tarih-sil-2026-08-30")).toBeTruthy());

    // AYNI TARIH IKINCI KEZ: ekleme dugmesi KAPALI (sunucu zaten
    // tekillestiriyor ama kullaniciya once burada soylenir).
    await userEvent.type(girdi, "2026-08-30");
    expect((el("devriye-ek-tarih-ekle") as HTMLButtonElement).disabled).toBe(true);

    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.metot === "POST");
      expect(post).toBeTruthy();
      expect((post!.govde as Record<string, unknown>).ek_tarihler).toEqual([
        "2026-08-30",
      ]);
    });
  });

  it("EK TARIH YOKSA null gider", async () => {
    const cagrilar = sahtele();
    ciz(PatrolPlansPage);
    await formuAc();
    await userEvent.type(screen.getByLabelText(/Ad/), "Yeni plan");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.metot === "POST");
      expect(post).toBeTruthy();
      expect((post!.govde as Record<string, unknown>).ek_tarihler).toBeNull();
    });
  });
});
