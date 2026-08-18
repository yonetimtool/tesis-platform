// @vitest-environment jsdom
// (P44) Mesaj sayfasi — SMS SAYACI ve RIZA/AMAC ayrimi.
//
// Sayacin ekranda olmasi P32'nin urun karariydi: Turkce harf tuzagi mesaji
// UCS-2'ye dusurur ve 160'lik sinir 70'e iner. Sayac cizilmezse kullanici
// faturayi GONDERDIKTEN SONRA gorur — bu test tam olarak o cizimi korur.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import MesajlarPage from "@/app/(protected)/mesajlar/page";

import { ciz, fetchSahtele } from "./yardimci";

const SABLONLAR = {
  meta: { limit: 100, offset: 0, total: 2 },
  items: [
    { id: "s1", kanal: "sms", ad: "Bakiye Bildirimi", konu: null,
      govde: "Sayın {adi_soyadi}", amac: "operasyonel", aktif: true },
    { id: "s2", kanal: "eposta", ad: "Kampanya", konu: "Duyuru",
      govde: "Merhaba", amac: "pazarlama", aktif: true },
  ],
};
const GECMIS = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "g1", kanal: "sms", amac: "operasyonel", hedef: "+905321112233",
            konu: null, durum: "gonderildi", hata: null,
            created_at: "2026-08-01T09:00:00Z" }],
};

afterEach(() => vi.restoreAllMocks());

describe("Mesaj sayfasi", () => {
  it("(P168 §4) SEKMELER cizilir ve varsayilan GONDERIM", async () => {
    // Brief dort sekme istiyor. Onceki hâl tek uzun sayfaydi ve SMS ile
    // e-posta sablonlari AYNI tabloda karisik duruyordu.
    fetchSahtele({
      "/api/panel/mesaj-sablonlari": SABLONLAR,
      "/api/panel/mesaj-gecmis": GECMIS,
    });
    ciz(MesajlarPage);
    for (const ad of ["Gönderim", "SMS Şablonları", "E-posta Şablonları", "Ayarlar"]) {
      expect(await screen.findByRole("tab", { name: ad })).toBeInTheDocument();
    }
    // Varsayilan sekme GONDERIM: kullanicinin en sik yaptigi is odur.
    expect(screen.getByRole("tab", { name: "Gönderim" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
  });

  it("(P168 §4) SMS sekmesi YALNIZ sms sablonlarini gosterir", async () => {
    // Iki farkli isin ayni listede olmasi, kullaniciyi her seferinde
    // kanal sutununu okumaya zorluyordu.
    fetchSahtele({
      "/api/panel/mesaj-sablonlari": SABLONLAR,
      "/api/panel/mesaj-gecmis": GECMIS,
    });
    ciz(MesajlarPage);
    await userEvent.click(await screen.findByRole("tab", { name: "SMS Şablonları" }));
    expect(await screen.findByText("Bakiye Bildirimi")).toBeInTheDocument();
    expect(screen.queryByText("Kampanya")).toBeNull();
  });

  it("AMAC sablonda gorunur (gonderimde secilmez)", async () => {
    // P32: ayni sablonun bir gun pazarlama bir gun operasyonel
    // gonderilmesi riza denetimini anlamsiz kilardi.
    fetchSahtele({
      "/api/panel/mesaj-sablonlari": SABLONLAR,
      "/api/panel/mesaj-gecmis": GECMIS,
    });
    ciz(MesajlarPage);
    // (P168 §4) Sablonlar artik KANAL SEKMELERINDE; amac sutunu orada.
    await userEvent.click(await screen.findByRole("tab", { name: "SMS Şablonları" }));
    expect(await screen.findByText("Operasyonel")).toBeInTheDocument();
    await userEvent.click(screen.getByRole("tab", { name: "E-posta Şablonları" }));
    expect(await screen.findByText("Pazarlama")).toBeInTheDocument();
  });

  it("SMS SAYACI ve UCS-2 uyarisi cizilir", async () => {
    fetchSahtele({
      "/api/panel/mesaj-sablonlari": SABLONLAR,
      "/api/panel/mesaj-gecmis": GECMIS,
      "/api/panel/mesaj-onizleme": {
        konu: null, govde: "Sayın Ali",
        karakter: 9, unicode_mi: true, parca: 1, kalan: 61,
        zorlayan: ["ı", "ş"],
      },
    });
    ciz(MesajlarPage);
    await waitFor(() =>
      expect(screen.getAllByText("Bakiye Bildirimi").length).toBeGreaterThan(0),
    );

    await userEvent.selectOptions(screen.getByLabelText("Şablon"), "s1");
    await userEvent.click(screen.getByRole("button", { name: "Önizle" }));

    await waitFor(() => expect(screen.getByText("Sayın Ali")).toBeInTheDocument());
    // Parca ve kalan GORUNUR. Metin birden cok dugume bolundugu icin
    // (etiket + <b>sayi</b>) kapsayici uzerinden aranir.
    const sayac = screen.getByText(/SMS parçası/).textContent ?? "";
    expect(sayac).toContain("Karakter");
    expect(sayac).toContain("Kalan");
    // ZORLAYAN karakterler gosterilir: "neden 3 SMS oldu" sorusunu
    // kullanicinin metne bakip tahmin etmesine birakmak sayaci yarim
    // gostermek olurdu.
    expect(screen.getByText("ı ş")).toBeInTheDocument();
  });

  it("AD ve GOVDE bos ise istek ATILMAZ", async () => {
    fetchSahtele({
      "/api/panel/mesaj-sablonlari": SABLONLAR,
      "/api/panel/mesaj-gecmis": GECMIS,
    });
    ciz(MesajlarPage);
    // (P161) Form artik MODALDA: once acilir.
    await userEvent.click(await screen.findByRole("button", { name: "Yeni şablon" }));
    await waitFor(() =>
      expect(screen.getAllByText("Bakiye Bildirimi").length).toBeGreaterThan(0),
    );
    await userEvent.click(screen.getByRole("button", { name: "Şablonu kaydet" }));
    await waitFor(() =>
      expect(screen.getByText("Ad ve gövde zorunludur.")).toBeInTheDocument(),
    );
  });

  it("KANAL e-posta secilince KONU alani belirir", async () => {
    // SMS'te konu YOKTUR; alani her zaman gostermek, gonderilmeyecek bir
    // veriyi doldurtmak olurdu.
    fetchSahtele({
      "/api/panel/mesaj-sablonlari": SABLONLAR,
      "/api/panel/mesaj-gecmis": GECMIS,
    });
    ciz(MesajlarPage);
    // (P161) Form artik MODALDA: once acilir.
    await userEvent.click(await screen.findByRole("button", { name: "Yeni şablon" }));
    await waitFor(() =>
      expect(screen.getAllByText("Bakiye Bildirimi").length).toBeGreaterThan(0),
    );
    expect(screen.queryByLabelText("Konu")).not.toBeInTheDocument();

    const kanallar = screen.getAllByLabelText("Kanal");
    await userEvent.selectOptions(kanallar[0], "eposta");
    expect(screen.getByLabelText("Konu")).toBeInTheDocument();
  });
});
