// @vitest-environment jsdom
// (P154 / Asama 6.2) LISTE — DAVRANIS testi.
//
// Brief'in bes maddesi tek tek olculuyor: kolon siralama, kolon suzgeci,
// toplu secim, SAYFA BASINA KAYIT (10/25/50/100), sayfalama + toplam.
//
// Ayrica IKI TUZAK kilitleniyor:
//   * "tumunu sec" YALNIZ GORUNEN sayfayi kapsar — suzgecten gizlenmis
//     satirlari da secmek, kullanicinin gormedigi kayitlara toplu islem
//     yaptirmak olurdu,
//   * `sunucuTarafi` iken sayfalama denetimleri CIZILMEZ — yoksa bilesen
//     "500 kaydin 50'sini" alip "50 kayit var" derdi.
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement, useState } from "react";
import { describe, expect, it } from "vitest";

import { Liste, type Kolon } from "@/components/Liste";

import { ciz } from "./yardimci";

interface Satir {
  id: string;
  ad: string;
  tutar: number;
}

const VERI: Satir[] = Array.from({ length: 30 }, (_, i) => ({
  id: `k${i + 1}`,
  // Siralamayi ANLAMLI kilmak icin ters sirada adlar.
  ad: `Kasa ${String(30 - i).padStart(2, "0")}`,
  tutar: (i + 1) * 100,
}));

const KOLONLAR: Kolon<Satir>[] = [
  { anahtar: "ad", baslik: "Ad", deger: (s) => s.ad, suzgec: true },
  { anahtar: "tutar", baslik: "Tutar", deger: (s) => s.tutar, hizala: "end" },
];

function govdeSatirlari(): HTMLElement[] {
  const tablo = screen.getByRole("table");
  const govde = tablo.querySelector("tbody")!;
  return Array.from(govde.querySelectorAll("tr"));
}

function Sarmal(props: { secimli?: boolean; sunucuTarafi?: boolean; veri?: Satir[] }) {
  const [secili, setSecili] = useState<string[]>([]);
  return createElement(Liste<Satir>, {
    kolonlar: KOLONLAR,
    satirlar: props.veri ?? VERI,
    kimlik: (s: Satir) => s.id,
    sunucuTarafi: props.sunucuTarafi,
    secim: props.secimli ? { secili, degisti: setSecili } : undefined,
  });
}

describe("(P154) Liste — sayfalama, siralama, suzgec, secim", () => {
  it("VARSAYILAN sayfa boyu 25; toplam DOGRU yazilir", () => {
    ciz(() => createElement(Sarmal));
    expect(govdeSatirlari()).toHaveLength(25);
    expect(screen.getByText("1–25 / 30")).toBeTruthy();
  });

  it("SAYFA BASINA KAYIT degisince gorunen sayi degisir (10/25/50/100)", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    const secici = screen.getByLabelText("Sayfa başına", { exact: false });
    // Brief'in acikca istedigi dort secenek.
    const secenekler = within(secici as HTMLElement)
      .getAllByRole("option")
      .map((o) => o.textContent);
    expect(secenekler).toEqual(["10", "25", "50", "100"]);

    await k.selectOptions(secici, "10");
    expect(govdeSatirlari()).toHaveLength(10);
    expect(screen.getByText("1–10 / 30")).toBeTruthy();
  });

  it("SAYFALAMA ileri/geri calisir ve sinirda kilitlenir", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.selectOptions(screen.getByLabelText("Sayfa başına", { exact: false }), "10");

    const ileri = screen.getByLabelText("Sonraki sayfa");
    const geri = screen.getByLabelText("Önceki sayfa");
    expect(geri).toBeDisabled();

    await k.click(ileri);
    expect(screen.getByText("11–20 / 30")).toBeTruthy();
    await k.click(ileri);
    expect(screen.getByText("21–30 / 30")).toBeTruthy();
    // Son sayfada ileri KAPALI: bos sayfa gostermek kullaniciya
    // "kayit bitti mi, yuklenemedi mi" sorusunu sordururdu.
    expect(ileri).toBeDisabled();
  });

  it("KOLON SIRALAMA tiklamayla yon degistirir", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    // Veri ters sirada uretildi: ilk satir "Kasa 30".
    expect(govdeSatirlari()[0].textContent).toContain("Kasa 30");

    await k.click(screen.getByRole("button", { name: "Ad — Artan sırala" }));
    expect(govdeSatirlari()[0].textContent).toContain("Kasa 01");

    await k.click(screen.getByRole("button", { name: "Ad — Azalan sırala" }));
    expect(govdeSatirlari()[0].textContent).toContain("Kasa 30");
  });

  it("KOLON SUZGECI daraltir ve sayfayi BASA alir", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.selectOptions(screen.getByLabelText("Sayfa başına", { exact: false }), "10");
    await k.click(screen.getByLabelText("Sonraki sayfa"));
    expect(screen.getByText("11–20 / 30")).toBeTruthy();

    await k.type(screen.getByLabelText("Ad — Süzgeç"), "Kasa 1");
    // "Kasa 10".."Kasa 19" -> 10 kayit. ("Kasa 01" iceriginde "Kasa 1"
    // GECMEZ; adlar iki haneli dolduruluyor.)
    expect(screen.getByText("1–10 / 10")).toBeTruthy();
    // Sayfa basa alinmasaydi kullanici SUZGECTEN SONRA bos ekran gorurdu.
    expect(govdeSatirlari()[0].textContent).toContain("Kasa 1");
  });

  it("TUMUNU SEC yalniz GORUNEN sayfayi kapsar", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal, { secimli: true }));
    await k.selectOptions(screen.getByLabelText("Sayfa başına", { exact: false }), "10");

    await k.click(screen.getByLabelText("Tümünü seç"));
    // 30 degil 10: gorunmeyen kayitlara toplu islem yaptirmak, kullanicinin
    // farkinda olmadigi satirlari degistirmek olurdu.
    expect(screen.getByText("10 seçili")).toBeTruthy();
  });

  it("BOS DURUMDA anlamli mesaj cizilir", () => {
    ciz(() => createElement(Sarmal, { veri: [] }));
    expect(screen.getByText("Kayıt yok.")).toBeTruthy();
  });

  it("SUNUCU sayfaliyorsa sayfalama denetimleri CIZILMEZ", () => {
    ciz(() => createElement(Sarmal, { sunucuTarafi: true }));
    expect(screen.queryByLabelText("Sonraki sayfa")).toBeNull();
    // Tum satirlar cizilir; kirpma sunucunun isidir.
    expect(govdeSatirlari()).toHaveLength(30);
  });
});
