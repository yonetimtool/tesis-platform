// @vitest-environment jsdom
// (P154 / Asama 5) SURUKLE-BIRAK YERLESIMI.
//
// Olculen uc sey:
//   1. KLAVYE ESDEGERI VAR — surukleme tek yol degil. Brief'in kendi
//      sarti "klavye navigasyonu"; fare suruklemesi klavyeyle
//      ERISILEMEZ ve tek yol olsaydi ekran okuyucu/klavye kullanicisi
//      yerlesimi hic degistiremezdi.
//   2. TEK ISTEK: yirmi dairelik bir katta yirmi PATCH, arada kesilme
//      riski demekti — yarim uygulanmis bir siralama, gorulen duzenle
//      saklanani ayirirdi.
//   3. YENIDEN NUMARALANDIRMA: etkilenen katin TAMAMI 1..n olur; iki
//      daireyi takas etmek bosluk ya da cift `sira` birakabilirdi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BuildingEditorPage from "@/app/(protected)/building-editor/page";

import { ciz, fetchSahtele } from "./yardimci";

const BLOKLAR = { items: [{ id: "b1", ad: "A", unit_sayisi: 3 }] };
const DAIRELER = {
  meta: { limit: 200, offset: 0, total: 3 },
  items: [
    { id: "u1", no: "A-1", blok: "A", kat: 1, sira: 1, aktif: true, unit_tip_ad: null },
    { id: "u2", no: "A-2", blok: "A", kat: 1, sira: 2, aktif: true, unit_tip_ad: null },
    { id: "u3", no: "A-3", blok: "A", kat: 1, sira: 3, aktif: true, unit_tip_ad: null },
  ],
};

afterEach(() => vi.restoreAllMocks());

function govdeYakala(): Record<string, unknown>[] {
  fetchSahtele({ "/api/blocks": BLOKLAR, "/api/units": DAIRELER });
  const govdeler: Record<string, unknown>[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    if (String(girdi).includes("/units/siralama") && init?.body) {
      govdeler.push(JSON.parse(String(init.body)));
    }
    return onceki(girdi, init);
  }) as typeof fetch;
  return govdeler;
}

async function blogaGir() {
  ciz(BuildingEditorPage);
  // Kutucuk "Blok A" yazar (`blokEtiketi`), duz "A" degil.
  const kutu = await screen.findByText(/Blok A/);
  await userEvent.click(kutu);
}

describe("(P154/5) bina yerlesimi — siralama", () => {
  it("KLAVYE ile tasinir (surukleme TEK YOL degil)", async () => {
    const govdeler = govdeYakala();
    await blogaGir();

    const daire = await screen.findByLabelText(/A-1 dairesi/);
    daire.focus();
    // Alt+Sag: kat icinde bir sira ileri. Ciplak ok tuslari sayfayi
    // kaydirir; odaklanmis bir kutuda kaydirmayi yutmak klavye
    // kullanicisini sayfada hapsederdi — bu yuzden Alt.
    await userEvent.keyboard("{Alt>}{ArrowRight}{/Alt}");

    await waitFor(() => expect(govdeler.length).toBe(1));
    const satirlar = govdeler[0].satirlar as { id: string; sira: number }[];
    // A-1 ikinci siraya gecti, A-2 basa dondu.
    expect(satirlar.find((x) => x.id === "u1")?.sira).toBe(2);
    expect(satirlar.find((x) => x.id === "u2")?.sira).toBe(1);
  });

  it("TEK ISTEKTE gonderilir ve KAT TAMAMI yeniden numaralanir", async () => {
    const govdeler = govdeYakala();
    await blogaGir();

    const daire = await screen.findByLabelText(/A-3 dairesi/);
    daire.focus();
    await userEvent.keyboard("{Alt>}{ArrowLeft}{/Alt}");

    await waitFor(() => expect(govdeler.length).toBe(1));
    const satirlar = govdeler[0].satirlar as { id: string; sira: number }[];
    // UC daire de tek istekte, 1..3 kesintisiz.
    expect(satirlar).toHaveLength(3);
    expect(satirlar.map((x) => x.sira).sort()).toEqual([1, 2, 3]);
  });

  it("KATIN BASINDA sola tasima ISTEK ATMAZ", async () => {
    // Sinirdan tasmak, sunucuya hicbir sey degistirmeyen bir yazma
    // gondermek olurdu.
    const govdeler = govdeYakala();
    await blogaGir();

    const daire = await screen.findByLabelText(/A-1 dairesi/);
    daire.focus();
    await userEvent.keyboard("{Alt>}{ArrowLeft}{/Alt}");

    await new Promise((r) => setTimeout(r, 50));
    expect(govdeler).toEqual([]);
  });

  it("ALTSIZ ok tuslari yerlesimi DEGISTIRMEZ", async () => {
    const govdeler = govdeYakala();
    await blogaGir();

    const daire = await screen.findByLabelText(/A-1 dairesi/);
    daire.focus();
    await userEvent.keyboard("{ArrowRight}");

    await new Promise((r) => setTimeout(r, 50));
    expect(govdeler).toEqual([]);
  });
});
