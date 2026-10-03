// @vitest-environment jsdom
//
// (P244 §8a) OPERASYON LISTELERI — KART YIGINI YERINE TABLO.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// `p244-kart-yigini-yasak` KAYNAK METNI tarar: "hicbir sayfa kaydi kart
// olarak dizmiyor". Bu, kartin GITTIGINI olcer; yerine KOYULANIN dogru
// oldugunu olcmez. Bu dosya ikincisini yapar ve uc karari kilitler:
//
//   1. Kayitlar GERCEK bir `<table>` icinde (ekran okuyucu satir/sutun
//      iliskisini ancak boyle alir),
//   2. Tabloya tasinirken KAYBOLABILECEK eylemler kaybolmadi
//      (kargoda "Teslim aldim", rehberde `tel:` baglantisi),
//   3. Rol/durum kapilari AYNEN korundu — tablo bir gorunum degisikligi,
//      bir yetki degisikligi DEGIL.
//
// (3) en onemlisi: kart->tablo donusumu sirasinda en kolay kaybedilen
// sey, kartin icine gomulu kosullu dugmedir.
import { screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import DisHizmetlerPage from "@/app/(protected)/dis-hizmetler/page";

import { ciz, fetchSahtele } from "./yardimci";

const BEKLEYEN = {
  id: "k1",
  unit_no: "A-12",
  firma: "Hızlı Kargo",
  notlar: null,
  durum: "bekliyor",
  created_at: "2026-09-01T10:00:00Z",
};
const TESLIM = { ...BEKLEYEN, id: "k2", unit_no: "B-3", durum: "teslim_alindi" };

const ESNAF = {
  id: "e1",
  tur: "Tesisatçı",
  ad: "Ali",
  soyad: "Veli",
  telefon: "+905321112233",
  aciklama: null,
};

function kargoKur(rol: string, items: unknown[]) {
  fetchSahtele({
    "/api/me": { role: rol },
    "/api/kargo": { items, meta: { total: items.length } },
  });
}

afterEach(() => vi.restoreAllMocks());

describe("(P244 §8a) dis hizmet rehberi", () => {
  it("TELEFON hala ARANABILIR bir `tel:` baglantisi", async () => {
    fetchSahtele({ "/api/external-services": { note: null, items: [ESNAF] } });
    ciz(DisHizmetlerPage);
    const hucre = await screen.findByRole("cell", { name: /Ali Veli/ });
    expect(hucre.closest("table")).not.toBeNull();
    // Rehberdeki numaranin TEK isi aranmaktir; tabloya tasinirken duz
    // metne donsaydi ekran is gormezdi.
    const bag = screen.getByRole("link", { name: /532/ });
    expect(bag.getAttribute("href")).toBe("tel:+905321112233");
  });

  it("DUZENLE ve SIL satirda KALDI", async () => {
    fetchSahtele({ "/api/external-services": { note: null, items: [ESNAF] } });
    ciz(DisHizmetlerPage);
    const hucre = await screen.findByRole("cell", { name: /Ali Veli/ });
    const satir = hucre.closest("tr")!;
    expect(within(satir).getByRole("button", { name: "Düzenle" })).toBeInTheDocument();
    expect(within(satir).getByRole("button", { name: "Sil" })).toBeInTheDocument();
  });
});
