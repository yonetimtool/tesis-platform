// @vitest-environment jsdom
// (P160 / Asama 3 artiklari) GRAFIK · TARIH ARALIGI · TOAST.
//
// Ucunun de ortak konusu ayni: GORSEL BIR SEY, TEK BASINA BILGI DEGILDIR.
//   * Pasta dilimi bir sayi tasimaz -> ayni veri TABLO olarak da cizilir.
//   * Ters tarih araligi sessizce bos rapor uretiyordu -> sebep yazilir.
//   * Bildirim kutusu `bg-white` ile sabitti -> koyu temada beyaz kart.
import { screen, render, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement, useState } from "react";
import { describe, expect, it, vi } from "vitest";

import { Grafik, TarihAraligi, aralikGecerli } from "@/components/ui";
import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";

function ciz(oge: React.ReactElement) {
  return render(
    createElement(I18nProvider, {
      baslangicDili: "tr",
      baslangicSozlugu: SOZLUKLER.tr,
      children: oge,
    }),
  );
}

/* ==================================================================== */

describe("(P160) Grafik — rakamlar KAYBOLMAZ", () => {
  const DILIMLER = [
    { ad: "Temizlik", deger: 125050 },
    { ad: "Elektrik", deger: 40000 },
  ];

  it("ayni veri bir TABLO olarak da cizilir", () => {
    ciz(
      createElement(Grafik, {
        baslik: "Gider dağılımı",
        bosBaslik: "Gider yok",
        dilimler: DILIMLER,
      }),
    );
    const tablo = screen.getByRole("table");
    // Her dilim bir SATIR BASLIGI: ekran okuyucu ad/deger esini kurar.
    expect(within(tablo).getByRole("rowheader", { name: /Temizlik/ })).toBeInTheDocument();
    expect(within(tablo).getByRole("rowheader", { name: /Elektrik/ })).toBeInTheDocument();
  });

  it("BICIMLENDIRICI degeri metne cevirir (ham kurus ekrana cikmaz)", () => {
    ciz(
      createElement(Grafik, {
        baslik: "Gider dağılımı",
        bosBaslik: "Gider yok",
        dilimler: DILIMLER,
        bicimle: (n: number) => `${(n / 100).toFixed(2)} TL`,
      }),
    );
    expect(screen.getByText("1250.50 TL")).toBeInTheDocument();
    expect(screen.queryByText("125050")).toBeNull();
  });

  it("VERI YOKSA grafik degil BOS DURUM cizilir", () => {
    ciz(
      createElement(Grafik, {
        baslik: "Gider dağılımı",
        bosBaslik: "Gider yok",
        dilimler: [],
      }),
    );
    expect(screen.getByText("Gider yok")).toBeInTheDocument();
    expect(screen.queryByRole("table")).toBeNull();
  });

  it("CIZIM ekran okuyucuya OKUNMAZ (aria-hidden) — tablo okunur", () => {
    const { container } = ciz(
      createElement(Grafik, {
        baslik: "Gider dağılımı",
        bosBaslik: "Gider yok",
        dilimler: DILIMLER,
      }),
    );
    // Cizim kabugu gizli; tablo gizli DEGIL.
    expect(container.querySelector('[aria-hidden="true"]')).toBeTruthy();
    expect(screen.getByRole("table")).toBeInTheDocument();
  });
});

/* ==================================================================== */

describe("(P160) TarihAraligi — ters aralik SESSIZ kalmaz", () => {
  function Sarmal({ b0 = "", s0 = "" }: { b0?: string; s0?: string }) {
    const [bas, setBas] = useState(b0);
    const [bit, setBit] = useState(s0);
    return createElement(TarihAraligi, {
      baslangic: bas,
      bitis: bit,
      onBaslangic: setBas,
      onBitis: setBit,
    });
  }

  it("tutarli aralikta UYARI YOK", () => {
    ciz(createElement(Sarmal, { b0: "2026-08-01", s0: "2026-08-31" }));
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("bitis baslangictan ONCEYSE sebep yazilir", () => {
    ciz(createElement(Sarmal, { b0: "2026-08-31", s0: "2026-08-01" }));
    const uyari = screen.getByRole("alert");
    expect(uyari.textContent).toMatch(/önce olamaz/);
  });

  it("ters aralikta BITIS alani `aria-invalid` ve sebebe BAGLI", () => {
    ciz(createElement(Sarmal, { b0: "2026-08-31", s0: "2026-08-01" }));
    const bitis = screen.getByLabelText(/Bitiş/);
    expect(bitis).toHaveAttribute("aria-invalid", "true");
    const sebepId = bitis.getAttribute("aria-describedby");
    expect(sebepId, "sebep baglanmadi").toBeTruthy();
    expect(document.getElementById(sebepId!)?.textContent).toMatch(/önce olamaz/);
  });

  it("kullanici duzeltince uyari KALKAR", async () => {
    ciz(createElement(Sarmal, { b0: "2026-08-31", s0: "2026-08-01" }));
    expect(screen.getByRole("alert")).toBeInTheDocument();
    const bitis = screen.getByLabelText(/Bitiş/);
    await userEvent.clear(bitis);
    await waitFor(() => expect(screen.queryByRole("alert")).toBeNull());
  });

  it("`aralikGecerli` BOS alanlari gecerli sayar (henuz secilmemis)", () => {
    expect(aralikGecerli("", "")).toBe(true);
    expect(aralikGecerli("2026-08-01", "")).toBe(true);
    expect(aralikGecerli("2026-08-01", "2026-08-31")).toBe(true);
    expect(aralikGecerli("2026-08-31", "2026-08-01")).toBe(false);
  });
});

/* ==================================================================== */

describe("(P160) Toast — tema tokenleri", () => {
  it("kutu SABIT beyaz zemin kullanmaz", async () => {
    const { ToastProvider, useToast } = await import("@/components/Toast");
    function Deneme() {
      const toast = useToast();
      return createElement("button", { onClick: () => toast.success("Kaydedildi") }, "bas");
    }
    ciz(createElement(ToastProvider, { children: createElement(Deneme) }));
    await userEvent.click(screen.getByRole("button", { name: "bas" }));

    const kutu = await screen.findByText("Kaydedildi");
    const kabuk = kutu.parentElement as HTMLElement;
    // Koyu temada beyaz kart cikiyordu; zemin artik token okuyor.
    expect(kabuk.style.background).toContain("--yz-");
    expect(kabuk.className).not.toContain("bg-white");
  });
});
