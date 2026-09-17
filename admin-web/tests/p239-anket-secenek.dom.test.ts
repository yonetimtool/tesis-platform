// @vitest-environment jsdom
// (P239 §7) ANKET SECENEKLERI — AYRI KUTULAR, "+" ILE EKLE, TEK TEK SIL.
//
// OLCULEN KUSUR: secenekler tek bir cok-satirli metin alanindaydi.
// Kullanici kac secenek yazdigini goremiyor, bos satir sessizce
// yutuluyor, silmek icin satiri isaretlemek gerekiyordu.
//
// SUNUCUYA GIDEN GOVDE DEGISMEDI ({metin, sira}); bu testin son maddesi
// tam olarak onu olcer — mevcut anketler ve arka uc etkilenmesin diye.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import AnketlerPage from "@/app/(protected)/anketler/page";

import { ciz, fetchSahtele } from "./yardimci";

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

function govdeleriYakala(): string[] {
  const govdeler: string[] = [];
  const asil = globalThis.fetch;
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method === "POST" && init.body) govdeler.push(String(init.body));
    return asil(g, init);
  }) as typeof fetch;
  return govdeler;
}

async function formuAc() {
  fetchSahtele({ "/api/panel/anketler": { items: [] } });
  const govdeler = govdeleriYakala();
  ciz(AnketlerPage);
  await userEvent.click(el("anket-ekle-ac") as HTMLElement);
  return govdeler;
}

afterEach(() => vi.restoreAllMocks());

describe("(P239 §7) anket secenek kutulari", () => {
  it("IKI KUTU ACIK BASLAR, ucuncu YOK", async () => {
    await formuAc();
    expect(el("anket-madde-0")).toBeTruthy();
    expect(el("anket-madde-1")).toBeTruthy();
    expect(el("anket-madde-2")).toBeNull();
  });

  it('"+" HER BASISTA BIR KUTU EKLER', async () => {
    await formuAc();
    await userEvent.click(el("anket-madde-ekle") as HTMLElement);
    await waitFor(() => expect(el("anket-madde-2")).toBeTruthy());
    await userEvent.click(el("anket-madde-ekle") as HTMLElement);
    await waitFor(() => expect(el("anket-madde-3")).toBeTruthy());
  });

  it("IKI KUTUDA SILME KAPALI — gizli DEGIL, KAPALI", async () => {
    // Gizlenen dugme "neden yok" sorusunu dogurur; kapali dugme
    // ipucu metniyle KURALI soyler.
    await formuAc();
    const sil = el("anket-madde-sil-0") as HTMLButtonElement;
    expect(sil).toBeTruthy();
    expect(sil.disabled).toBe(true);
    expect(sil.title).toMatch(/en az iki/i);
  });

  it("UC KUTUDA SILME ACILIR ve DOGRU kutuyu siler", async () => {
    await formuAc();
    await userEvent.click(el("anket-madde-ekle") as HTMLElement);
    await waitFor(() => expect(el("anket-madde-2")).toBeTruthy());
    await userEvent.type(el("anket-madde-0") as HTMLElement, "A");
    await userEvent.type(el("anket-madde-1") as HTMLElement, "B");
    await userEvent.type(el("anket-madde-2") as HTMLElement, "C");

    expect((el("anket-madde-sil-1") as HTMLButtonElement).disabled).toBe(false);
    await userEvent.click(el("anket-madde-sil-1") as HTMLElement);

    // ORTADAKI gitti: kalanlar A ve C — ve SILME YENIDEN KAPANDI.
    await waitFor(() => expect(el("anket-madde-2")).toBeNull());
    expect((el("anket-madde-0") as HTMLInputElement).value).toBe("A");
    expect((el("anket-madde-1") as HTMLInputElement).value).toBe("C");
    expect((el("anket-madde-sil-0") as HTMLButtonElement).disabled).toBe(true);
  });

  it("GOVDE DEGISMEDI: {metin, sira} listesi, BOS kutular ATILIR", async () => {
    const govdeler = await formuAc();
    await userEvent.type(el("anket-baslik") as HTMLElement, "Otopark");
    await userEvent.click(el("anket-madde-ekle") as HTMLElement);
    await waitFor(() => expect(el("anket-madde-2")).toBeTruthy());
    await userEvent.type(el("anket-madde-0") as HTMLElement, "Evet");
    // 1 BOS BIRAKILIR — sira, gonderilenlere gore YENIDEN verilmeli.
    await userEvent.type(el("anket-madde-2") as HTMLElement, "Hayır");
    await userEvent.click(el("anket-kaydet") as HTMLElement);

    await waitFor(() => expect(govdeler.length).toBe(1));
    expect(JSON.parse(govdeler[0]).secenekler).toEqual([
      { metin: "Evet", sira: 0 },
      { metin: "Hayır", sira: 1 },
    ]);
  });
});
