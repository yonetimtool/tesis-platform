// @vitest-environment jsdom
// (P244 §7b) FINANS — GORSEL ORAN ve OZET GOSTERGELERI.
//
// ===========================================================================
// OLCULEN KUSURLAR
// ===========================================================================
//  1. BUTCE ekrani hedefi ve gerceklesen tutari YAN YANA IKI SAYI KOLONU
//     olarak gosteriyordu. Iki sayiyi karsilastirmak okurun isiydi;
//     "420.000 ile 483.500 arasindaki fark ne?" sorusunu goz yapamaz.
//  2. AIDAT ekraninda tahsilat gostergesi YOKTU — oysa uc P192'den beri
//     var ve `/finans/borclular` onu kullaniyordu. "Bu donem ne kadar
//     tahsil edildi" sorusunun sorulacagi ilk yer aidat ekrani.
import { screen, waitFor } from "@testing-library/react";
import { createElement as h } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import ButcePage from "@/app/(protected)/finans/butce/page";
import { HedefBar } from "@/components/finans/hedef-bar";

import { ciz } from "./yardimci";

const kanca = (ad: string): HTMLElement | null =>
  document.querySelector<HTMLElement>(`[data-test="${ad}"]`);

function taklit(satirlar: unknown[]) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    const govde = url.includes("butce-karsilastirma")
      ? { yil: 2026, items: satirlar }
      : { items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P244 §7b) hedef/gerceklesen bari", () => {
  it("HEDEFSIZ kategoride BAR CIZILMEZ", () => {
    // Sifir hedefe karsi dolu bir bar cizmek "sonsuz asim" demekti ve
    // bu bir bilgi degil, bir hata.
    const { container } = ciz(() =>
      h(HedefBar, {
        hedefKurus: 0,
        gerceklesenKurus: 500000,
        kotuMu: true,
        etiket: "Temizlik",
      }),
    );
    expect(container.querySelector("span[aria-hidden]")).toBeNull();
    expect(container.textContent).toContain("—");
  });

  it("DOLGU %100'DE DURUR ama YUZDE gercegi soyler", () => {
    // %180'lik bir bar satirdan tasar ve tablo hizasini bozardi; ama
    // sayiyi da %100'e kirpmak YANLIS bilgi olurdu.
    const { container } = ciz(() =>
      h(HedefBar, {
        hedefKurus: 100000,
        gerceklesenKurus: 180000,
        kotuMu: true,
        etiket: "Temizlik",
      }),
    );
    expect(container.textContent).toContain("%180");
    const dolgu = container.querySelector("span[style*='width']") as HTMLElement;
    expect(dolgu.style.width).toBe("100%");
  });

  it("ASIM GIDERDE kotu, GELIRDE iyi — renk ayni degil", () => {
    const renk = (kotuMu: boolean) => {
      const { container } = ciz(() =>
        h(HedefBar, {
          hedefKurus: 100000,
          gerceklesenKurus: 150000,
          kotuMu,
          etiket: "x",
        }),
      );
      return (container.querySelector("span[style*='width']") as HTMLElement).style
        .background;
    };
    expect(renk(true)).not.toBe(renk(false));
  });

  it("EKRAN OKUYUCU oranin ne oldugunu duyar", () => {
    // Bar `aria-hidden`; anlami tasiyan sey sarmalayicinin adi.
    ciz(() =>
      h(HedefBar, {
        hedefKurus: 100000,
        gerceklesenKurus: 115000,
        kotuMu: true,
        etiket: "Temizlik: hedefin %115'i",
      }),
    );
    expect(screen.getByLabelText(/Temizlik/)).toBeInTheDocument();
  });
});

describe("(P244 §7b) butce ekrani", () => {
  it("ORAN KOLONU tabloda cizilir", async () => {
    taklit([
      {
        kategori_id: "k1",
        ad: "Temizlik",
        tip: "gider",
        hedef_kurus: 100000,
        gerceklesen_kurus: 115000,
        sapma_kurus: 15000,
        sapma_yuzde: 15,
      },
    ]);
    ciz(ButcePage);
    await waitFor(() => expect(screen.getByText("Temizlik")).toBeInTheDocument());
    // Hem tutar hem ORAN gorunur: bar var olan bilgiyi gorsellestirir,
    // yeni bilgi tasimaz.
    expect(screen.getByLabelText(/Temizlik: hedefin %115/)).toBeInTheDocument();
  });
});
