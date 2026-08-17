// @vitest-environment jsdom
// (P167 §2.1/§2.5) PANEL DUZENLEME MODU — CIZIM ve KAYIT.
//
// `pano-ozellestirme.test.ts` KUMEYI olcuyor (hangi bolum, hangi sirada);
// bu dosya DAVRANISI: dugme sayfayi duzenleme moduna sokuyor mu, gizlenen
// bolum SUNUCUYA yaziliyor mu, "Varsayilana don" gercekten sifirliyor mu.
//
// EN PAHALI SONUC: duzeni degistirip KAYDEDILDIGINI sanmak. Sessizdir —
// kullanici ertesi gun eski panoyu bulur ve neden oldugunu bilemez. Bu
// yuzden testin agirligi PUT govdesindedir, ekrandaki gorunumde degil.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DashboardPage from "@/app/(protected)/dashboard/page";

import { ciz } from "./yardimci";

interface Cagri {
  url: string;
  method: string;
  body: unknown;
}

function fetchTaklidi(tercih: unknown = {}) {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const govde = url.includes("/api/dashboard/live")
      ? {
          generated_at: "2026-08-04T22:30:00Z",
          aktif_turlar: [],
          alarm_gruplari: [],
          aidat_tahsilat_orani: 78,
          nfc_nokta_sayisi: 0,
        }
      : url.includes("/api/cameras")
        ? { meta: { limit: 50, offset: 0, total: 0 }, items: [] }
        : url.includes("/api/me/pano-tercihi")
          ? tercih
          : url.includes("/api/panel/kasa-bakiyeleri")
            ? { items: [], genel_toplam_kurus: 0 }
            : url.includes("/api/panel/finans-ozet")
              ? {
                  borclandirilan_ay_kurus: 100,
                  tahsil_edilen_ay_kurus: 50,
                  acik_borc_kurus: 50,
                  kasa_toplam_kurus: 0,
                  icra_acik_dosya: 0,
                  borc_kurus: 0,
                  onay_bekleyen_adet: 0,
                  odenmis_fatura_ay_kurus: 0,
                }
              : url.includes("/api/takvim")
                ? { items: [] }
                : {};
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

describe("(P167 §2.5) panel duzenleme modu", () => {
  it("VARSAYILAN olarak KAPALI — sira dugmeleri gorunmez", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    expect(screen.queryByRole("button", { name: "Yukarı taşı" })).toBeNull();
    expect(screen.getByRole("button", { name: "Paneli düzenle" })).toBeInTheDocument();
  });

  it("ACILINCA her bolumun sira ve gizle dugmeleri cizilir", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    await userEvent.setup().click(
      screen.getByRole("button", { name: "Paneli düzenle" }),
    );
    expect(screen.getAllByRole("button", { name: "Yukarı taşı" }).length)
      .toBeGreaterThan(1);
    expect(screen.getAllByRole("button", { name: "Bölümü gizle" }).length)
      .toBeGreaterThan(1);
  });

  it("GIZLEME SUNUCUYA YAZILIR (sessizce kaybolmaz)", async () => {
    const cagrilar = fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    const kullanici = userEvent.setup();
    await kullanici.click(screen.getByRole("button", { name: "Paneli düzenle" }));
    await kullanici.click(screen.getAllByRole("button", { name: "Bölümü gizle" })[0]);

    await waitFor(() => {
      const put = cagrilar.find(
        (c) => c.url.includes("/api/me/pano-tercihi") && c.method === "PUT",
      );
      expect(put, "duzen SUNUCUYA yazilmadi").toBeTruthy();
      const govde = put!.body as { bolumler: { id: string; gizli: boolean }[] };
      expect(govde.bolumler[0].gizli).toBe(true);
    });
  });

  it("GIZLI BOLUM normal modda CIZILMEZ, duzenleme modunda GORUNUR", async () => {
    // Kullanici neyi geri acacagini gormeli — duzenleme modunda satir
    // DOM'da kalir (soluk cizilir).
    fetchTaklidi({ bolumler: [{ id: "takvim", gizli: true }] });
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    expect(screen.queryByText("Takvim")).toBeNull();

    await userEvent.setup().click(
      screen.getByRole("button", { name: "Paneli düzenle" }),
    );
    expect(await screen.findByText("Takvim")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bölümü göster" })).toBeInTheDocument();
  });

  it("VARSAYILANA DON butun bolumleri geri acar ve YAZAR", async () => {
    const cagrilar = fetchTaklidi({
      bolumler: [{ id: "takvim", gizli: true }, { id: "finans", gizli: true }],
    });
    ciz(DashboardPage);
    await screen.findByText("Site maketi");
    const kullanici = userEvent.setup();
    await kullanici.click(screen.getByRole("button", { name: "Paneli düzenle" }));
    await kullanici.click(screen.getByRole("button", { name: "Varsayılana dön" }));

    await waitFor(() => {
      const put = cagrilar
        .filter((c) => c.url.includes("/api/me/pano-tercihi") && c.method === "PUT")
        .at(-1);
      expect(put).toBeTruthy();
      const govde = put!.body as { bolumler: { gizli: boolean }[] };
      expect(govde.bolumler.every((b) => !b.gizli)).toBe(true);
    });
  });

  it("KAYITLI SIRA cizime yansir", async () => {
    // Kullanici takvimi en uste almis: kayit ne diyorsa ekran onu
    // gostermeli.
    fetchTaklidi({ bolumler: [{ id: "takvim" }, { id: "finans" }] });
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    const metin = document.body.textContent ?? "";
    expect(metin.indexOf("Takvim")).toBeLessThan(metin.indexOf("Finansal özet"));
  });
});

describe("(P167 §2.2) finansal ozet", () => {
  it("ALTI KART cizilir ve KASALAR paneli ayri durur", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    for (const etiket of [
      "Borçlandırılan (bu ay)",
      "Tahsil edilen (bu ay)",
      "Borçlarım",
      "Alacaklarım",
      "Onay bekleyen hareketler",
      "Ödenmiş faturalar (bu ay)",
    ]) {
      expect(await screen.findByText(etiket)).toBeInTheDocument();
    }
    expect(screen.getByText("Kasalar")).toBeInTheDocument();
    expect(screen.getByText("Genel toplam")).toBeInTheDocument();
  });

  it("EXCEL ve PDF SIMGELERI var (metin dugme degil)", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    const excel = await screen.findByRole("button", { name: "Excel olarak indir" });
    const pdf = screen.getByRole("button", { name: "PDF olarak indir" });
    // GORUNEN metin YOK — ikon. Erisilebilir ad `aria-label`den geliyor.
    expect(excel.textContent?.trim()).toBe("");
    expect(pdf.querySelector("svg")).not.toBeNull();
  });

  it("TUTARLAR SAYMA ANIMASYONU OLMADAN, dogru degerle cizilir", async () => {
    // Brief: "Tutarlarda animasyonlu sayac KULLANMA — para sayarken
    // gercek olmayan bakiye gorunur." Ilk karede DOGRU deger olmali.
    fetchTaklidi();
    ciz(DashboardPage);
    // 100 kurus = 1,00 TL
    expect(await screen.findByText(/1,00/)).toBeInTheDocument();
  });
});
