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
import { fireEvent, screen, waitFor } from "@testing-library/react";
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

// (P184 §11) DUZENLEME ARTIK TEK ETKILESIM: SURUKLE-BIRAK.
//
// Onceki kalabalik kontrol cubugu (sutun 1/2/3/4 dugmeleri + banner girdisi +
// yukari/asagi + bolum basi gizle/goster) KALDIRILDI. Kalan tek gorsel kontrol
// her bolumdeki SURUKLE tutamaci; gizleme "Gizli bolumler" TEPSISINE surukleyerek
// yapilir, geri acma tepsiden tuvale surukleyerek. Klavye tasima (ok tuslari)
// surukle-birak'in erisilebilir esi olarak DURUYOR.
//
// jsdom gercek HTML5 surukle-birak uretmez; dragStart/dragOver/drop olaylari
// ELLE tetiklenir (uygulamanin dinledigi olaylar bunlar, veri aktarimi degil).
function surukleBirak(kaynak: Element, hedef: Element) {
  fireEvent.dragStart(kaynak);
  fireEvent.dragOver(hedef);
  fireEvent.drop(hedef);
  fireEvent.dragEnd(kaynak);
}

describe("(P167 §2.5 · P184 §11) panel duzenleme modu", () => {
  it("VARSAYILAN olarak KAPALI — surukle tutamaci gorunmez", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    // Normal gorunumde hicbir duzenleme kontrolu cizilmez.
    expect(
      screen.queryByRole("button", { name: /sürükleyin ya da ok tuşlarını/ }),
    ).toBeNull();
    expect(screen.getByRole("button", { name: "Paneli düzenle" })).toBeInTheDocument();
  });

  it("ACILINCA her bolumun SURUKLE tutamaci cizilir; sutun/banner/gizle dugmeleri YOK", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    await userEvent.setup().click(
      screen.getByRole("button", { name: "Paneli düzenle" }),
    );
    // Her bolum basliginda tek surukle tutamaci (klavye ile de tasir).
    expect(
      screen.getAllByRole("button", { name: /sürükleyin ya da ok tuşlarını/ }).length,
    ).toBeGreaterThan(1);
    // (P184 §11) KALDIRILAN kontroller: per-bolum gizle/goster dugmesi, sutun
    // sayisi dugmeleri, banner girdisi, satir tasima dugmeleri.
    expect(screen.queryByRole("button", { name: "Bölümü gizle" })).toBeNull();
    expect(screen.queryByRole("button", { name: "Bölümü göster" })).toBeNull();
    expect(screen.queryByPlaceholderText("Başlık (isteğe bağlı)")).toBeNull();
    expect(screen.queryByRole("button", { name: "Satırı yukarı" })).toBeNull();
    // Tepsi basligi cizilir.
    expect(screen.getByText("Gizli bölümler")).toBeInTheDocument();
  });

  it("KLAVYE ile bolum tasima (ok tusu) SUNUCUYA YAZILIR", async () => {
    // (P182 §4 · P184 §11) Surukle-birak'in erisilebilir esi: tutamaca odaklan,
    // sag ok ile satir icinde kaydir; yeni sira PUT govdesine dusmeli.
    const cagrilar = fetchTaklidi({
      bolumler: [{ id: "finans" }, { id: "takvim" }],
      satirlar: [{ sutun: 2, idler: ["finans", "takvim"], baslik: null }],
    });
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    const kullanici = userEvent.setup();
    await kullanici.click(screen.getByRole("button", { name: "Paneli düzenle" }));
    const tutamac = screen.getByRole("button", {
      name: /Finansal özet bölümünü taşı/,
    });
    tutamac.focus();
    fireEvent.keyDown(tutamac, { key: "ArrowRight" });

    await waitFor(() => {
      const put = cagrilar
        .filter((c) => c.url.includes("/api/me/pano-tercihi") && c.method === "PUT")
        .at(-1);
      expect(put, "klavye tasima yazilmadi").toBeTruthy();
      const govde = put!.body as { satirlar: { idler: string[] }[] };
      expect(govde.satirlar[0].idler).toEqual(["takvim", "finans"]);
    });
  });

  it("SURUKLE-BIRAK ile YENIDEN SIRALAMA SUNUCUYA YAZILIR", async () => {
    // (P184 §11) Tek etkilesim: finansi takvimin ONUNE surukle -> sira degisir.
    const cagrilar = fetchTaklidi({
      bolumler: [{ id: "takvim" }, { id: "finans" }],
      satirlar: [{ sutun: 1, idler: ["takvim"], baslik: null },
                 { sutun: 1, idler: ["finans"], baslik: null }],
    });
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    const kullanici = userEvent.setup();
    await kullanici.click(screen.getByRole("button", { name: "Paneli düzenle" }));
    // Tutulan: FINANS tutamaci; hedef: TAKVIM bolumu (onune birakilir).
    const finansTut = screen.getByRole("button", { name: /Finansal özet bölümünü taşı/ });
    const takvimBolum = screen
      .getByRole("button", { name: /Takvim bölümünü taşı/ })
      .closest("section")!;
    surukleBirak(finansTut, takvimBolum);

    await waitFor(() => {
      const put = cagrilar
        .filter((c) => c.url.includes("/api/me/pano-tercihi") && c.method === "PUT")
        .at(-1);
      expect(put, "surukle siralama yazilmadi").toBeTruthy();
      const govde = put!.body as { bolumler: { id: string }[] };
      expect(govde.bolumler[0].id).toBe("finans");
    });
  });

  it("TEPSIYE SURUKLEME gizli=true olarak SUNUCUYA YAZILIR", async () => {
    // (P184 §11) Gizleme artik tepsiye surukleyerek: bolumu al, "Gizli bolumler"
    // tepsisine birak; PUT govdesinde o bolum gizli=true olmali.
    const cagrilar = fetchTaklidi();
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    const kullanici = userEvent.setup();
    await kullanici.click(screen.getByRole("button", { name: "Paneli düzenle" }));
    const finansTut = screen.getByRole("button", { name: /Finansal özet bölümünü taşı/ });
    // Tepsi = "Gizli bolumler" basligini iceren border'li kutu.
    const tepsi = screen.getByText("Gizli bölümler").closest("div")!.parentElement!;
    surukleBirak(finansTut, tepsi);

    await waitFor(() => {
      const put = cagrilar
        .filter((c) => c.url.includes("/api/me/pano-tercihi") && c.method === "PUT")
        .at(-1);
      expect(put, "gizleme SUNUCUYA yazilmadi").toBeTruthy();
      const govde = put!.body as { bolumler: { id: string; gizli: boolean }[] };
      expect(govde.bolumler.find((b) => b.id === "finans")?.gizli).toBe(true);
    });
  });

  it("GIZLI BOLUM normal modda CIZILMEZ, duzenleme modunda TEPSIDE GORUNUR", async () => {
    // (P184 §11) Kullanici neyi geri acacagini tepside gormeli: gizli bolum
    // duzenleme modunda tepside bir surukle tutamaci olarak durur.
    fetchTaklidi({ bolumler: [{ id: "takvim", gizli: true }] });
    ciz(DashboardPage);
    await screen.findByText("Finansal özet");
    expect(screen.queryByText("Takvim")).toBeNull();

    await userEvent.setup().click(
      screen.getByRole("button", { name: "Paneli düzenle" }),
    );
    // Tepside "Takvim" etiketli surukle tutamaci gorunur.
    expect(
      await screen.findByRole("button", { name: /Takvim bölümünü taşı/ }),
    ).toBeInTheDocument();
    expect(screen.getByText("Gizli bölümler")).toBeInTheDocument();
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
