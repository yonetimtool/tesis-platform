// @vitest-environment jsdom
// (P132.3/4) PANO — mobil hiyerarsi + harita + kamera seridi.
//
// OLCULEN SEY GORUNUM DEGIL DAVRANIS: hangi bolumler var, hangi sirada,
// veri yokken ne cizilir, harita anahtarsizken nereye duser, kamera
// seridi kac karo gosterir ve OTOMATIK OYNATMIYOR mu.
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
const ALARM = {
  tip: "tur_kacirildi",
  mesaj: "Gece turu kaçırıldı",
  olusma_zamani: "2026-08-04T23:05:00Z",
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
  alarmlar = [ALARM],
  kameralar = [KAMERA],
  tesis = { konum_lat: 41.01, konum_lon: 28.97, konum_ad: "Acme Plaza", ad: "Acme" },
}: Record<string, unknown> = {}) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    const govde = url.includes("/api/dashboard/live")
      ? { generated_at: "2026-08-04T23:10:00Z", aktif_turlar: turlar, son_alarmlar: alarmlar }
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

describe("(P132.3) pano bolumleri — mobil SIRASI", () => {
  it("hizli ozet -> tur durumu -> son hareketler -> kameralar", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Gece turu");
    const metin = document.body.textContent ?? "";
    const sira = ["Bugünkü Turlar", "Son Alarmlar", "Kameralar"].map((b) => metin.indexOf(b));
    // Hepsi VAR ve SIRA korunuyor (mobil ana ekranla ayni).
    expect(sira.every((i) => i >= 0), metin.slice(0, 200)).toBe(true);
    expect(sira).toEqual([...sira].sort((a, b) => a - b));
  });

  it("VERI YOKKEN bos durum cizilir (cıplak spinner ya da bos ekran DEGIL)", async () => {
    fetchTaklidi({ turlar: [], alarmlar: [], kameralar: [] });
    ciz(DashboardPage);
    expect(await screen.findByText(/Bugün için tur yok/i)).toBeInTheDocument();
    expect(await screen.findByText(/Alarm yok/i)).toBeInTheDocument();
  });

  it("istatistik kartlari sayilari OZETLER", async () => {
    fetchTaklidi({
      turlar: [TUR, { ...TUR, patrol_window_id: "w2", durum: "tamamlandi" }],
    });
    ciz(DashboardPage);
    // 2 tur, 1 tamamlanan, 1 bekleyen, 1 alarm.
    await waitFor(() => expect(screen.getAllByText("2").length).toBeGreaterThan(0));
    expect(screen.getAllByText("1").length).toBeGreaterThanOrEqual(2);
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
    // "Gece turu" iki yerde gecer (tur satiri + alarm metni); bolumun
    // CIZILDIGINI bekleyip kamera basligini sorgulamak yeterli.
    await screen.findAllByText(/Gece turu/);
    expect(screen.queryByText("Kameralar")).toBeNull();
  });
});
