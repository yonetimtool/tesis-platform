// @vitest-environment jsdom
// (P160 / Asama 6) AIDAT · FINANS · SAYAC — tasima gerilemesi.
//
// Bu grubun ortak konusu PARA. Buradaki her testin varlik sebebi, tasima
// sirasinda kaybi EN PAHALI olacak davranislar:
//   * daire kimligi yerine daire NUMARASI (aidat),
//   * ozet rakamlarinin ANIMASYONSUZ olmasi (finans),
//   * sihirbazin hangi adimda oldugunu SOYLEMESI (sayac).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DuesPage from "@/app/(protected)/dues/page";
import FinansPage from "@/app/(protected)/finans/page";
import SayacOkumaPage from "@/app/(protected)/sayac-okuma/page";

import { ciz, fetchSahtele } from "./yardimci";

const TAHAKKUK = {
  meta: { limit: 25, offset: 0, total: 1 },
  items: [
    {
      id: "a1",
      unit_id: "u1",
      donem: "2026-08",
      tutar_kurus: 125050,
      son_odeme_tarihi: "2026-08-15",
      aciklama: null,
      created_at: "2026-08-01T00:00:00Z",
    },
  ],
};
const ODEME = {
  meta: { limit: 25, offset: 0, total: 1 },
  items: [
    {
      id: "o1",
      unit_id: "u1",
      assessment_id: "a1",
      tutar_kurus: 125050,
      odeme_zamani: "2026-08-10T10:00:00Z",
      donem: "2026-08",
      yontem: "havale",
      durum: "basarili",
      makbuz_no: null,
      provider: null,
      provider_ref: null,
      kaydeden_user_id: "k1",
    },
  ],
};
const DAIRELER = {
  meta: { limit: 200, offset: 0, total: 1 },
  items: [{ id: "u1", no: "12", blok: "A", aktif: true }],
};

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) Aidat — daire KIMLIGI degil NUMARASI", () => {
  it("daire numarasi cizilir (UUID parcasi DEGIL)", async () => {
    fetchSahtele({
      "/api/dues/assessments": TAHAKKUK,
      "/api/dues/payments": ODEME,
      "/api/units": DAIRELER,
    });
    ciz(DuesPage);
    // Once "A/12" gorunmeli...
    await waitFor(() => expect(screen.getByText("A/12")).toBeInTheDocument());
    // ...ve ham kimlik ekranda OLMAMALI.
    expect(screen.queryByText("u1")).toBeNull();
  });

  it("daire listesi cekilemezse ESKI davranisa duser — uydurma ad YOK", async () => {
    // Uc 200 daire ile sinirli; eslesmeyen kimlik icin kisa kimlik
    // gosterilir. Onemli olan: olmayan bir daire adi UYDURULMAZ.
    fetchSahtele({
      "/api/dues/assessments": TAHAKKUK,
      "/api/dues/payments": ODEME,
    });
    ciz(DuesPage);
    await waitFor(() => expect(screen.getByText("#u1")).toBeInTheDocument());
  });

  it("ODEMELER sekmesi ayri sayfalanir ve durum ROZETI tasir", async () => {
    fetchSahtele({
      "/api/dues/assessments": TAHAKKUK,
      "/api/dues/payments": ODEME,
      "/api/units": DAIRELER,
    });
    ciz(DuesPage);
    await waitFor(() => expect(screen.getByText("A/12")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("tab", { name: "Ödemeler" }));
    await waitFor(() => expect(screen.getByText("başarılı")).toBeInTheDocument());
  });
});

/* ==================================================================== */

describe("(P160) Finans — para ANIMASYONSUZ", () => {
  const OZET = {
    borclandirilan_ay_kurus: 150000,
    tahsil_edilen_ay_kurus: 100000,
    acik_borc_kurus: 50000,
    kasa_toplam_kurus: 250000,
    icra_acik_dosya: 2,
  };
  const KASALAR = {
    items: [{ kasa_id: "k1", kod: "MERKEZ", ad: "Merkez Kasa", bakiye_kurus: 250000 }],
    genel_toplam_kurus: 250000,
  };
  const HAREKETLER = {
    meta: { limit: 25, offset: 0, total: 1 },
    items: [
      {
        id: "h1",
        tip: "tahsilat",
        yon: "giris",
        tutar_kurus: 100000,
        tarih: "2026-08-01T10:00:00Z",
        kasa_ad: "Merkez Kasa",
        user_ad: "Ali Veli",
        belge_no: null,
        aciklama: "Aidat",
      },
    ],
  };

  it("ozet rakami ILK CIZIMDE dogru — sayarak yaklasmaz", async () => {
    // `Kpi` sayaci sifirdan hedefe sayar; parada bu, ekranda BIR SURE
    // yanlis bakiye yazmak demektir. Ozet kartlari o yuzden sayacsiz.
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    ciz(FinansPage);
    // Bir ozet degeri gorunur gorunmez, DIGER DORDU DE son degerinde
    // olmali. Sayan bir bilesende bu an hepsi ara degerde olurdu.
    await waitFor(() =>
      expect(screen.getAllByText("2.500,00 ₺").length).toBeGreaterThan(0),
    );
    expect(screen.getByText("1.500,00 ₺")).toBeInTheDocument();
    expect(screen.getByText("1.000,00 ₺")).toBeInTheDocument();
    expect(screen.getByText("500,00 ₺")).toBeInTheDocument();
    // Icra dosya SAYISI — para degil, oldugu gibi.
    expect(screen.getByText("2")).toBeInTheDocument();
  });

  it("GENEL TOPLAM satiri korundu (VeriTablosu'na tasinmama gerekcesi)", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    ciz(FinansPage);
    await waitFor(() => expect(screen.getByText("Genel toplam")).toBeInTheDocument());
  });

  it("TIP SUZGECI istege yansir ve sayfayi SIFIRLAR", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    const cagrilan: string[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (g: RequestInfo | URL, i?: RequestInit) => {
      cagrilan.push(String(g));
      return onceki(g, i);
    }) as typeof fetch;

    ciz(FinansPage);
    await waitFor(() => expect(screen.getByText("Ali Veli")).toBeInTheDocument());
    await userEvent.selectOptions(
      screen.getByRole("combobox", { name: "Tür süzgeci" }),
      "gider",
    );
    await waitFor(() =>
      expect(
        cagrilan.some((u) => u.includes("tip=gider") && u.includes("offset=0")),
      ).toBe(true),
    );
  });
});

/* ==================================================================== */

describe("(P160) Sayac sihirbazi — hangi adimda oldugu SOYLENIR", () => {
  const KALEMLER = { items: [{ id: "k-1", ad: "Su" }] };
  const ANA = { items: [{ id: "s-1", ad: "Ana su sayaci", ortak_alan_yuzde: null }] };
  const BOLUM = { items: [{ id: "b-1", unit_no: "A-1" }] };

  it("aktif adim `aria-current=step` tasir — renk TEK tasiyici degil", async () => {
    fetchSahtele({
      "/api/tanimlar/gelir-gider-tanimlari": KALEMLER,
      "/api/tanimlar/sayaclar-ana": ANA,
      "/api/tanimlar/sayaclar-bolum": BOLUM,
    });
    ciz(SayacOkumaPage);
    const liste = await screen.findByRole("list");
    const aktif = within(liste)
      .getAllByRole("listitem")
      .filter((li) => li.getAttribute("aria-current") === "step");
    expect(aktif).toHaveLength(1);
    expect(aktif[0].textContent).toContain("Gelir/gider");
  });

  it("ILERI deyince `aria-current` sonraki adima GECER", async () => {
    fetchSahtele({
      "/api/tanimlar/gelir-gider-tanimlari": KALEMLER,
      "/api/tanimlar/sayaclar-ana": ANA,
      "/api/tanimlar/sayaclar-bolum": BOLUM,
    });
    ciz(SayacOkumaPage);
    await userEvent.selectOptions(
      await screen.findByRole("combobox", { name: "Gelir/gider kalemi" }),
      "k-1",
    );
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));

    const liste = screen.getByRole("list");
    const aktif = within(liste)
      .getAllByRole("listitem")
      .filter((li) => li.getAttribute("aria-current") === "step");
    expect(aktif).toHaveLength(1);
    expect(aktif[0].textContent).not.toContain("Gelir/gider");
  });

  it("ALAN ADLARI korundu — form etiketleri erisilebilir ad uretir", async () => {
    fetchSahtele({
      "/api/tanimlar/gelir-gider-tanimlari": KALEMLER,
      "/api/tanimlar/sayaclar-ana": ANA,
      "/api/tanimlar/sayaclar-bolum": BOLUM,
    });
    ciz(SayacOkumaPage);
    await userEvent.selectOptions(
      await screen.findByRole("combobox", { name: "Gelir/gider kalemi" }),
      "k-1",
    );
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));
    // `aria-label` KALDIRILDI, adlar artik `<label>`dan geliyor; ad
    // AYNI kalmali yoksa mevcut testler ve ekran okuyucu kirilir.
    expect(screen.getByRole("textbox", { name: "Dönem" })).toBeInTheDocument();
    expect(
      screen.getByRole("combobox", { name: "Ana sayaç" }),
    ).toBeInTheDocument();
  });
});
