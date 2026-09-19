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
    "blok", "daire", "sakin", "eposta", "kasa", "aidat",
  ]);
  // (P243 §6a) BLOK ve DAIRE de eksik: asgari kurulum tamamlanmamis.
  const eksik = ["blok", "daire", "kasa", "eposta"];
  const asgari = new Set(["blok", "daire"]);
  return {
    adimlar: kodlar.map((kod) => ({
      kod,
      sayi: eksik.includes(kod) ? 0 : 1,
      tamam: !eksik.includes(kod),
      atlandi: false,
      zorunlu: zorunlu.has(kod),
      asgari: asgari.has(kod),
    })),
    toplam: kodlar.length,
    gecilen: kodlar.length - eksik.length,
    zorunlu_toplam: zorunlu.size,
    eksik_zorunlular: eksik.filter((k) => zorunlu.has(k)),
    calisir: false,
    asgari_toplam: asgari.size,
    asgari_eksikler: ["blok", "daire"],
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

  it("EKSIK ADIMLAR ve NEYI ENGELLEDIKLERI yaziyor", async () => {
    kur();
    ciz(KurulumPage);
    await screen.findByText(/Çalışır kurulum için eksikler/);
    // "Sunu yap" degil, "yapmazsan su olmaz".
    // Engel metni hem ozette hem adim satirinda gecer (ikisi de eksik
    // adimlar); olculen sey METNIN GORUNMESI.
    expect(
      screen.getAllByText(/tahsilat ve gider kaydedilemez/i).length,
    ).toBeGreaterThan(0);
    expect(screen.getAllByText(/davetler gitmez/i).length).toBeGreaterThan(0);
  });

  // ===================================================================
  // (P243 §6a/§6f) ASGARI KURULUM — ILERLEME BASKI YAPMAZ
  // ===================================================================
  // OLCULEN KUSUR: 19 adimin 7'si "zorunlu"ydu ve aralarinda kasa,
  // gelir-gider tanimi, aidat vardi. Sihirbaz yeni yoneticiye, duyuru
  // yapabilmek icin once muhasebe kurmasi gerektigini sandiriyordu.
  it("BASLANGIC BOLUMU yalniz blok+daire ister", async () => {
    kur();
    ciz(KurulumPage);
    const kutu = await screen.findByTestId("kurulum-asgari");
    expect(kutu).toHaveTextContent(/Başlamak için gerekenler/);
    expect(kutu).toHaveTextContent(/0\/2 hazır/);
    expect(kutu).toHaveTextContent(/Bloklar/);
    expect(kutu).toHaveTextContent(/Kat ve daireler/);
    // KASA BURADA DEGIL: zorunlu ama asgari degil.
    expect(kutu).not.toHaveTextContent(/Kasa/);
  });

  it("YUZDE GOSTERGESI YOK — '%40 tamam' bir sitemdir", async () => {
    kur();
    ciz(KurulumPage);
    await screen.findByTestId("kurulum-asgari");
    expect(screen.queryByRole("progressbar")).toBeNull();
    expect(screen.queryByText(/Zorunlu adımlar:/)).toBeNull();
  });

  it("SONRA YAPILABILECEKLER bolumu — asgari adimlar BURADA DEGIL", async () => {
    kur();
    ciz(KurulumPage);
    const kutu = await screen.findByTestId("kurulum-sonra");
    expect(kutu).toHaveTextContent(/Şunları da yapabilirsiniz/);
    expect(kutu).toHaveTextContent(/Kasa/);
    // Asgari adim iki kez listelenmez.
    expect(kutu).not.toHaveTextContent(/Kat ve daireler/);
  });

  it("ATLANAN adim 'sonra yapabilirsiniz' listesine GIRMEZ", async () => {
    // Atlamak bilincli bir karardir; listeye geri yazmak sitem olurdu.
    const d = durum();
    d.adimlar = d.adimlar.map((a) =>
      // TAMAM DEGIL + ATLANDI: yalniz `atlandi` isaretlemek yetmez,
      // satir zaten `tamam` oldugu icin listede gorunmezdi ve kilit
      // hicbir seyi olcmezdi (kirarak dogrulandi).
      a.kod === "nfc_noktasi" ? { ...a, sayi: 0, tamam: false, atlandi: true } : a,
    );
    kur(d);
    ciz(KurulumPage);
    const kutu = await screen.findByTestId("kurulum-sonra");
    expect(kutu).not.toHaveTextContent(/NFC noktaları/);
  });

  it("HEPSI TAMAMSA ozet 'calisir durumda' der", async () => {
    const d = durum();
    d.adimlar = d.adimlar.map((a) => ({ ...a, sayi: 1, tamam: true }));
    d.eksik_zorunlular = [];
    d.calisir = true;
    d.asgari_eksikler = [];
    d.gecilen = d.toplam;
    kur(d);
    ciz(KurulumPage);
    expect(await screen.findByText(/Tesis çalışır durumda/)).toBeInTheDocument();
    expect(screen.queryByText(/Çalışır kurulum için eksikler/)).toBeNull();
    // Her sey bitince "sunlari da yapabilirsiniz" de cizilmez.
    expect(screen.queryByTestId("kurulum-sonra")).toBeNull();
    expect(screen.queryByTestId("kurulum-asgari")).toBeNull();
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
    // Eski sunucu asgari alanlarini gondermez: bolum HIC cizilmez,
    // "0/0 hazır" gibi anlamsiz bir sayac gosterilmez.
    expect(screen.queryByTestId("kurulum-asgari")).toBeNull();
  });
});
