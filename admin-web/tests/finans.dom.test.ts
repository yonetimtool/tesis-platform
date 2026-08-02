// @vitest-environment jsdom
// (P43) Finans sayfasi — BILESEN testi (jsdom).
//
// Olculen sey "sayfa aciliyor mu" degil: PARA nasil cizilir, HATA sessiz
// kaliyor mu, ve YON isareti dogru mu. Ucuncusu onemli cunku P29'un karari
// geregi tutar HER ZAMAN POZITIFTIR; isaret `yon` alanindan gelir ve bu
// mantik yalnizca burada, cizim katmaninda yasar.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import FinansPage from "@/app/(protected)/finans/page";

import { ciz, fetchSahtele } from "./yardimci";

const OZET = {
  borclandirilan_ay_kurus: 150000,
  tahsil_edilen_ay_kurus: 100000,
  acik_borc_kurus: 50000,
  kasa_toplam_kurus: 250000,
  icra_acik_dosya: 2,
};
const KASALAR = {
  items: [{ kasa_id: "k1", kod: "MERKEZ", ad: "Merkez Kasa", bakiye_kurus: 250000 }],
  genel_toplam_kurus: 250000,
};
const HAREKETLER = {
  meta: { limit: 20, offset: 0, total: 2 },
  items: [
    {
      id: "h1", tip: "tahsilat", yon: "giris", tutar_kurus: 100000,
      tarih: "2026-08-01T10:00:00Z", kasa_ad: "Merkez Kasa",
      user_ad: "Ali Veli", belge_no: null, aciklama: "Aidat",
    },
    {
      id: "h2", tip: "gider", yon: "cikis", tutar_kurus: 25000,
      tarih: "2026-08-01T11:00:00Z", kasa_ad: "Merkez Kasa",
      user_ad: null, belge_no: "F-1", aciklama: null,
    },
  ],
};

afterEach(() => vi.restoreAllMocks());

describe("Finans sayfasi", () => {
  it("ozet, kasa ve hareketleri cizer; PARA kurustan TL'ye cevrilir", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    ciz(FinansPage);

    // 250000 kurus = 2.500,00 TL — panelde kurus GOSTERILMEZ.
    await waitFor(() => expect(screen.getAllByText(/2\.500,00/).length).toBeGreaterThan(0));
    expect(screen.getAllByText("Merkez Kasa").length).toBeGreaterThan(0);
    expect(screen.getByText("Ali Veli")).toBeInTheDocument();
  });

  it("YON isareti: giris +, cikis −  (tutar her zaman POZITIF)", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    ciz(FinansPage);

    await waitFor(() => expect(screen.getAllByText(/\+1\.000,00/).length).toBeGreaterThan(0));
    // U+2212 (matematiksel eksi) — ASCII tire DEGIL.
    expect(screen.getAllByText(/−250,00/).length).toBeGreaterThan(0);
  });

  it("UC DUSTUGUNDE hata gorunur — 'kayit yok' GOSTERILMEZ", async () => {
    // Bu ayrim tur 42'de bulunmustu: bos liste ile dusen uc ayni ekrani
    // veriyordu ve kullanici kasanin bos oldugunu saniyordu.
    fetchSahtele({ "/api/panel/finans-ozet": OZET });
    ciz(FinansPage);

    await waitFor(() =>
      expect(screen.getByText("Hareketler alınamadı.")).toBeInTheDocument(),
    );
    expect(screen.queryByText("Hareket yok")).not.toBeInTheDocument();
  });

  it("KASA YOKSA yonlendirici bos durum cizilir", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": { items: [], genel_toplam_kurus: 0 },
      "/api/panel/finans-hareketler": { meta: { limit: 20, offset: 0, total: 0 }, items: [] },
    });
    ciz(FinansPage);

    await waitFor(() =>
      expect(screen.getByText("Kasa tanımlanmamış")).toBeInTheDocument(),
    );
    // Bos durum KULLANICIYA NE YAPACAGINI soyler.
    expect(screen.getByText(/Tanımlar sayfasından/)).toBeInTheDocument();
  });

  // ------------------------- (P64) CIFT KAYIT -------------------------- //
  //
  // Dugmenin `ymesgul` kilidi yalniz HIZLI CIFT TIKLAMAYI onler. Korunmayan
  // sey ZAMAN ASIMI SONRASI TEKRARDI: istek sunucuya ulasip yanit donmezse
  // kullanici "kaydedilmedi" sanip tekrar basar. Anahtar o tekrarda AYNI
  // kalmali (sunucu ikinci kaydi acmaz), basaridan SONRA degismeli (sonraki
  // mesru hareket ayri bir islemdir).
  async function hareketYaz(tutar: string): Promise<void> {
    await userEvent.clear(screen.getByRole("textbox", { name: "Tutar" }));
    await userEvent.type(screen.getByRole("textbox", { name: "Tutar" }), tutar);
    await userEvent.click(screen.getByRole("button", { name: "Hareketi kaydet" }));
  }

  /** POST'larda gonderilen Idempotency-Key basliklarini toplar. */
  function anahtarlar(): string[] {
    const toplanan: string[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === "POST" && String(girdi).includes("finans-hareketler")) {
        const h = (init.headers ?? {}) as Record<string, string>;
        toplanan.push(h["Idempotency-Key"]);
      }
      return onceki(girdi, init);
    }) as typeof fetch;
    return toplanan;
  }

  it("TEKRAR DENEMEDE anahtar AYNI, basaridan sonra DEGISIR", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      // Ilk yazma DUSER (sunucuya ulasip yanit donmeyen istegin panel
      // tarafindaki karsiligi): kullanici tekrar basar.
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    const toplanan = anahtarlar();
    ciz(FinansPage);
    await waitFor(() => expect(screen.getAllByText("Merkez Kasa").length).toBeGreaterThan(0));

    await hareketYaz("100");
    await waitFor(() => expect(toplanan).toHaveLength(1));
    await hareketYaz("250");
    await waitFor(() => expect(toplanan).toHaveLength(2));

    expect(toplanan[0]).toBeTruthy();
    // Iki YAZMA da BASARILI oldugu icin anahtar YENILENMIS olmali —
    // aksi halde ikinci (mesru) hareket sunucuda TEKRAR sayilir ve
    // SESSIZCE KAYDEDILMEZDI.
    expect(toplanan[1]).not.toBe(toplanan[0]);
  });

  it("YAZMA DUSERSE anahtar KORUNUR (tekrar ayni islemdir)", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    const toplanan: string[] = [];
    const onceki = globalThis.fetch;
    let ilkYazma = true;
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === "POST" && String(girdi).includes("finans-hareketler")) {
        const h = (init.headers ?? {}) as Record<string, string>;
        toplanan.push(h["Idempotency-Key"]);
        if (ilkYazma) {
          ilkYazma = false;
          return new Response(JSON.stringify({ error: { message: "zaman asimi" } }), {
            status: 504,
            headers: { "Content-Type": "application/json" },
          });
        }
      }
      return onceki(girdi, init);
    }) as typeof fetch;

    ciz(FinansPage);
    await waitFor(() => expect(screen.getAllByText("Merkez Kasa").length).toBeGreaterThan(0));

    await hareketYaz("100");
    await waitFor(() => expect(toplanan).toHaveLength(1));
    await userEvent.click(screen.getByRole("button", { name: "Hareketi kaydet" }));
    await waitFor(() => expect(toplanan).toHaveLength(2));

    expect(toplanan[1]).toBe(toplanan[0]);
  });
});