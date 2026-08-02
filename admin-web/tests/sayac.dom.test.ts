// @vitest-environment jsdom
// (P111) SAYAC TAKIBI — bolum sayaclari defteri + dort adimli okuma sihirbazi.
//
// Uc ayri hata sinifi olculur:
//   1. REFERANS ALANI — form KIMLIK tasir, tablo sunucunun COZDUGU adi
//      gosterir. Ikisini karistirmak, tabloda ham UUID okumak demekti.
//   2. SESSIZ YOK SAYMA — bolum sayacinin dairesi PATCH govdesinde YOKTUR;
//      gonderilirse pydantic onu sessizce atar ve kullanici daireyi
//      tasidigini SANIR.
//   3. SIHIRBAZIN SOZLESMESI — ilk uc adim ISTEMCIDE toplanir, sunucuya
//      TEK istek gider (`SayacBorcIstek` docstring'i). Ara adimda istek
//      atan bir sihirbaz, sunucuda yarim durum birakirdi.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import SayacOkumaPage from "@/app/(protected)/sayac-okuma/page";
import TanimlarPage from "@/app/(protected)/tanimlar/page";

import { ciz, fetchSahtele } from "./yardimci";

afterEach(() => vi.restoreAllMocks());

const DAIRELER = {
  meta: { limit: 200, offset: 0, total: 2 },
  items: [
    { id: "u-1", no: "A-1", aktif: true },
    { id: "u-2", no: "A-2", aktif: true },
  ],
};
const ANA_SAYACLAR = {
  meta: { limit: 200, offset: 0, total: 1 },
  items: [{ id: "s-1", ad: "Ana Su Sayacı", tip: "su", aktif: true }],
};
const BOLUM_SAYACLARI = {
  meta: { limit: 200, offset: 0, total: 1 },
  items: [
    {
      id: "b-1",
      unit_id: "u-1",
      unit_no: "A-1",
      ana_sayac_id: "s-1",
      ana_sayac_ad: "Ana Su Sayacı",
      tesisat_no: "TS-9",
      ilk_okuma: 10,
      aktif: true,
    },
  ],
};
const KALEMLER = {
  meta: { limit: 200, offset: 0, total: 1 },
  items: [{ id: "k-1", ad: "Su Gideri", tip: "gider", aktif: true }],
};

/** Gonderilen istek govdelerini yakalar (url parcasi -> govde listesi). */
function govdeYakala(parca: string): unknown[] {
  const govdeler: unknown[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    if (String(girdi).includes(parca) && init?.body) {
      govdeler.push(JSON.parse(String(init.body)));
    }
    return onceki(girdi, init);
  }) as typeof fetch;
  return govdeler;
}

/** "Bölüm Sayaçları" sekmesini acar. */
async function bolumSekmesi(): Promise<void> {
  await waitFor(() =>
    expect(screen.getByRole("button", { name: "Bölüm Sayaçları" })).toBeInTheDocument(),
  );
  await userEvent.click(screen.getByRole("button", { name: "Bölüm Sayaçları" }));
}

describe("Bolum sayaclari defteri (referans alan tipi)", () => {
  it("TABLODA kimlik degil COZULMUS ad gorunur", async () => {
    fetchSahtele({
      "/api/tanimlar/sayaclar-bolum": BOLUM_SAYACLARI,
      "/api/tanimlar/sayaclar-ana": ANA_SAYACLAR,
      "/api/units": DAIRELER,
    });
    ciz(TanimlarPage);
    await bolumSekmesi();

    // Daire ve ana sayac sutunlari: `A-1` ve `Ana Su Sayacı`.
    await waitFor(() => expect(screen.getAllByText("A-1").length).toBeGreaterThan(0));
    expect(screen.getAllByText("Ana Su Sayacı").length).toBeGreaterThan(0);
    // Ham kimlikler EKRANDA OLMAMALI.
    expect(document.body.textContent ?? "").not.toContain("u-1");
    expect(document.body.textContent ?? "").not.toContain("s-1");
  });

  it("REFERANS SECICI secenekleri BASKA UCTAN yukler", async () => {
    fetchSahtele({
      "/api/tanimlar/sayaclar-bolum": BOLUM_SAYACLARI,
      "/api/tanimlar/sayaclar-ana": ANA_SAYACLAR,
      "/api/units": DAIRELER,
    });
    ciz(TanimlarPage);
    await bolumSekmesi();
    await userEvent.click(screen.getByRole("button", { name: "Yeni kayıt" }));

    const daireSecici = await screen.findByRole("combobox", { name: "Daire" });
    // Iki daire de secenek olarak gelmeli — liste `/api/units`ten.
    await waitFor(() =>
      expect(within(daireSecici).getAllByRole("option")).toHaveLength(3),
    );
    expect(within(daireSecici).getByRole("option", { name: "A-2" })).toBeInTheDocument();
  });

  it("DUZENLEMEDE daire alani PASIF ve govdede GONDERILMEZ", async () => {
    // Sunucunun PATCH govdesi `unit_id` KABUL ETMEZ; gondermek sessizce
    // yok sayilir ve kullanici daireyi degistirdigini sanirdi.
    fetchSahtele({
      "/api/tanimlar/sayaclar-bolum": BOLUM_SAYACLARI,
      "/api/tanimlar/sayaclar-ana": ANA_SAYACLAR,
      "/api/units": DAIRELER,
    });
    const govdeler = govdeYakala("/api/tanimlar/sayaclar-bolum/b-1");
    ciz(TanimlarPage);
    await bolumSekmesi();
    await waitFor(() => expect(screen.getByRole("button", { name: "Düzenle" })).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Düzenle" }));

    const daireSecici = await screen.findByRole("combobox", { name: "Daire" });
    expect(daireSecici).toBeDisabled();

    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(govdeler).toHaveLength(1));
    expect(govdeler[0]).not.toHaveProperty("unit_id");
    // Diger alanlar YINE gider (form bos gondermiyor).
    expect(govdeler[0]).toHaveProperty("tesisat_no", "TS-9");
  });

  it("TOPLU URETIM: ana sayac kimligi gider, sonuc SAYILARLA raporlanir", async () => {
    fetchSahtele({
      "/api/tanimlar/sayaclar-bolum-otomatik": { olusturulan: 12, atlanan: 3 },
      "/api/tanimlar/sayaclar-bolum": BOLUM_SAYACLARI,
      "/api/tanimlar/sayaclar-ana": ANA_SAYACLAR,
      "/api/units": DAIRELER,
    });
    const govdeler = govdeYakala("sayaclar-bolum-otomatik");
    ciz(TanimlarPage);
    await bolumSekmesi();

    const secici = await screen.findByRole("combobox", { name: "Ana sayaç" });
    await userEvent.selectOptions(secici, "s-1");
    await userEvent.click(screen.getByRole("button", { name: "Sayaçları üret" }));

    await waitFor(() => expect(govdeler).toHaveLength(1));
    expect(govdeler[0]).toEqual({ ana_sayac_id: "s-1" });
    // ATLANAN SAYISI DA YAZILIR: yalniz "olusturulan" gosterilseydi,
    // ikinci calistirmada kullanici "hicbir sey olmadi" sanirdi.
    await waitFor(() =>
      expect(document.body.textContent ?? "").toContain("12 sayaç açıldı, 3 daire atlandı."),
    );
  });
});

describe("Sayac okuma sihirbazi (dort adim, TEK istek)", () => {
  function sihirbaziSahtele(bolumler = BOLUM_SAYACLARI) {
    fetchSahtele({
      "/api/tanimlar/gelir-gider-tanimlari": KALEMLER,
      "/api/tanimlar/sayaclar-ana": ANA_SAYACLAR,
      "/api/tanimlar/sayaclar-bolum": bolumler,
      "/api/borclandirma/sayac": { created: [], atlanan: 1 },
    });
  }

  /** 1. ve 2. adimi doldurur, 3. adima birakir. */
  async function ikiAdim(): Promise<void> {
    await userEvent.selectOptions(
      await screen.findByRole("combobox", { name: "Gelir/gider kalemi" }),
      "k-1",
    );
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));

    await userEvent.selectOptions(
      await screen.findByRole("combobox", { name: "Ana sayaç" }),
      "s-1",
    );
    await userEvent.type(screen.getByRole("textbox", { name: "Dönem" }), "2026-08");
    await userEvent.type(
      screen.getByRole("textbox", { name: "Ana sayaç dönem tüketimi" }),
      "100",
    );
    await userEvent.type(screen.getByRole("textbox", { name: "Birim fiyat (₺)" }), "35,50");
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));
  }

  it("ILK UC ADIMDA borclandirma istegi ATILMAZ", async () => {
    sihirbaziSahtele();
    const govdeler = govdeYakala("/api/borclandirma/sayac");
    ciz(SayacOkumaPage);
    await ikiAdim();
    await screen.findByRole("textbox", { name: "A-1" });
    expect(govdeler).toHaveLength(0);
  });

  it("DONEM BICIMI adiminda dogrulanir (son adima birakilmaz)", async () => {
    sihirbaziSahtele();
    ciz(SayacOkumaPage);
    await userEvent.selectOptions(
      await screen.findByRole("combobox", { name: "Gelir/gider kalemi" }),
      "k-1",
    );
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));
    await userEvent.selectOptions(
      await screen.findByRole("combobox", { name: "Ana sayaç" }),
      "s-1",
    );
    await userEvent.type(screen.getByRole("textbox", { name: "Dönem" }), "Ağustos");
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));

    expect(document.body.textContent ?? "").toContain("YYYY-AA");
    // Adim ILERLEMEDI: 3. adimin daire alani yok.
    expect(screen.queryByRole("textbox", { name: "A-1" })).not.toBeInTheDocument();
  });

  it("SON ADIM: govde sunucunun sozlesmesine uyar (kurus + tuketim haritasi)", async () => {
    sihirbaziSahtele();
    const govdeler = govdeYakala("/api/borclandirma/sayac");
    ciz(SayacOkumaPage);
    await ikiAdim();
    await userEvent.type(await screen.findByRole("textbox", { name: "A-1" }), "40");
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));
    await userEvent.click(screen.getByRole("button", { name: "Borçlandır" }));

    await waitFor(() => expect(govdeler).toHaveLength(1));
    expect(govdeler[0]).toMatchObject({
      donem: "2026-08",
      gelir_gider_tanim_id: "k-1",
      ana_sayac_id: "s-1",
      ana_tuketim: 100,
      // BIRIM FIYAT KURUSTUR: `35,50` -> 3550. TL gondermek tutari
      // yuz kat KUCULTURDU.
      birim_fiyat_kurus: 3550,
      bolum_tuketimleri: { "b-1": 40 },
    });
  });

  it("ONIZLEME ortak alan YUZDESINI uygular (sunucunun kurali)", async () => {
    // Ana 100, daire toplami 40 -> fark 60. Yuzde YOKSA farkin TAMAMI
    // dagitilir: (40 + 60) x 35,50 = 3.550,00 ₺.
    // Yuzde 50 ise farkin YARISI: (40 + 30) x 35,50 = 2.485,00 ₺.
    // Ikisini ayirt etmemek, yuzde kullanan sitede onizlemeyi OLDUGUNDAN
    // BUYUK gostermek demekti.
    fetchSahtele({
      "/api/tanimlar/gelir-gider-tanimlari": KALEMLER,
      "/api/tanimlar/sayaclar-ana": {
        meta: { limit: 200, offset: 0, total: 1 },
        items: [{ id: "s-1", ad: "Ana Su Sayacı", tip: "su", ortak_alan_yuzde: 50, aktif: true }],
      },
      "/api/tanimlar/sayaclar-bolum": BOLUM_SAYACLARI,
    });
    ciz(SayacOkumaPage);
    await ikiAdim();
    await userEvent.type(await screen.findByRole("textbox", { name: "A-1" }), "40");
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));

    await waitFor(() =>
      expect(document.body.textContent ?? "").toContain("2.485,00"),
    );
    expect(document.body.textContent ?? "").not.toContain("3.550,00");
  });

  it("BAGLI SAYAC YOKSA borclandirma dugmesi PASIF ve neden yazili", async () => {
    // Bos listeyle ilerlemek, hicbir daireyi borclandirmayan bir istek
    // atmak olurdu — sunucu 201 doner, kullanici "oldu" sanir.
    sihirbaziSahtele({ meta: { limit: 200, offset: 0, total: 0 }, items: [] });
    ciz(SayacOkumaPage);
    await ikiAdim();
    await waitFor(() =>
      expect(document.body.textContent ?? "").toContain("daire sayacı yok"),
    );
    await userEvent.click(screen.getByRole("button", { name: "İleri" }));
    expect(screen.getByRole("button", { name: "Borçlandır" })).toBeDisabled();
  });
});
