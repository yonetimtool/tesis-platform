// @vitest-environment jsdom
// (P44) Ayarlar — SESSIZ HATA SINIFI: DEGISMEYEN ALAN GONDERILMEMELI.
//
// `guvenlik_modu`nu her kayitta gondermek yoneticiye 403 verirdi (o alani
// yalniz admin gonderebilir) — yani kullanici degistirmedigi bir alan
// yuzunden kaydedemezdi.
//
// (P154 / Asama 7.2) BU DOSYA ESKIDEN PORTAL TESTLERINI DE TASIYORDU
// (`portal-ayar.dom.test.ts`). Portal kaldirildi; anketin "en az iki
// secenek" kurali `anketler.dom.test.ts`e TASINDI, silinmedi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import SettingsPage from "@/app/(protected)/settings/page";

import { ciz, fetchSahtele } from "./yardimci";

const AYARLAR = {
  tenant_id: "11111111-1111-1111-1111-111111111111",
  ad: "Acme Plaza", slug: "acme-plaza", timezone: "Europe/Istanbul",
  kurulum_tamamlandi: true,
  tur_gecikme_toleransi_dk: 10, tur_alarm_tekrar_sayisi: 3,
  tur_baslangic_foto_zorunlu: false, guvenlik_modu: "yonetim_ici",
  gurultu_esigi: 5, gurultu_uyari_metni: null,
};

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
