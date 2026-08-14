// @vitest-environment jsdom
// (P132.3/4 · P133.2) PANO — bolumler, harita, kamera seridi.
//
// OLCULEN SEY GORUNUM DEGIL DAVRANIS: hangi bolumler var, hangi sirada,
// veri yokken ne cizilir, harita anahtarsizken nereye duser, kamera
// seridi kac karo gosterir ve OTOMATIK OYNATMIYOR mu.
//
// (P133.2) YAPI DEGISTI: dort istatistik karti + iki liste yerine
// selamlama cumlesi -> KAHRAMAN blok -> ikincil tint bloklar -> gruplu
// alarmlar + tesis blogu -> kamera seridi. Beklentiler yeni yapiyi
// olcuyor; olculen INVARYANTLAR ayni kaldi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DashboardPage from "@/app/(protected)/dashboard/page";
import { haritaAdresi } from "@/components/SiteHarita";

import { ciz } from "./yardimci";

const TUR = {
  patrol_window_id: "w1",
  patrol_plan_id: "p1",
  patrol_plan_ad: "Gece turu",
  pencere_baslangic: "2026-08-04T22:00:00Z",
  pencere_bitis: "2026-08-04T23:00:00Z",
  durum: "bekliyor",
  okutulan_checkpoint_sayisi: 2,
  beklenen_checkpoint_sayisi: 5,
};
// (P133.3) Alarmlar artik GRUPLU geliyor.
const ALARM_GRUBU = {
  tip: "kacirilan_tur",
  patrol_plan_id: "p1",
  patrol_plan_ad: "Gece turu",
  mesaj: "Gece turu kaçırıldı",
  sayi: 3,
  en_son: "2026-08-04T23:05:00Z",
  onem: "yuksek",
  olaylar: [
    { olusma_zamani: "2026-08-04T23:05:00Z", patrol_window_id: "w9" },
    { olusma_zamani: "2026-08-04T22:05:00Z", patrol_window_id: "w8" },
    { olusma_zamani: "2026-08-04T21:05:00Z", patrol_window_id: "w7" },
  ],
};
const KAMERA = {
  id: "k1",
  ad: "Ana Kapı",
  konum: null,
  stream_url: "https://o/live.m3u8",
  tur: "hls",
  aktif: true,
  sakin_gorebilir: true,
  restream_url: null,
  snapshot_url: "https://o/kare.jpg",
  oynatilabilir: true,
};

function fetchTaklidi({
  turlar = [TUR],
  alarmlar = [ALARM_GRUBU],
  kameralar = [KAMERA],
  tesis = { konum_lat: 41.01, konum_lon: 28.97, konum_ad: "Acme Plaza", ad: "Acme" },
  tahsilat = 78,
  simdi = "2026-08-04T22:30:00Z",
}: Record<string, unknown> = {}) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    const govde = url.includes("/api/dashboard/live")
      ? {
          // `generated_at` KAHRAMAN blogun secimini belirler: pencere
          // 22:00-23:00 ve "simdi" 22:30 => tur SURUYOR.
          generated_at: simdi,
          aktif_turlar: turlar,
          alarm_gruplari: alarmlar,
          aidat_tahsilat_orani: tahsilat,
          nfc_nokta_sayisi: 12,
        }
      : url.includes("/api/cameras")
        ? { meta: { limit: 50, offset: 0, total: (kameralar as unknown[]).length }, items: kameralar }
        : url.includes("/api/tenant/settings")
          ? tesis
          : {};
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P133.2) pano bolumleri — SIRA", () => {
  it("kahraman -> alarmlar -> tesis -> kameralar", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    // Ad IKI yerde gecer (kahraman blok + alarm grubu) — `findAllByText`.
    await screen.findAllByText("Gece turu");
    const metin = document.body.textContent ?? "";
    const sira = ["Süren devriye", "Son Alarmlar", "Tesis", "Kameralar"].map((b) =>
      metin.indexOf(b),
    );
    expect(sira.every((i) => i >= 0), metin.slice(0, 300)).toBe(true);
    expect(sira).toEqual([...sira].sort((a, b) => a - b));
  });

  it("VERI YOKKEN bos durum cizilir (cıplak spinner ya da bos ekran DEGIL)", async () => {
    fetchTaklidi({ turlar: [], alarmlar: [], kameralar: [] });
    ciz(DashboardPage);
    expect(
      await screen.findByText(/Bugün için planlanmış devriye yok/i),
    ).toBeInTheDocument();
    expect(await screen.findByText(/Bekleyen alarm yok/i)).toBeInTheDocument();
  });

  it("SURMEYEN gun SIRADAKI turu gosterir (bos durum degil)", async () => {
    // Pencere ILERIDE: "suren" yok ama gosterilecek bir sey VAR.
    fetchTaklidi({ simdi: "2026-08-04T20:00:00Z" });
    ciz(DashboardPage);
    expect(await screen.findByText(/Sıradaki devriye/i)).toBeInTheDocument();
    expect(screen.queryByText(/planlanmış devriye yok/i)).toBeNull();
  });

  it("IKINCIL bloklar sayilari OZETLER", async () => {
    fetchTaklidi({
      turlar: [TUR, { ...TUR, patrol_window_id: "w2", durum: "tamamlandi" }],
    });
    ciz(DashboardPage);
    // 2 tur, 1 tamamlanan, 3 geciken olay (grubun `sayi`si), %78 tahsilat.
    //
    // (P160) IDDIA ERISILEBILIR METINDEN OKUNUYOR. KPI halkasinin GORSEL
    // rakami 0'dan hedefe SAYARAK gelir, yani ara karelerde "%12" gibi bir
    // deger gosterir; gorsel metne bakan bir test yarisa girer. `sr-only`
    // metin ise HER ZAMAN gercek degeri tasir (sayan ara degerler ekran
    // okuyucuya okunmaz) — dogru kaynak da zaten odur.
    await waitFor(() =>
      expect(screen.getByText("Aidat tahsilatı: %78")).toBeInTheDocument(),
    );
    expect(screen.getByText(/Geciken okutma: 3$/)).toBeInTheDocument();
  });

  it("MALI BLOK yetki yoksa HIC cizilmez (0% degil)", async () => {
    // Sunucu guvenlik rollerine `null` doner; "%0" cizmek veriyi
    // sizdirmadan YANLIS bilgi vermek olurdu.
    fetchTaklidi({ tahsilat: null });
    ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    expect(screen.queryByText(/Aidat tahsilatı/i)).toBeNull();
  });
});

describe("(P133.3) alarmlar GRUPLU cizilir", () => {
  it("tek satir + olay sayisi; ayrinti ISTEGE acilir", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Gece turu kaçırıldı");
    expect(screen.getByText("3 olay")).toBeInTheDocument();

    // Olay satirlari KAPALI baslar — alti neredeyse ayni satir sikayeti.
    const acilir = screen.getByRole("button", { name: /olayları göster/i });
    await userEvent.setup().click(acilir);
    expect(
      screen.getByRole("button", { name: /olayları gizle/i }),
    ).toBeInTheDocument();
  });

  it("TEK OLAYLI grup acilmaz (gosterecegi yeni bir sey yok)", async () => {
    fetchTaklidi({
      alarmlar: [{ ...ALARM_GRUBU, sayi: 1, olaylar: [ALARM_GRUBU.olaylar[0]] }],
    });
    ciz(DashboardPage);
    await screen.findByText("Gece turu kaçırıldı");
    expect(screen.getByRole("button", { name: /olayları göster/i })).toBeDisabled();
  });
});

describe("(P132.4a) tesis konumu haritasi", () => {
  it("ANAHTAR YOKKEN OSM adresine duser", () => {
    const u = haritaAdresi(41.01, 28.97, null);
    expect(u).toContain("openstreetmap.org");
    expect(u).toContain("marker=41.01");
  });

  it("anahtar VARSA Google gomulusu", () => {
    const u = haritaAdresi(41.01, 28.97, "AIza-test");
    expect(u).toContain("google.com/maps/embed");
    expect(u).toContain("key=AIza-test");
  });

  it("KONUM YOKSA harita cizilmez, NE YAPILACAGI yazilir", async () => {
    fetchTaklidi({ tesis: { ad: "Acme" } });
    ciz(DashboardPage);
    expect(await screen.findByText(/Konum henüz girilmedi/i)).toBeInTheDocument();
    expect(document.querySelector("iframe")).toBeNull();
  });
});

describe("(P132.4b) kamera seridi", () => {
  it("EN COK 4 karo gosterir (serit, tam liste degil)", async () => {
    const cok = Array.from({ length: 7 }, (_, i) => ({
      ...KAMERA,
      id: `k${i}`,
      ad: `Kamera ${i}`,
    }));
    fetchTaklidi({ kameralar: cok });
    ciz(DashboardPage);
    await screen.findByText("Kamera 0");
    expect(screen.queryByText("Kamera 4")).toBeNull();
  });

  it("OTOMATIK OYNATMAZ — oynatici ancak tiklayinca acilir", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Ana Kapı");
    // Dort yayini birden calistirmak P43'te reddedilmisti.
    expect(document.querySelector("video")).toBeNull();

    const kullanici = userEvent.setup();
    await kullanici.click(screen.getByRole("button", { name: /yayınını aç/i }));
    await waitFor(() => expect(document.querySelector("video")).not.toBeNull());
  });

  it("kamera YOKSA bolum HIC cizilmez", async () => {
    fetchTaklidi({ kameralar: [] });
    ciz(DashboardPage);
    // "Gece turu" iki yerde gecer (kahraman blok + alarm grubu); bolumun
    // CIZILDIGINI bekleyip kamera basligini sorgulamak yeterli.
    await screen.findAllByText(/Gece turu/);
    expect(screen.queryByText("Kameralar")).toBeNull();
  });
});
