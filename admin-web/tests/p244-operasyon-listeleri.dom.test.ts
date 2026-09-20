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
import KargolarPage from "@/app/(protected)/kargolar/page";

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

describe("(P244 §8a) kargo listesi", () => {
  it("kayitlar GERCEK TABLODA — satir/sutun iliskisi korunur", async () => {
    kargoKur("security", [BEKLEYEN, TESLIM]);
    ciz(KargolarPage);
    const hucre = await screen.findByRole("cell", { name: "A-12" });
    // `closest("table")`: `div` izgarasi gorsel olarak ayni durur ama
    // ekran okuyucu icin tablo DEGILDIR.
    expect(hucre.closest("table"), "kayitlar tabloda degil").not.toBeNull();
    expect(screen.getByRole("cell", { name: "B-3" })).toBeInTheDocument();
  });

  it("SAKIN bekleyen kargoda 'Teslim aldim' GORUR", async () => {
    kargoKur("resident", [BEKLEYEN]);
    ciz(KargolarPage);
    await screen.findByRole("cell", { name: "A-12" });
    expect(
      await screen.findByRole("button", { name: "Teslim aldım" }),
    ).toBeInTheDocument();
  });

  it("TESLIM EDILMIS kargoda dugme YOK (damga ikinci kez basilmaz)", async () => {
    kargoKur("resident", [TESLIM]);
    ciz(KargolarPage);
    await screen.findByRole("cell", { name: "B-3" });
    expect(screen.queryByRole("button", { name: "Teslim aldım" })).toBeNull();
  });

  it("GUVENLIK dugmeyi HIC gormez (sunucu ona 404 verir)", async () => {
    kargoKur("security", [BEKLEYEN]);
    ciz(KargolarPage);
    await screen.findByRole("cell", { name: "A-12" });
    expect(screen.queryByRole("button", { name: "Teslim aldım" })).toBeNull();
  });

  it("OZET SAYILARI AYRI UCLARDAN — gorunen listeden turetilmez", async () => {
    // Gorunen listede 2 kayit var; ama sayaclar `meta.total` okur.
    // Ayni sahte yanit uc uca da dondugu icin burada olculen sey
    // sayinin DEGERI degil, sayfanin sayaclari AYRI sorgularla
    // sormasidir: `?durum=bekliyor&limit=1` ve `?durum=teslim_alindi`.
    kargoKur("security", [BEKLEYEN, TESLIM]);
    ciz(KargolarPage);
    await screen.findByRole("cell", { name: "A-12" });
    const { cagrilanUrller } = await import("./yardimci");
    const urller = cagrilanUrller();
    expect(urller.some((u) => u.includes("durum=bekliyor&") || u.endsWith("durum=bekliyor"))).toBe(
      true,
    );
    expect(urller.some((u) => u.includes("durum=teslim_alindi"))).toBe(true);
  });
});

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
