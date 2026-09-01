// @vitest-environment jsdom
// (P193 §3) UC EKRAN BOSLUGU — ONAY/RET, TERS KAYIT, EKSTRE HESABI.
//
// =========================================================================
// OLCULEN SEY
// =========================================================================
// P192 uc yeni yetenegi SUNUCUYA ekledi ama panelde dugmesi yoktu:
//
//   7. Onay bekleyen gideri onaylayamiyor/reddedemiyorsunuz.
//   8. Yanlis tahakkuku duzeltemiyorsunuz (ters kayit).
//   9. Ekstre yuklerken hangi banka hesabina yazilacagini secemiyorsunuz.
//
// Uclarin CALISTIGI ayrica olculdu (docs/P193-kararlar.md §3). Bu dosya
// EKRAN yarisini kilitler: dugmeler CIZILIYOR mu, dogru YOLA gidiyor mu,
// ve yapilamayacak eylemde CIZILMIYOR mu (kullaniciya 409 aldirmamak).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BankaSayfasi from "@/app/(protected)/finans/banka/page";
import BorclandirmalarPage from "@/app/(protected)/finans/borclandirmalar/page";
import GiderlerPage from "@/app/(protected)/finans/giderler/page";

import { ciz, fetchSahtele } from "./yardimci";

/** Yazma isteklerini yakalar: hangi YOLA hangi metotla gidildi. */
function istekleriYakala(): { yol: string; metot: string }[] {
  const kayit: { yol: string; metot: string }[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method && init.method !== "GET") {
      kayit.push({ yol: String(girdi), metot: init.method });
    }
    return onceki(girdi, init);
  }) as typeof fetch;
  return kayit;
}

afterEach(() => vi.restoreAllMocks());

// ==================== 1) ONAY BEKLEYEN GIDER (eksik 7) ==================== //

const BEKLEYEN = {
  id: "11111111-1111-1111-1111-111111111111",
  tarih: "2026-08-01", belge_no: "GDR-1", tutar_kurus: 250000,
  tip: "gider", durum: "onay_bekliyor", aciklama: "Asansör bakımı",
  kasa_id: null, yon: "cikis",
};
const ODENMIS = { ...BEKLEYEN, id: "22222222-2222-2222-2222-222222222222",
  belge_no: "GDR-2", durum: "odendi", aciklama: "Temizlik" };

describe("(P193 §3) onay bekleyen gider", () => {
  function kur() {
    fetchSahtele({
      "/api/panel/finans-hareketler": {
        meta: { total: 2 }, items: [BEKLEYEN, ODENMIS],
      },
      "/api/panel/kasalar": { items: [] },
    });
  }

  it("BEKLEYEN satirda ONAYLA ve REDDET var, ODENMIS satirda YOK", async () => {
    kur();
    ciz(GiderlerPage);
    const bekleyenSatir = (await screen.findByText("Asansör bakımı")).closest("tr")!;
    expect(within(bekleyenSatir).getByRole("button", { name: "Onayla" })).toBeInTheDocument();
    expect(within(bekleyenSatir).getByRole("button", { name: "Reddet" })).toBeInTheDocument();
    // Gerceklesmis kayitta onay sorusu YOKTUR; orada eylem IPTALDIR.
    const odenmisSatir = screen.getByText("Temizlik").closest("tr")!;
    expect(within(odenmisSatir).queryByRole("button", { name: "Onayla" })).toBeNull();
    expect(within(odenmisSatir).getByRole("button", { name: /İptal et/ })).toBeInTheDocument();
  });

  it("ONAYLA -> onay diyalogu -> POST .../onayla", async () => {
    kur();
    const istekler = istekleriYakala();
    ciz(GiderlerPage);
    const satir = (await screen.findByText("Asansör bakımı")).closest("tr")!;
    await userEvent.click(within(satir).getByRole("button", { name: "Onayla" }));
    // ONAY SORULUR: defteri hemen etkileyen bir eylem tek tikla olmaz.
    const diyalog = await screen.findByRole("dialog");
    expect(within(diyalog).getByText(/kasadan düşülecek/)).toBeInTheDocument();
    await userEvent.click(within(diyalog).getByRole("button", { name: "Onayla" }));
    await waitFor(() => expect(istekler.length).toBe(1));
    expect(istekler[0]).toEqual({
      yol: `/api/panel/finans-hareketler/${BEKLEYEN.id}/onayla`,
      metot: "POST",
    });
  });

  it("REDDET -> POST .../reddet", async () => {
    kur();
    const istekler = istekleriYakala();
    ciz(GiderlerPage);
    const satir = (await screen.findByText("Asansör bakımı")).closest("tr")!;
    await userEvent.click(within(satir).getByRole("button", { name: "Reddet" }));
    const diyalog = await screen.findByRole("dialog");
    await userEvent.click(within(diyalog).getByRole("button", { name: "Reddet" }));
    await waitFor(() => expect(istekler.length).toBe(1));
    expect(istekler[0].yol).toBe(
      `/api/panel/finans-hareketler/${BEKLEYEN.id}/reddet`,
    );
  });
});

// ==================== 2) TAHAKKUK TERS KAYDI (eksik 8) ==================== //

const TAHAKKUK = {
  id: "33333333-3333-3333-3333-333333333333",
  unit_id: "44444444-4444-4444-4444-444444444444",
  donem: "2026-08", tutar_kurus: 75000, son_odeme_tarihi: "2026-08-15",
  aciklama: "Ağustos aidatı", gelir_gider_tanim_ad: "Aidat",
  hedef_ad: "A-1", tarih: "2026-08-01", gecikme_kurus: 0,
  ters_kayit_id: null, iptal_edildi: false,
};

describe("(P193 §3) tahakkuk düzeltme", () => {
  function kur(ekstra: Record<string, unknown>[] = []) {
    fetchSahtele({
      "/api/panel/dues-assessments": {
        meta: { total: 1 + ekstra.length }, items: [TAHAKKUK, ...ekstra],
      },
      "/api/panel/gecikme-faizi-onizleme": {
        uygulaniyor: false, toplam_fark_kurus: 0, items: [],
      },
      "/api/panel/gecikme-ayari": { uygulaniyor: false },
    });
  }

  it("DUZELT dugmesi POST .../ters-kayit gonderir", async () => {
    kur();
    const istekler = istekleriYakala();
    ciz(BorclandirmalarPage);
    const satir = (await screen.findByText("Ağustos aidatı")).closest("tr")!;
    await userEvent.click(within(satir).getByRole("button", { name: "Düzelt" }));
    const diyalog = await screen.findByRole("dialog");
    // ONAY METNI "SILINIR" DEMEZ: kayit kalir, ters satir eklenir.
    expect(within(diyalog).getByText(/ters bir satır/)).toBeInTheDocument();
    await userEvent.click(within(diyalog).getByRole("button", { name: "Düzelt" }));
    await waitFor(() => expect(istekler.length).toBe(1));
    expect(istekler[0]).toEqual({
      yol: `/api/panel/dues-assessments/${TAHAKKUK.id}/ters-kayit`,
      metot: "POST",
    });
  });

  it("ZATEN DUZELTILMIS ve DUZELTME SATIRINDA dugme CIZILMEZ", async () => {
    // Ikisinde de uc reddederdi (409 / 422). Basilamayacak bir dugme
    // gostermek kullaniciya "sistem bozuk" dedirtir.
    kur([
      { ...TAHAKKUK, id: "55555555-5555-5555-5555-555555555555",
        aciklama: "Düzeltilmiş borç", iptal_edildi: true },
      { ...TAHAKKUK, id: "66666666-6666-6666-6666-666666666666",
        aciklama: "Ters kayıt", ters_kayit_id: TAHAKKUK.id },
    ]);
    ciz(BorclandirmalarPage);
    const a = (await screen.findByText("Düzeltilmiş borç")).closest("tr")!;
    expect(within(a).queryByRole("button", { name: "Düzelt" })).toBeNull();
    expect(within(a).getByText("Düzeltildi")).toBeInTheDocument();
    const b = screen.getByText("Ters kayıt").closest("tr")!;
    expect(within(b).queryByRole("button", { name: "Düzelt" })).toBeNull();
    expect(within(b).getByText("Düzeltme satırı")).toBeInTheDocument();
  });
});

// ================== 3) EKSTRE HEDEF HESABI (eksik 9) ================== //

const BANKA_KASA = {
  id: "77777777-7777-7777-7777-777777777777",
  ad: "Ziraat - Site Hesabı", banka_mi: true,
};
const NAKIT_KASA = {
  id: "88888888-8888-8888-8888-888888888888", ad: "Kasa", banka_mi: false,
};

describe("(P193 §3) ekstre hedef hesabı", () => {
  function kur() {
    fetchSahtele({
      "/api/banka/hareketler": { meta: { total: 0 }, items: [] },
      "/api/banka": { meta: { total: 0 }, items: [] },
      "/api/users": { meta: { total: 0 }, items: [] },
      "/api/panel/kasalar": { items: [BANKA_KASA, NAKIT_KASA] },
    });
  }

  it("YALNIZ BANKA kasalari secenek olur", async () => {
    kur();
    ciz(BankaSayfasi);
    const secim = await screen.findByLabelText(/Bu ekstre hangi hesaba ait/);
    const secenekler = within(secim as HTMLElement).getAllByRole("option");
    const adlar = secenekler.map((o) => o.textContent);
    expect(adlar).toContain("Ziraat - Site Hesabı");
    // Nakit kasaya ekstre yazmak anlamsizdir.
    expect(adlar).not.toContain("Kasa");
    // Varsayilan secenek DURUR: tek hesapli tesis secim yapmak zorunda
    // kalmamali.
    expect(adlar[0]).toMatch(/Varsayılan/);
  });

  it("SECILEN HESAP govdede kasa_id olarak GIDER", async () => {
    kur();
    const govdeler: Record<string, unknown>[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
      if (String(g).includes("/api/banka/ice-aktar") && init?.body) {
        govdeler.push(JSON.parse(String(init.body)));
      }
      return onceki(g, init);
    }) as typeof fetch;

    ciz(BankaSayfasi);
    const secim = await screen.findByLabelText(/Bu ekstre hangi hesaba ait/);
    await userEvent.selectOptions(secim, BANKA_KASA.id);

    // MT940 yolu: dosya okuma katmanini karistirmadan govdeyi olcer.
    const dosya = new File([":61:2608010801D500,00NTRF//X\n"], "ekstre.sta", {
      type: "text/plain",
    });
    await userEvent.upload(screen.getByLabelText(/Dosya seç/i), dosya);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: /İçe aktar/ })).toBeEnabled(),
    );
    await userEvent.click(screen.getByRole("button", { name: /İçe aktar/ }));
    await waitFor(() => expect(govdeler.length).toBe(1));
    expect(govdeler[0].kasa_id).toBe(BANKA_KASA.id);
  });
});
