// @vitest-environment jsdom
// (P126.4) GUVENLIK EKRANLARI — kargo, olaylar, arac gecisleri.
//
// Uc kural olculur, ucu de sessizce yanlis olabilecek cinsten:
//  1. OLAY KAYNAGI `manuel` SABITTIR — kullaniciya kaynak sectirmek,
//     otomatik uretilmis (kamera/devriye) bir kaydi elle taklit etmesine
//     izin vermek olurdu; olay kaydinin kanit degeri buradan gelir.
//  2. ARAC GECISLERINDE YAZMA YOK — kayitlar ANPR'den otomatik gelir;
//     elle plaka yazmak, otomatik kayitla celisen ikinci bir gercek uretir.
//  3. Hata varken "kayit yok" DENMEZ (P61).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import AracGecisleriPage from "@/app/(protected)/arac-gecisleri/page";
import KargolarPage from "@/app/(protected)/kargolar/page";
import OlaylarPage from "@/app/(protected)/olaylar/page";

import { ciz } from "./yardimci";

function taklit(harita: Record<string, unknown>, durum = 200) {
  const cagrilar: { url: string; method: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    if (anahtar === undefined) {
      return new Response(JSON.stringify({ error: { message: "yok" } }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify(harita[anahtar]), {
      status: durum,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

describe("Kargolar", () => {
  const KARGO = {
    id: "k1",
    unit_no: "A-12",
    firma: "Yurtiçi",
    notlar: null,
    durum: "bekliyor",
    created_at: "2026-08-04T09:00:00Z",
  };

  it("kayitlar listelenir, durum CEVRILMIS gosterilir", async () => {
    taklit({ "/api/kargo": { items: [KARGO] } });
    ciz(KargolarPage);
    expect(await screen.findByText("A-12")).toBeInTheDocument();
    // Ham enum ("bekliyor") DEGIL, cevrilmis etiket.
    // (P244 §8a) SATIRDAN OKUNUR: ayni kelime artik durum SUZGECININ
    // seceneginde de geciyor; kapsamsiz sorgu ikisini birden bulurdu ve
    // "listede gorunuyor" iddiasini suzgec secenegiyle de KARSILARDI.
    expect(screen.getByRole("cell", { name: "Bekliyor" })).toBeInTheDocument();
    expect(screen.queryByText("bekliyor")).toBeNull();
  });

  it("DAIRE NO olmadan gonderilmez", async () => {
    const c = taklit({ "/api/kargo": { items: [] } });
    ciz(KargolarPage);
    // (P161) Form artik MODALDA: once acilir. Kaydet dugmesi MODAL
    // KAPSAMINDA aranir — acici dugme ("Yeni kargo teslim al") ayni
    // ifadeyi tasiyor ve kapsamsiz sorgu ikisini birden bulur.
    await userEvent.click(await screen.findByRole("button", { name: "Yeni kargo teslim al" }));
    const kutu = await screen.findByRole("dialog");
    await userEvent.click(within(kutu).getByRole("button", { name: /Teslim al/i }));
    expect(await screen.findByText(/zorunludur/i)).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });

  it("kayit DAIRE NUMARASI ile gider", async () => {
    const c = taklit({ "/api/kargo": { items: [] } });
    ciz(KargolarPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni kargo teslim al" }));
    const kutu = await screen.findByRole("dialog");
    await userEvent.type(within(kutu).getByLabelText(/Daire no/i), "B-3");
    await userEvent.click(within(kutu).getByRole("button", { name: /Teslim al/i }));
    await waitFor(() => {
      const post = c.find((x) => x.method === "POST");
      expect(post?.body).toMatchObject({ unit_no: "B-3" });
    });
  });
});

describe("Olaylar", () => {
  const OLAY = {
    id: "o1",
    baslik: "Kapı açık kalmış",
    aciklama: null,
    kaynak: "manuel",
    konum: "Otopark",
    durum: "yeni",
    created_at: "2026-08-04T09:00:00Z",
  };

  it("KAYNAK `manuel` SABIT gonderilir — kullaniciya sectirilmez", async () => {
    const c = taklit({ "/api/violations": { items: [] } });
    ciz(OlaylarPage);
    // (P161) Form artik MODALDA.
    await userEvent.click(await screen.findByRole("button", { name: "Yeni olay bildir" }));
    // `/Konu/i` "Konum" ile de eslesiyor; TAM eslesme sart.
    await userEvent.type(await screen.findByLabelText("Konu"), "Kapı açık");
    await userEvent.click(screen.getByRole("button", { name: /^Bildir$/i }));
    await waitFor(() => {
      const post = c.find((x) => x.method === "POST");
      expect(post?.body).toMatchObject({ kaynak: "manuel" });
    });
    /**
     * Kaynak secimi icin bir acilir liste OLMAMALI.
     *
     * (P245) IDDIA VEKILDEN GERCEGE CEVRILDI. Eski surum "SAYFADA hic
     * `combobox` yok" diyordu; bu, kuralin kendisi degil bir
     * VEKILIYDI ve sayfaya bir DURUM SUZGECI eklenince dustu —
     * suzgecin kaynakla ilgisi yok.
     *
     * Olculen kural aynen duruyor: kaynak FORMDA sectirilmez. Sorgu
     * artik DIYALOGA kapsamlaniyor.
     */
    const diyalog = screen.getByRole("dialog");
    expect(within(diyalog).queryByRole("combobox")).toBeNull();
  });

  it("KONU olmadan gonderilmez", async () => {
    const c = taklit({ "/api/violations": { items: [] } });
    ciz(OlaylarPage);
    // (P161) Form artik MODALDA.
    await userEvent.click(await screen.findByRole("button", { name: "Yeni olay bildir" }));
    await userEvent.click(
      await screen.findByRole("button", { name: /^Bildir$/i }),
    );
    expect(await screen.findByText(/zorunludur/i)).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });

  it("kaynak ve durum CEVRILMIS gosterilir", async () => {
    taklit({ "/api/violations": { items: [OLAY] } });
    ciz(OlaylarPage);
    expect(await screen.findByText("Kapı açık kalmış")).toBeInTheDocument();
    expect(screen.getByText(/Elle bildirim/)).toBeInTheDocument();
    // (P245) "Yeni" artik durum SUZGECININ seceneginde de geciyor;
    // kapsamsiz sorgu iddiayi secenekle de karsilardi. Satirdan okunur.
    expect(screen.getByRole("cell", { name: "Yeni" })).toBeInTheDocument();
  });
});

describe("Araç geçişleri", () => {
  const GECIS = {
    id: "g1",
    plaka: "34ABC123",
    arac_tanim: "Beyaz panelvan",
    giris_zamani: "2026-08-04T09:00:00Z",
    cikis_zamani: null,
    unit_no: null,
    ziyaretci_mi: true,
  };

  it("kayitlar listelenir ve OTOMATIK oldugu YAZILI", async () => {
    taklit({ "/api/vehicle-passes": { items: [GECIS] } });
    ciz(AracGecisleriPage);
    expect(await screen.findByText("34ABC123")).toBeInTheDocument();
    expect(screen.getByText(/otomatik oluşur/i)).toBeInTheDocument();
  });

  it("YAZMA yolu YOK (okuma kontrolleri serbest)", async () => {
    // Elle plaka yazmak, otomatik kayitla celisen ikinci bir gercek uretir.
    //
    // (P244 §6) OLCUT DEGISTI, KURAL AYNI.
    // -----------------------------------------------------------------
    // Eski iddia "hic dugme ve hic metin kutusu yok"tu ve bu, "yazma
    // yolu yok"un VEKILIYDI. Sayfaya ARAMA ve FILTRE gelince vekil
    // dustu — ama kural dusmedi: arama kutusu bir OKUMA kontroludur,
    // kayit uretmez.
    //
    // Olculen sey artik dogrudan kuralin kendisi: form YOK ve
    // "yeni/ekle" gibi bir OLUSTURMA eylemi YOK. (Gercek guvence BFF'te:
    // rota yalniz `GET` disa aktarir — `bff-yol-eslesmesi` onu olcuyor.)
    taklit({ "/api/vehicle-passes": { items: [GECIS] } });
    const { container } = ciz(AracGecisleriPage);
    await screen.findByText("34ABC123");
    expect(container.querySelector("form")).toBeNull();
    const olusturma = screen
      .queryAllByRole("button")
      .filter((b) => /yeni|ekle|oluştur|kaydet/i.test(b.textContent ?? ""));
    expect(olusturma).toHaveLength(0);
  });

  it("istek DUSTUGUNDE 'kayit yok' YAZILMAZ (P61)", async () => {
    taklit({ "/api/vehicle-passes": { error: { message: "x" } } }, 500);
    ciz(AracGecisleriPage);
    await waitFor(() =>
      expect(screen.getByText(/bir hata/i)).toBeInTheDocument(),
    );
    expect(screen.queryByText(/geçiş kaydı yok/i)).toBeNull();
  });
});
