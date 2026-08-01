// @vitest-environment jsdom
// (P51) Vardiya ve NFC noktalari — GECE VARDIYASI ve NFC normalizasyonu.
//
// Ikisi de "sessizce yanlis calisan" sinifindan: gece vardiyasi
// (baslangic > bitis) kullaniciya SOYLENMEZSE, yonetici yanlis girdigini
// sanip saatleri duzeltmeye calisir; NFC etiketi ise buyuk/kucuk harf ve
// bosluk farkiyla girilirse eslesme sessizce dusen bir okutmaya doner.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import CheckpointsPage from "@/app/(protected)/checkpoints/page";
import NotificationsPage from "@/app/(protected)/notifications/page";
import ShiftsPage from "@/app/(protected)/shifts/page";

import { ciz, fetchSahtele } from "./yardimci";

const VARDIYALAR = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "v1", ad: "Gündüz", baslangic_saat: "08:00",
            bitis_saat: "16:00", gun_tipi: "her_gun",
            created_at: "2026-01-01T00:00:00Z" }],
};
const NOKTALAR = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "c1", ad: "Ana Kapı", nfc_tag_uid: "04A1B2C3D4E5F6",
            gps_lat: null, gps_lng: null, aktif: true,
            created_at: "2026-01-01T00:00:00Z" }],
};

afterEach(() => vi.restoreAllMocks());

describe("Vardiyalar", () => {
  it("GECE VARDIYASI uyarisi YALNIZ baslangic > bitis iken cikar", async () => {
    fetchSahtele({ "/api/shifts": VARDIYALAR });
    ciz(ShiftsPage);
    await waitFor(() => expect(screen.getByText("Gündüz")).toBeInTheDocument());

    // Formu ac (yeni vardiya): varsayilan 00:00-08:00 → gece DEGIL.
    await userEvent.click(screen.getAllByRole("button", { name: /Ekle|Yeni/ })[0]);
    const uyari = screen.queryByText(/ertesi güne|gece/i);
    expect(uyari).not.toBeInTheDocument();

    // Baslangici bitisten SONRAYA al → uyari cikmali.
    const saatler = screen.getAllByDisplayValue("00:00");
    await userEvent.clear(saatler[0]);
    await userEvent.type(saatler[0], "22:00");
    await waitFor(() =>
      expect(screen.getByText(/ertesi güne|gece/i)).toBeInTheDocument(),
    );
  });

  it("UC DUSTUGUNDE hata gorunur — bos liste GOSTERILMEZ", async () => {
    fetchSahtele({});
    ciz(ShiftsPage);
    await waitFor(() => expect(screen.getByText("yok")).toBeInTheDocument());
    expect(screen.queryByText("Gündüz")).not.toBeInTheDocument();
  });
});

describe("NFC noktalari", () => {
  it("etiket UID'i OLDUGU GIBI gosterilir (normalizasyon SUNUCUDA)", async () => {
    // Panelde kirpma/buyutme yapmak, sunucunun normalizasyonuyla
    // ayrisan ikinci bir kural demekti: kullanici panelde gordugu degeri
    // etikette bulamayabilirdi.
    fetchSahtele({ "/api/checkpoints": NOKTALAR });
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("Ana Kapı")).toBeInTheDocument());
    expect(screen.getByText("04A1B2C3D4E5F6")).toBeInTheDocument();
  });

  it("UC DUSTUGUNDE hata gorunur", async () => {
    fetchSahtele({});
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("yok")).toBeInTheDocument());
    expect(screen.queryByText("Ana Kapı")).not.toBeInTheDocument();
  });
});

// ---------------------------------------------------------------------------
// Bildirimler (P51): iki gercek kusur bu testlerle kapandi.
//   1) `tip` HAM tel degeriyle ciziliyordu — kullanici rozette
//      "gecikmis_okutma" goruyordu.
//   2) "Okundu isaretle" HAM `fetch` kullaniyordu: basarisiz yanit da
//      cozulur, dolayisiyla 500 sonrasi BASARI bildirimi cikiyor,
//      bildirim okunmamis kaliyordu (sessiz basarisizlik).
const BILDIRIMLER = {
  meta: { limit: 20, offset: 0, total: 2 },
  items: [
    { id: "n1", tip: "gecikmis_okutma", mesaj: "Tur geç okutuldu.",
      okundu: false, created_at: "2026-02-01T10:00:00Z" },
    { id: "n2", tip: "peyzaj_yaklasan", mesaj: "Eski kayıt.",
      okundu: true, created_at: "2026-02-01T09:00:00Z" },
  ],
};

describe("Bildirimler", () => {
  it("tip CEVIRIYLE cizilir; cevirisi olmayan tip HAM kalir", async () => {
    fetchSahtele({ "/api/notifications": BILDIRIMLER });
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByText("gecikmiş okutma")).toBeInTheDocument(),
    );
    expect(screen.queryByText("gecikmis_okutma")).not.toBeInTheDocument();
    // Urunden kaldirilmis eski tip: rozet BOS KALMAZ, ham deger gorunur.
    expect(screen.getByText("peyzaj_yaklasan")).toBeInTheDocument();
  });

  it("okundu isaretleme BASARISIZ olursa BASARI bildirimi CIKMAZ", async () => {
    fetchSahtele({
      "/api/notifications": BILDIRIMLER,
      "/api/notifications/n1": { __durum: 500, error: { code: "server_error", message: "Sunucu hatası." } },
    });
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByText("Tur geç okutuldu.")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: /Okundu/i }));
    await waitFor(() =>
      expect(screen.getByText("Sunucu hatası.")).toBeInTheDocument(),
    );
    expect(
      screen.queryByText(/okundu olarak işaretlendi/i),
    ).not.toBeInTheDocument();
  });
});
