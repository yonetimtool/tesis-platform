// @vitest-environment jsdom
// (P193 §2) KURULUM SIHIRBAZI — OZET, ZORUNLULUK ve HATIRLATICI.
//
// =========================================================================
// OLCULEN SEY
// =========================================================================
// Rehberi (docs/yonetici-kurulum-rehberi.md) yazarken uc kusur bulundu:
//
//  11. Sihirbazda KASA adimi yoktu; kasasiz tesiste yonetici ilk
//      tahsilati girmeye calisinca ogreniyordu.
//  13. E-POSTA gonderimi — kurulumun en kritik bagimliligi, cunku
//      davetler oradan gidiyor — sihirbazin hicbir adiminda gecmiyordu.
//  14. "Daha sonra" ile kapatilan hatirlatiiciyi geri getiren dugme
//      YALNIZ `/settings`teydi, yani yonetici bir daha goremiyordu.
//
// Ortak kok: sihirbaz "sunu yap" diyor ama "yapmazsan NE calismaz"
// demiyordu. Bu dosya sonucu kilitler.
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import KurulumPage from "@/app/(protected)/kurulum/page";
import { KURULUM_HEDEFLERI } from "@/lib/kurulum-adimlari";

import { ciz, fetchSahtele } from "./yardimci";

const KAPATILDI_ANAHTARI = "yonetio.kurulum.kapatildi";

/** Sunucunun `GET /kurulum` yaniti — iki zorunlu adim EKSIK. */
function durum() {
  const kodlar = Object.keys(KURULUM_HEDEFLERI);
  const zorunlu = new Set([
    "blok", "daire", "daire_tipi", "sakin", "eposta", "kasa", "aidat",
  ]);
  const eksik = ["kasa", "eposta"];
  return {
    adimlar: kodlar.map((kod) => ({
      kod,
      sayi: eksik.includes(kod) ? 0 : 1,
      tamam: !eksik.includes(kod),
      atlandi: false,
      zorunlu: zorunlu.has(kod),
    })),
    toplam: kodlar.length,
    gecilen: kodlar.length - eksik.length,
    zorunlu_toplam: zorunlu.size,
    eksik_zorunlular: eksik,
    calisir: false,
  };
}

function kur(yanit: Record<string, unknown> = durum()) {
  fetchSahtele({ "/api/panel/kurulum": yanit, "/api/me": { role: "yonetici" } });
}

afterEach(() => {
  vi.restoreAllMocks();
  localStorage.clear();
});

describe("(P193 §2) sihirbaz ozeti", () => {
  it("KASA ve E-POSTA adimlari LISTEDE", async () => {
    kur();
    ciz(KurulumPage);
    // Adim listesinde VE eksikler ozetinde gectigi icin coklu eslesme
    // beklenir; olculen sey adimin VARLIGI.
    expect((await screen.findAllByText(/^Kasa$/)).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/^E-posta gönderimi$/).length).toBeGreaterThan(0);
  });

  it("EKSIK ZORUNLULAR ve NEYI ENGELLEDIKLERI yaziyor", async () => {
    kur();
    ciz(KurulumPage);
    await screen.findByText(/Çalışır kurulum için eksikler/);
    expect(screen.getByText(/Zorunlu adımlar: 5\/7/)).toBeInTheDocument();
    // "Sunu yap" degil, "yapmazsan su olmaz".
    // Engel metni hem ozette hem adim satirinda gecer (ikisi de eksik
    // adimlar); olculen sey METNIN GORUNMESI.
    expect(
      screen.getAllByText(/tahsilat ve gider kaydedilemez/i).length,
    ).toBeGreaterThan(0);
    expect(screen.getAllByText(/davetler gitmez/i).length).toBeGreaterThan(0);
  });

  it("HEPSI TAMAMSA ozet 'calisir durumda' der", async () => {
    const d = durum();
    d.adimlar = d.adimlar.map((a) => ({ ...a, sayi: 1, tamam: true }));
    d.eksik_zorunlular = [];
    d.calisir = true;
    d.gecilen = d.toplam;
    kur(d);
    ciz(KurulumPage);
    expect(await screen.findByText(/Tesis çalışır durumda/)).toBeInTheDocument();
    expect(screen.queryByText(/Çalışır kurulum için eksikler/)).toBeNull();
  });

  it("HATIRLATICI YONETICIDEN geri acilabilir (eksik 14)", async () => {
    kur();
    localStorage.setItem(KAPATILDI_ANAHTARI, "1");
    ciz(KurulumPage);
    const dugme = await screen.findByRole("button", {
      name: /Kurulum sihirbazını tekrar göster/,
    });
    await userEvent.click(dugme);
    // Kapatma kaydi SILINDI -> hatirlatici bir sonraki sayfada yine cikar.
    expect(localStorage.getItem(KAPATILDI_ANAHTARI)).toBeNull();
  });

  it("ESKI SUNUCU yaniti sayfayi KIRMAZ (ozet alanlari yoksa)", async () => {
    // Panel ve sunucu ayri dagitiliyor; yeni panel bir an eski yanit
    // alabilir. Olculdu: alanlar zorunlu sayilinca cizim `undefined.length`
    // ile cokuyordu.
    kur({
      adimlar: [{ kod: "blok", sayi: 0, tamam: false, atlandi: false }],
      toplam: 1,
      gecilen: 0,
    });
    ciz(KurulumPage);
    expect(await screen.findByText(/^Bloklar$/)).toBeInTheDocument();
    expect(screen.queryByText(/Zorunlu adımlar:/)).toBeNull();
  });
});
