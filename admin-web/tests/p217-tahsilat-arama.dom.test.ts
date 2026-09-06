// @vitest-environment jsdom
// (P217 §3) TAHSILAT: ARAMA ALANI KOSULLU.
//
// ===========================================================================
// KALDIRMADAN ONCE OLCTUM
// ===========================================================================
// Sikayet: "daire ve kisi zaten ayri ayri secilebiliyor, arama alani
// gereksiz kalabalik". Alan KALDIRILMADI cunku olcum, seciclerin
// YAPAMADIGI bir is yaptigini gosterdi: kisi seciciyi besleyen UC
// listeyi de (borclular / tum kisiler / daire sakinleri) suzuyor.
// 500 kisilik bir sitede daire secmeden kisi bulmak, aramasiz bir
// acilir listede pratikte imkansiz.
//
// Ama sikayet de hakli: daire secilince liste 2-3 kisiye iniyor ve
// orada arama fazladan bir alan. KARAR: liste UZUNKEN gorunur.
//
// TAKLIT HTTP KATMANINDA (P200).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TahsilatlarPage from "@/app/(protected)/finans/tahsilatlar/page";

import { ciz } from "./yardimci";

function kisi(i: number) {
  return { id: `k${i}`, ad: `Kişi ${i}`, unitId: "u1", unitNo: "A-1",
           userId: `k${i}`, kalanKurus: 1000 + i };
}

/** [borcluSayisi] kadar borclu donduren sahte sunucu. */
function sunucu(borcluSayisi: number) {
  const borclular = Array.from({ length: borcluSayisi }, (_, i) => kisi(i));
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    // BORCLULAR `/api/panel/yaslandirma`dan KOVA yapisiyla gelir
    // (`useBorclular`). Ilk yazimda duz `items` dondurdum ve liste BOS
    // kaldi — yani "uzun liste" senaryosu hic kurulmamisti.
    const govde = url.includes("yaslandirma")
      ? { kovalar: [{ kova: "0-30", daireler: borclular.map((b) => ({
            unit_id: b.unitId, unit_no: b.unitNo, kalan_kurus: b.kalanKurus,
            borclu_ad: b.ad, borclu_user_id: b.userId })) }],
          toplam_kalan_kurus: 0, toplam_daire: borclular.length }
      : url.includes("units")
        ? { meta: { total: 1 }, items: [{ id: "u1", no: "A-1", blok: "A", aktif: true }] }
        : url.includes("users")
          ? { meta: { total: borcluSayisi }, items: borclular.map((b) => ({ id: b.id, ad: b.ad, role: "resident" })) }
          : url.includes("kasa")
            ? { meta: { total: 1 }, items: [{ id: "kasa1", ad: "Kasa", aktif: true }] }
            : { meta: { limit: 20, offset: 0, total: 0 }, items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

async function modaliAc() {
  const k = userEvent.setup();
  await k.click(await screen.findByRole("button", { name: /^\+?\s*(yeni|tahsilat)/i }));
  const modallar = await screen.findAllByRole("dialog");
  return { k, modal: modallar[modallar.length - 1] };
}

afterEach(() => vi.restoreAllMocks());

describe("(P217 §3) kişi arama alanı", () => {
  it("KISA listede GORUNMEZ (şikâyetin çözümü)", async () => {
    sunucu(3);
    ciz(TahsilatlarPage);
    const { modal } = await modaliAc();
    await waitFor(() =>
      expect(within(modal).queryByTestId?.("tahsilat-kisi-ara")
        ?? modal.querySelector('[data-test="tahsilat-kisi-ara"]')).toBeNull(),
    );
    // Ama KISI SECICI duruyor: alan gizlendi, islev kaybolmadi.
    expect(modal.querySelector('[data-test="tahsilat-kisi"]')).not.toBeNull();
    expect(modal.querySelector('[data-test="tahsilat-daire"]')).not.toBeNull();
  });

  it("UZUN listede GORUNUR (aramasız seçilemezdi)", async () => {
    sunucu(25);
    ciz(TahsilatlarPage);
    const { modal } = await modaliAc();
    await waitFor(() =>
      expect(modal.querySelector('[data-test="tahsilat-kisi-ara"]')).not.toBeNull(),
    );
  });

  it("UZUN listede arama GERCEKTEN suzer", async () => {
    sunucu(25);
    ciz(TahsilatlarPage);
    const { k, modal } = await modaliAc();
    const arama = await waitFor(() => {
      const a = modal.querySelector('[data-test="tahsilat-kisi-ara"]');
      expect(a).not.toBeNull();
      return a as HTMLInputElement;
    });
    const secici = () => modal.querySelector('[data-test="tahsilat-kisi"]') as HTMLSelectElement;
    const oncekiAdet = secici().options.length;
    await k.type(arama, "Kişi 7");
    await waitFor(() => expect(secici().options.length).toBeLessThan(oncekiAdet));
  });

  it("ARAMA YAZINCA alan KENDI ALTINDAN kaybolmaz", async () => {
    // Esik SUZULMUS liste uzerinden olculseydi, kullanici yazip listeyi
    // kisaltinca alan gizlenir ve yazdigi metin ekrandan silinirdi.
    sunucu(25);
    ciz(TahsilatlarPage);
    const { k, modal } = await modaliAc();
    const arama = await waitFor(() => {
      const a = modal.querySelector('[data-test="tahsilat-kisi-ara"]');
      expect(a).not.toBeNull();
      return a as HTMLInputElement;
    });
    await k.type(arama, "Kişi 7");
    expect(modal.querySelector('[data-test="tahsilat-kisi-ara"]')).not.toBeNull();
    expect((modal.querySelector('[data-test="tahsilat-kisi-ara"]') as HTMLInputElement).value)
      .toContain("Kişi 7");
  });
});
