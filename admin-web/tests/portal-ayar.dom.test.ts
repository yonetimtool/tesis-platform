// @vitest-environment jsdom
// (P44) Portal yonetimi + Ayarlar — IKI SESSIZ HATA SINIFI.
//
// 1) Portal yayin anahtari: "doldurdum ama yayinlamadim" ile "yayinladim"
//    farki gorunur olmali ve anahtar ANINDA kaydedilmeli (kaydet'e basmayi
//    bekleyen bir anahtar, kullanicinin yayinladigini sanmasi demekti).
// 2) Ayarlar: DEGISMEYEN ALAN GONDERILMEMELI — `guvenlik_modu`nu her
//    kayitta gondermek yoneticiye 403 verirdi (o alani yalniz admin
//    gonderebilir).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import PortalPage from "@/app/(protected)/portal/page";
import SettingsPage from "@/app/(protected)/settings/page";

import { ciz, fetchSahtele } from "./yardimci";

const PORTAL = {
  yayinda: false, hero_baslik: "Huzur Sitesi", hero_alt: null,
  hakkimizda: null, iletisim_adres: null, iletisim_telefon: null,
  iletisim_email: null,
};
const AYARLAR = {
  tenant_id: "11111111-1111-1111-1111-111111111111",
  ad: "Acme Plaza", slug: "acme-plaza", timezone: "Europe/Istanbul",
  kurulum_tamamlandi: true,
  tur_gecikme_toleransi_dk: 10, tur_alarm_tekrar_sayisi: 3,
  tur_baslangic_foto_zorunlu: false, guvenlik_modu: "yonetim_ici",
  gurultu_esigi: 5, gurultu_uyari_metni: null,
};
const BOS = { meta: { limit: 50, offset: 0, total: 0 }, items: [] };

afterEach(() => vi.restoreAllMocks());

function govdeYakala(harita: Record<string, unknown>): Record<string, unknown>[] {
  fetchSahtele(harita);
  const govdeler: Record<string, unknown>[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method === "PATCH" && init.body) {
      govdeler.push(JSON.parse(String(init.body)));
    }
    return onceki(girdi, init);
  }) as typeof fetch;
  return govdeler;
}

describe("Portal yonetimi", () => {
  it("YAYIN ANAHTARI aninda kaydedilir", async () => {
    const govdeler = govdeYakala({
      "/api/panel/portal": PORTAL,
      "/api/panel/anketler": BOS,
      "/api/panel/portal-iletisim": BOS,
    });
    ciz(PortalPage);
    await waitFor(() =>
      expect(screen.getByLabelText(/Site sayfası yayında/)).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByLabelText(/Site sayfası yayında/));
    await waitFor(() => expect(govdeler.length).toBe(1));
    expect(govdeler[0]).toEqual({ yayinda: true });
  });

  it("ANKET en az IKI secenek ister — istek ATILMAZ", async () => {
    // Tek secenekli anket oy toplamaz, ONAY toplar (P38). Sunucuya sorup
    // 422 almak yerine burada soyleniyor.
    const govdeler = govdeYakala({
      "/api/panel/portal": PORTAL,
      "/api/panel/anketler": BOS,
      "/api/panel/portal-iletisim": BOS,
    });
    ciz(PortalPage);
    await waitFor(() => expect(screen.getByText("Anketler")).toBeInTheDocument());

    await userEvent.type(screen.getByLabelText("Anket başlığı"), "Otopark");
    await userEvent.type(screen.getByLabelText(/Seçenekler/), "Evet");
    await userEvent.click(screen.getByRole("button", { name: "Anketi aç" }));

    await waitFor(() =>
      expect(
        screen.getByText("Başlık ve en az iki seçenek gerekir."),
      ).toBeInTheDocument(),
    );
    expect(govdeler.length).toBe(0);
  });
});

describe("Ayarlar — operasyon", () => {
  it("DEGISMEYEN ALAN gonderilmez", async () => {
    const govdeler = govdeYakala({ "/api/tenant/settings": AYARLAR });
    ciz(SettingsPage);
    // (P55) ETIKETIN VARLIGI YETMEZ, DEGERIN GELMESI BEKLENIR. Form
    // sunucu yanitiyla BIR KEZ dolar; alan cizildigi anda hala bostur.
    // Bos alanda `clear()` bir sey yapmaz, sonra doldurma etkisi kosar ve
    // yazilan metin sunucu degerinin ARDINA eklenirdi: 10 + "25" = 1025.
    // Test 14 kosumun 1'inde boyle duserdi — urun kodu saglam, yaris
    // testin kendisindeydi.
    await waitFor(() =>
      expect(screen.getByLabelText(/Tur gecikme toleransı/)).toHaveValue(10),
    );

    const alan = screen.getByLabelText(/Tur gecikme toleransı/);
    await userEvent.clear(alan);
    await userEvent.type(alan, "25");
    await userEvent.click(screen.getAllByRole("button", { name: "Kaydet" })[1]);

    await waitFor(() => expect(govdeler.length).toBe(1));
    // YALNIZ degisen alan; `guvenlik_modu` GITMEZ (yoneticiye 403 verirdi).
    expect(Object.keys(govdeler[0])).toEqual(["tur_gecikme_toleransi_dk"]);
    expect(govdeler[0].tur_gecikme_toleransi_dk).toBe(25);
  });

  it("HIC DEGISIKLIK yoksa istek ATILMAZ", async () => {
    const govdeler = govdeYakala({ "/api/tenant/settings": AYARLAR });
    ciz(SettingsPage);
    await waitFor(() =>
      expect(screen.getByLabelText(/Tur gecikme toleransı/)).toBeInTheDocument(),
    );
    await userEvent.click(screen.getAllByRole("button", { name: "Kaydet" })[1]);
    await waitFor(() =>
      expect(screen.getByText("Değişiklik yok.")).toBeInTheDocument(),
    );
    expect(govdeler.length).toBe(0);
  });
});
