// @vitest-environment jsdom
// (P193 §4-5) TESIS AYARLARI EKRANI — YONETICININ ULASABILDIGI AYARLAR.
//
// =========================================================================
// OLCULEN SEY
// =========================================================================
// Rehberde iki eksik (2 ve 3): sunucu `PATCH /tenant/settings`in bir
// kismini yoneticiye ACIYORDU (`_YONETICI_YAZABILIR`) ama tek ayar ekrani
// PLATFORM yuzeyindeydi — yonetici tesis adini bile web'den
// degistiremiyordu. Ustune (eksik 1) tesis ADRESI diye bir alan hic yoktu.
//
// Bu dosya ekranin dogru alanlari cizdigini, PLATFORMA ait olanlari
// CIZMEDIGINI ve yalniz DEGISEN alani gonderdigini kilitler.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TesisAyarlariPage from "@/app/(protected)/tesis-ayarlari/page";

import { ciz, fetchSahtele } from "./yardimci";

const AYARLAR = {
  tenant_id: "99999999-9999-9999-9999-999999999999",
  ad: "Acme Plaza",
  slug: "acme-plaza",
  timezone: "Europe/Istanbul",
  kurulum_tamamlandi: true,
  adres: null,
  ilce: null,
  il: null,
  posta_kodu: null,
  gurultu_esigi: 5,
  okutma_mesafe_esigi_m: 50,
  rezervasyon_gecmis_ay: 12,
  tur_gecikme_toleransi_dk: 10,
  tur_alarm_tekrar_sayisi: 3,
  tur_baslangic_foto_zorunlu: false,
  guvenlik_modu: "yonetim_ici",
  gurultu_uyari_metni: null,
};

function kur() {
  fetchSahtele({ "/api/tenant/settings": AYARLAR });
  const govdeler: Record<string, unknown>[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method === "PATCH" && init.body) {
      govdeler.push(JSON.parse(String(init.body)));
    }
    return onceki(g, init);
  }) as typeof fetch;
  return govdeler;
}

afterEach(() => vi.restoreAllMocks());

describe("(P193 §5) tesis ayarları ekranı", () => {
  it("TESIS ADI ve ADRES alanlari CIZILIR", async () => {
    kur();
    ciz(TesisAyarlariPage);
    expect(await screen.findByLabelText(/Tesis adı/)).toHaveValue("Acme Plaza");
    for (const etiket of [/Açık adres/, /İlçe/, /^İl$/, /Posta kodu/]) {
      expect(screen.getByLabelText(etiket)).toBeInTheDocument();
    }
    // Adresin NEREDE gorunecegi yaziyor: nereye cikacagini bilmeden
    // doldurulan bir alan, bos birakilan bir alandir.
    expect(screen.getByText(/makbuzunda ve rapor/i)).toBeInTheDocument();
  });

  it("PLATFORMA AIT alanlar CIZILMEZ ve nedeni YAZILI", async () => {
    kur();
    ciz(TesisAyarlariPage);
    await screen.findByLabelText(/Tesis adı/);
    // Guvenlik modu `adminOnly`: sunucu da yoneticiye 403 verir.
    expect(screen.queryByLabelText(/Güvenlik modu/)).toBeNull();
    expect(screen.queryByLabelText(/Zaman dilimi|Saat dilimi/)).toBeNull();
    expect(screen.getByText(/Saat dilimi, tesis kodu ve güvenlik modu/)).toBeInTheDocument();
  });

  it("ISLETME ayarlari (gurultu, okutma, rezervasyon) CIZILIR", async () => {
    kur();
    ciz(TesisAyarlariPage);
    await screen.findByLabelText(/Tesis adı/);
    expect(screen.getByLabelText(/Gürültü/)).toBeInTheDocument();
    expect(screen.getByLabelText(/Okutma/)).toBeInTheDocument();
  });

  it("YALNIZ DEGISEN alan gonderilir", async () => {
    const govdeler = kur();
    ciz(TesisAyarlariPage);
    const adres = await screen.findByLabelText(/Açık adres/);
    await userEvent.type(adres, "Örnek Mah. No:5");
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/ }));
    await waitFor(() => expect(govdeler.length).toBe(1));
    // Tek alan: dokunulmamis alanlar gonderilmez (gereksiz yazma ve
    // ileride kisitlanirsa beklenmedik 403).
    expect(govdeler[0]).toEqual({ adres: "Örnek Mah. No:5" });
  });

  it("HICBIR SEY DEGISMEDIYSE istek ATILMAZ", async () => {
    const govdeler = kur();
    ciz(TesisAyarlariPage);
    await screen.findByLabelText(/Tesis adı/);
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/ }));
    await waitFor(() =>
      expect(screen.getByText(/Değişiklik yok|değişiklik/i)).toBeInTheDocument(),
    );
    expect(govdeler.length).toBe(0);
  });
});
