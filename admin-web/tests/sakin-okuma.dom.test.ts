// @vitest-environment jsdom
// (P126.3) SAKIN SALT-OKUMA EKRANLARI — duyurular, site kurallari, etkinlikler.
//
// Uc sayfa da AYNI iki kurali tasir ve ikisi de sessizce bozulabilir:
//  1. YAZMA DUGMESI YOK — sunucu yonetici olmayani zaten reddeder, ama
//     kullaniciya basip 403 alacagi bir dugme gostermek "yetkim var sandim"
//     demektir;
//  2. HATA VARKEN "kayit yok" DENMEZ (P61) — liste `data?.items ?? []`den
//     turer ve istek dustugunde de bos gorunur.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import DuyurularPage from "@/app/(protected)/duyurular/page";
import EtkinliklerPage from "@/app/(protected)/etkinlikler/page";
import SiteKurallariPage from "@/app/(protected)/kurallar/page";

import { ciz } from "./yardimci";

function taklit(harita: Record<string, unknown>, durum = 200) {
  const cagrilar: string[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    cagrilar.push(url);
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

const SENARYOLAR = [
  {
    ad: "Duyurular",
    Sayfa: DuyurularPage,
    uc: "/api/announcements",
    kayit: {
      id: "d1",
      baslik: "Havuz bakımı",
      govde: "Havuz salı kapalı.",
      created_at: "2026-08-01T09:00:00Z",
    },
    gorunen: "Havuz bakımı",
    bosMetin: /Henüz duyuru yok/i,
  },
  {
    ad: "Site kuralları",
    Sayfa: SiteKurallariPage,
    uc: "/api/site-rules",
    kayit: { id: "k1", baslik: "Gürültü", icerik: "23:00 sonrası sessizlik.", sira: 1 },
    gorunen: "Gürültü",
    bosMetin: /kural tanımlanmamış/i,
  },
  {
    ad: "Etkinlikler",
    Sayfa: EtkinliklerPage,
    uc: "/api/events",
    kayit: {
      id: "e1",
      baslik: "Bahar şenliği",
      aciklama: "Bahçede.",
      tarih: "2026-09-01T15:00:00Z",
      konum: "Bahçe",
    },
    gorunen: "Bahar şenliği",
    bosMetin: /Yaklaşan etkinlik yok/i,
  },
];

for (const s of SENARYOLAR) {
  describe(s.ad, () => {
    it("kayitlar listelenir ve DOGRU uca gidilir", async () => {
      const c = taklit({ [s.uc]: { items: [s.kayit] } });
      ciz(s.Sayfa);
      expect(await screen.findByText(s.gorunen)).toBeInTheDocument();
      expect(c.some((u) => u.startsWith(s.uc))).toBe(true);
    });

    it("KAYIT YOKKEN bos durum gosterilir", async () => {
      taklit({ [s.uc]: { items: [] } });
      ciz(s.Sayfa);
      expect(await screen.findByText(s.bosMetin)).toBeInTheDocument();
    });

    it("istek DUSTUGUNDE 'kayit yok' YAZILMAZ (P61)", async () => {
      taklit({ [s.uc]: { error: { message: "patladi" } } }, 500);
      ciz(s.Sayfa);
      await waitFor(() =>
        expect(screen.getByText(/bir hata/i)).toBeInTheDocument(),
      );
      expect(screen.queryByText(s.bosMetin)).toBeNull();
    });

    it("YAZMA dugmesi YOK (salt okuma)", async () => {
      taklit({ [s.uc]: { items: [s.kayit] } });
      ciz(s.Sayfa);
      await screen.findByText(s.gorunen);
      // Hicbir dugme olmamali: bu ekranlar okuyan tarafin.
      expect(screen.queryAllByRole("button")).toHaveLength(0);
    });
  });
}
