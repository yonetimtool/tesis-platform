// @vitest-environment jsdom
// (P237 §2) GOREV ALT ADIMLARI — web yuzeyi.
//
// OLCULEN SINIF (P189/P226/P229'da uc kez tekrarladi): arka uc ve sayfa
// ayri ayri dogru, ARADAKI HALKA olculmemis. Burada olculen sey ekranin
// GERCEKTEN hangi URL'e hangi metotla gittigi ve donen govdeyi nasil
// cizdigi.
import { screen, waitFor } from "@testing-library/react";
import { createElement } from "react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import { GorevAdimlari } from "@/components/GorevAdimlari";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

const ADIMLAR = {
  meta: { limit: 3, offset: 0, total: 3 },
  items: [
    {
      id: "a1", task_id: "t1", sira: 0, ad: "A blok", foto_zorunlu: false,
      tamamlandi: true, tamamlayan_user_id: "u1", tamamlayan_ad: "Ali Guard",
      tamamlanma_zamani: "2026-09-15T08:00:00Z", foto_key: "g/x.jpg",
      foto_url: "https://s/x.jpg", notlar: "bitti",
    },
    {
      id: "a2", task_id: "t1", sira: 1, ad: "B blok", foto_zorunlu: false,
      tamamlandi: false,
    },
    {
      id: "a3", task_id: "t1", sira: 2, ad: "C blok", foto_zorunlu: true,
      tamamlandi: false,
    },
  ],
};

/** `ciz` prop almiyor (ortak sarmalayici); bileseni sabit prop'la sarar. */
const Sarmal = () => createElement(GorevAdimlari, { taskId: "t1" });

/** Depo kurali: `data-test` (testid DEGIL). */
const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

afterEach(() => vi.restoreAllMocks());

describe("Gorev alt adimlari", () => {
  it("ILERLEME 1/3 yazar ve TAMAMLAYANI adiyla gosterir", async () => {
    fetchSahtele({ "/api/tasks/t1/adimlar": ADIMLAR });
    ciz(Sarmal);
    await waitFor(() =>
      expect(el("gorev-adim-ilerleme")?.textContent).toContain("1/3"),
    );
    expect(screen.getByText(/Ali Guard/)).toBeTruthy();
    expect(screen.getByText("A blok")).toBeTruthy();
  });

  it("FOTO ZORUNLU adimda DOSYA SECICI cizilir, duz dugme DEGIL", async () => {
    // Dogrudan "Tamamla" dugmesi 422 uretirdi (`gorev_adimi_foto_zorunlu`);
    // kullaniciya once fotograf sordurmak, o 422'yi hic dogurmamak demek.
    fetchSahtele({ "/api/tasks/t1/adimlar": ADIMLAR });
    ciz(Sarmal);
    await waitFor(() => expect(screen.getByText("C blok")).toBeTruthy());
    expect(el("gorev-adim-foto-a3")).toBeTruthy();
    expect(el("gorev-adim-tamamla-a3")).toBeNull();
    // Fotosuz adimda TAM TERSI.
    expect(el("gorev-adim-tamamla-a2")).toBeTruthy();
    expect(el("gorev-adim-foto-a2")).toBeNull();
  });

  it("TAMAMLA dogru URL'e POST atar", async () => {
    fetchSahtele({
      "/api/tasks/t1/adimlar": ADIMLAR,
      "/api/tasks/t1/adimlar/a2/tamamla": ADIMLAR.items[1],
    });
    ciz(Sarmal);
    await waitFor(() => expect(el("gorev-adim-tamamla-a2")).toBeTruthy());
    await userEvent.click(el("gorev-adim-tamamla-a2") as HTMLElement);
    await waitFor(() =>
      expect(
        cagrilanUrller().some((u) => u.includes("/api/tasks/t1/adimlar/a2/tamamla")),
      ).toBe(true),
    );
  });

  it("ADIM EKLE: bos adda istek ATILMAZ", async () => {
    fetchSahtele({ "/api/tasks/t1/adimlar": ADIMLAR });
    ciz(Sarmal);
    await waitFor(() => expect(el("gorev-adim-ekle")).toBeTruthy());
    const dugme = el("gorev-adim-ekle") as HTMLButtonElement;
    expect(dugme.disabled).toBe(true);
  });

  it("ADIMI OLMAYAN gorevde BOS DURUM — '0/0' degil aciklama", async () => {
    fetchSahtele({
      "/api/tasks/t1/adimlar": { meta: { limit: 0, offset: 0, total: 0 }, items: [] },
    });
    ciz(Sarmal);
    await waitFor(() =>
      expect(screen.getByText(/alt adımlara bölünmedi/i)).toBeTruthy(),
    );
  });
});
