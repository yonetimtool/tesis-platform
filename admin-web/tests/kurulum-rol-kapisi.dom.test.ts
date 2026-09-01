// @vitest-environment jsdom
// (P167) KURULUM SIHIRBAZI — ADIMLAR ROLE GORE TAMAMLANABILIR MI?
//
// =========================================================================
// OLCULEN SEY
// =========================================================================
// P166'da sihirbazi tararken bir CIKMAZ bulundu: sekizinci adim ("Aidat
// tahakkuku") yoneticiyi `/dues`a yolluyordu ama `POST /dues/assessments`
// YALNIZ ADMIN'di — yonetici toplu tahakkuk dugmesinde 403 aliyordu. O
// tur, kullaniciyi duvara yollamamak icin adimi "senin rolunle
// tamamlanamaz" diye isaretledi ve karari Kerem'e birakti.
//
// KEREM KARARI VERDI: uc yoneticiye acildi (aidat yazmak site
// yoneticisinin asil isi). Bu dosya SONUCU kilitler:
//   1. `aidat` adimi artik YONETICIDE de eyleme cagirir ("Git"), uyari
//      notu CIZILMEZ;
//   2. rol kapisi MEKANIZMASI hala calisir — silinmedi, cunku yarin baska
//      bir adim dar bir role kilitlenirse 403'e yollamak yerine
//      isaretlemek gerekir.
//
// (2) neden onemli: kusuru duzeltirken ONU GORUNUR KILAN mekanizmayi da
// silmek yaygin bir hatadir; ayni ders ikinci kez ogrenilir.
import { screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import KurulumPage from "@/app/(protected)/kurulum/page";
import { KURULUM_HEDEFLERI, type KurulumHedefi } from "@/lib/kurulum-adimlari";

import { ciz, fetchSahtele } from "./yardimci";

/** Sunucunun `GET /kurulum` yaniti — sekiz adim, hicbiri tamam degil. */
const KODLAR = [
  "blok",
  "daire",
  "daire_tipi",
  "sakin",
  "personel",
  "gorev_alani",
  "nfc_noktasi",
  "aidat",
];

function durum() {
  return {
    adimlar: KODLAR.map((kod) => ({ kod, sayi: 0, tamam: false, atlandi: false })),
    toplam: KODLAR.length,
    gecilen: 0,
  };
}

function kur(rol: string) {
  fetchSahtele({
    "/api/panel/kurulum": durum(),
    // Sayfa rolu `useRol(null)` ile `/api/me`den cozer.
    "/api/me": { role: rol },
  });
}

afterEach(() => vi.restoreAllMocks());

describe("(P167) aidat adimi YONETICIDE tamamlanabilir", () => {
  it("YONETICI: uyari notu YOK", async () => {
    kur("yonetici");
    ciz(KurulumPage);
    // Adimlar geldikten sonra olc: yanit gelmeden hicbir satir cizilmez.
    await screen.findByText(/Aidat tahakkuku/i);
    expect(
      screen.queryByText(/yalnızca platform yöneticisi/i),
      "yoneticiye artik 'yapamazsin' denmemeli",
    ).toBeNull();
  });

  it("YONETICI: sekiz adimin SEKIZI de eyleme cagirir", async () => {
    kur("yonetici");
    ciz(KurulumPage);
    await screen.findByText(/Aidat tahakkuku/i);
    // Hicbiri tamamlanmadigi icin hepsi "Git" demeli. Bir adim
    // "Goruntule"ye dusuyorsa ya tamamlanmis sayiliyordur ya da rol
    // kapisina takilmistir — ikisi de bu senaryoda yanlis.
    expect(screen.getAllByRole("link", { name: /^Git$/ })).toHaveLength(
      KODLAR.length,
    );
  });

  it("ADMIN: davranis AYNI (acilma admin'i kisitlamadi)", async () => {
    kur("admin");
    ciz(KurulumPage);
    await screen.findByText(/Aidat tahakkuku/i);
    expect(screen.queryByText(/yalnızca platform yöneticisi/i)).toBeNull();
    expect(screen.getAllByRole("link", { name: /^Git$/ })).toHaveLength(
      KODLAR.length,
    );
  });
});

describe("(P167) rol kapisi MEKANIZMASI duruyor", () => {
  it("hicbir adim artik rol kapisi TASIMIYOR", () => {
    // Bugunku dogru durum: sekiz adimin hicbiri dar bir role kilitli
    // degil. Bu satir, `rolGerekli`nin sessizce geri gelmesini gorunur
    // kilar — geri gelirse bilincli bir karar olmali.
    const kapili = Object.entries(KURULUM_HEDEFLERI).filter(([, h]) => h.rolGerekli);
    expect(kapili.map(([k]) => k)).toEqual([]);
  });

  it("MEKANIZMA SILINMEDI: alan tip sozlesmesinde duruyor", () => {
    // `rolGerekli` opsiyonel bir alan; varligini calisma aninda
    // kanitlamanin yolu, tabloyu o alanla genisletebilmek. Derleme
    // gecerse alan duruyordur — silinse bu dosya DERLENMEZDI.
    const ornek: KurulumHedefi = {
      etiket: "kurulumAidat",
      aciklama: "kurulumAidatAlt",
      rota: "/dues",
      engel: "kurulumEngelAidat",
      rolGerekli: ["admin"],
    };
    expect(ornek.rolGerekli).toEqual(["admin"]);
  });
});
