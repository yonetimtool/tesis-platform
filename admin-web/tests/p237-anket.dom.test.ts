// @vitest-environment jsdom
// (P237 §3) ANKET — web yuzeyi: hedef kitle, anonimlik, katilim, dokum.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import AnketlerPage from "@/app/(protected)/anketler/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

/** POST govdelerini yakalar — `fetchSahtele` govde tutmuyor. */
function govdeleriYakala(): string[] {
  const govdeler: string[] = [];
  const asil = globalThis.fetch;
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method === "POST" && init.body) govdeler.push(String(init.body));
    return asil(g, init);
  }) as typeof fetch;
  return govdeler;
}

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

function anket(over: Record<string, unknown> = {}) {
  return {
    id: "a1",
    baslik: "Otopark düzeni",
    aciklama: null,
    gorsel_url: null,
    baslangic_at: null,
    kapanis_at: null,
    aktif: true,
    acik: true,
    anonim: false,
    hedef_roller: [],
    hedef_sakin_tipi: null,
    hedef_kisi: 40,
    toplam_oy: 10,
    oy_verdim: false,
    secenekler: [
      { id: "s1", metin: "Evet", sira: 0, oy: 7 },
      { id: "s2", metin: "Hayır", sira: 1, oy: 3 },
    ],
    created_at: "2026-09-01T00:00:00Z",
    ...over,
  };
}

const DOKUM = {
  meta: { limit: 200, offset: 0, total: 1 },
  items: [
    {
      user_id: "u1", ad: "Ali Veli", secenek_id: "s1",
      secenek_metin: "Evet", created_at: "2026-09-02T10:00:00Z",
    },
  ],
};

afterEach(() => vi.restoreAllMocks());

describe("Anketler sayfasi", () => {
  it("KATILIM ORANI cizilir: 10/40 = %25", async () => {
    fetchSahtele({ "/api/panel/anketler": { items: [anket()] } });
    ciz(AnketlerPage);
    await waitFor(() => expect(el("anket-katilim-a1")).toBeTruthy());
    expect(el("anket-katilim-a1")?.textContent).toContain("25");
  });

  it("PAYDA YOKSA oran CIZILMEZ — uydurma yuzde uretilmez", async () => {
    // Sakine `hedef_kisi` gelmez; "0 oy" ile "olcusu yok" ayni sey degil.
    fetchSahtele({
      "/api/panel/anketler": { items: [anket({ hedef_kisi: null })] },
    });
    ciz(AnketlerPage);
    await waitFor(() => expect(screen.getByText("Otopark düzeni")).toBeTruthy());
    expect(el("anket-katilim-a1")).toBeNull();
  });

  it("ANONIM ankette DOKUM ISTEGI HIC ATILMAZ", async () => {
    // Arka uc 409 doner (veri YOK). Istegi atmak, kullaniciya anlamsiz
    // bir hata gostermek olurdu.
    fetchSahtele({
      "/api/panel/anketler": { items: [anket({ anonim: true })] },
    });
    ciz(AnketlerPage);
    await waitFor(() => expect(el("anket-sonuc-a1")).toBeTruthy());
    await userEvent.click(el("anket-sonuc-a1") as HTMLElement);
    await waitFor(() => expect(el("anket-sonuc-panosu")).toBeTruthy());
    expect(screen.getByText(/kimler oy verdiği kaydedilmez/i)).toBeTruthy();
    expect(cagrilanUrller().some((u) => u.includes("/oylar"))).toBe(false);
  });

  it("ADLI ankette DOKUM istenir ve AD cizilir", async () => {
    fetchSahtele({
      "/api/panel/anketler": { items: [anket()] },
      "/api/panel/anketler/a1/oylar": DOKUM,
    });
    ciz(AnketlerPage);
    await waitFor(() => expect(el("anket-sonuc-a1")).toBeTruthy());
    await userEvent.click(el("anket-sonuc-a1") as HTMLElement);
    await waitFor(() => expect(screen.getByText("Ali Veli")).toBeTruthy());
    expect(cagrilanUrller().some((u) => u.includes("/oylar"))).toBe(true);
  });

  it("FORM: EN AZ IKI madde — tek maddede istek ATILMAZ", async () => {
    fetchSahtele({ "/api/panel/anketler": { items: [] } });
    const govdeler = govdeleriYakala();
    ciz(AnketlerPage);
    await userEvent.click(el("anket-ekle-ac") as HTMLElement);
    await userEvent.type(el("anket-baslik") as HTMLElement, "Tek");
    await userEvent.type(el("anket-maddeler") as HTMLElement, "Tamam");
    await userEvent.click(el("anket-kaydet") as HTMLElement);
    // Ipucu metni de "en az iki" iceriyor; hata satirinin BELIRMESI
    // olculur (bir tane -> iki tane).
    await waitFor(() =>
      expect(screen.getAllByText(/en az iki/i).length).toBeGreaterThan(1),
    );
    // POST HIC ATILMADI: govde yakalayicisi bos.
    expect(govdeler).toEqual([]);
  });

  it("FORM: HEDEF KITLE ve ANONIM govdeye girer", async () => {
    fetchSahtele({ "/api/panel/anketler": { items: [] } });
    const govdeler = govdeleriYakala();
    ciz(AnketlerPage);
    await userEvent.click(el("anket-ekle-ac") as HTMLElement);
    await userEvent.type(el("anket-baslik") as HTMLElement, "Otopark");
    await userEvent.type(
      el("anket-maddeler") as HTMLElement,
      "Evet\nHayır",
    );
    await userEvent.click(el("anket-hedef-resident") as HTMLElement);
    await userEvent.click(el("anket-anonim") as HTMLElement);
    await userEvent.click(el("anket-kaydet") as HTMLElement);
    await waitFor(() => expect(govdeler.length).toBe(1));
    const g = JSON.parse(govdeler[0]);
    expect(g.anonim).toBe(true);
    expect(g.hedef_roller).toContain("resident");
    expect(g.secenekler).toEqual([
      { metin: "Evet", sira: 0 },
      { metin: "Hayır", sira: 1 },
    ]);
  });

  it("MALIK/KIRACI ayrimi: yalniz SAKIN hedeflendiginde cizilir", async () => {
    // "yalniz guvenlik ekibi" + "yalniz malikler" birlikte anlamsiz;
    // sunucu da ayrimi personele UYGULAMAZ.
    fetchSahtele({ "/api/panel/anketler": { items: [] } });
    ciz(AnketlerPage);
    await userEvent.click(el("anket-ekle-ac") as HTMLElement);
    // Hedef BOSKEN (herkes) ayrim gorunur.
    expect(el("anket-sakin-tipi")).toBeTruthy();

    await userEvent.click(el("anket-hedef-security") as HTMLElement);
    expect(el("anket-sakin-tipi")).toBeNull();

    // SAKIN de eklenince GERI GELIR.
    await userEvent.click(el("anket-hedef-resident") as HTMLElement);
    expect(el("anket-sakin-tipi")).toBeTruthy();
  });

  it("GIZLENEN ayrim GOVDEYE GIRMEZ", async () => {
    fetchSahtele({ "/api/panel/anketler": { items: [] } });
    const govdeler = govdeleriYakala();
    ciz(AnketlerPage);
    await userEvent.click(el("anket-ekle-ac") as HTMLElement);
    await userEvent.type(el("anket-baslik") as HTMLElement, "Otopark");
    await userEvent.type(el("anket-maddeler") as HTMLElement, "Evet\nHayır");

    // Once malik secilir...
    await userEvent.selectOptions(el("anket-sakin-tipi") as HTMLElement, "malik");
    // ...sonra hedef YALNIZ GUVENLIK yapilir: ayrim gizlenir VE temizlenir.
    await userEvent.click(el("anket-hedef-security") as HTMLElement);
    await userEvent.click(el("anket-kaydet") as HTMLElement);

    await waitFor(() => expect(govdeler.length).toBe(1));
    const g = JSON.parse(govdeler[0]);
    expect(g.hedef_sakin_tipi).toBeNull();
  });

  it("ANONIMLIK UYARISI formda, KAYDETMEDEN ONCE gorunur", async () => {
    fetchSahtele({ "/api/panel/anketler": { items: [] } });
    ciz(AnketlerPage);
    await userEvent.click(el("anket-ekle-ac") as HTMLElement);
    expect(screen.getByText(/DEĞİŞTİRİLEMEZ/)).toBeTruthy();
  });
});
