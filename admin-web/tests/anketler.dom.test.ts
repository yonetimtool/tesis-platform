// @vitest-environment jsdom
// (P154 / Asama 7.2) ANKETLER — kendi sayfasi.
//
// Anket yonetimi `/portal` icindeydi ve o sayfa kaldirildi. Bu test o
// tasima sirasinda KAYBOLMAMASI gereken kurali olcer: tek secenekli anket
// oy toplamaz, ONAY toplar (P38). Sunucuya sorup 422 almak yerine
// istemcide soyleniyor — ve istek HIC ATILMIYOR.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import AnketlerPage from "@/app/(protected)/anketler/page";

import { ciz, fetchSahtele } from "./yardimci";

const BOS = { meta: { limit: 50, offset: 0, total: 0 }, items: [] };

afterEach(() => vi.restoreAllMocks());

describe("Anketler", () => {
  it("en az IKI secenek ister — istek ATILMAZ", async () => {
    fetchSahtele({ "/api/panel/anketler": BOS });
    const gonderilen: string[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === "POST") gonderilen.push(String(girdi));
      return onceki(girdi, init);
    }) as typeof fetch;

    ciz(AnketlerPage);
    await waitFor(() =>
      expect(screen.getByLabelText("Anket başlığı")).toBeInTheDocument(),
    );

    await userEvent.type(screen.getByLabelText("Anket başlığı"), "Otopark");
    await userEvent.type(screen.getByLabelText(/Seçenekler/), "Evet");
    await userEvent.click(screen.getByRole("button", { name: "Anketi aç" }));

    await waitFor(() =>
      expect(
        screen.getByText("Başlık ve en az iki seçenek gerekir."),
      ).toBeInTheDocument(),
    );
    expect(gonderilen).toEqual([]);
  });
});
