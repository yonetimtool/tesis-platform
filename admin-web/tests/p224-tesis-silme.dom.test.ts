// @vitest-environment jsdom
// (P224) TESIS SILME — ONIZLEME + TESIS ADI ONAYI + ARSIV.
//
// =========================================================================
// OLCULEN KAZA
// =========================================================================
// Prod'da "Yönetio Platform" tesisi silindi, platform admin hesabi
// ON DELETE CASCADE ile gitti ve panele girilemez hale gelindi.
//
// Panelin o gunku hali:
//   * icinde NE OLDUGUNU soyleyen tek bir sayi yoktu,
//   * onay kelimesi HER TESISTE AYNI idi — yani yanlis tesisi silmeye
//     karsi hicbir sey yapmiyordu, sadece kas hafizasi uretiyordu.
//
// SAHTE HTTP KATMANINDA (P200 dersi): ozet/silme cagrilarini kuran katman
// da testten geciyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TenantDetayPage from "@/app/(protected)/tenants/[id]/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/tenants/t-1",
  useParams: () => ({ id: "t-1" }),
  useSearchParams: () => new URLSearchParams(),
}));

const json = (govde: unknown, status = 200) =>
  new Response(JSON.stringify(govde), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const DETAY = {
  tenant_id: "t-1",
  ad: "Yönetio Platform",
  kayit_kodu: "1234-5678-000001",
  kurulum_tamamlandi: true,
  created_at: "2026-01-01T00:00:00Z",
  yoneticiler: [],
};

const OZET_TEMIZ = {
  tenant_id: "t-1",
  ad: "Yönetio Platform",
  slug: "platform",
  arsivlendi_at: null,
  onay_metni: "Yönetio Platform",
  kullanici: 3,
  daire: 12,
  finansal_hareket: 0,
  sikayet: 0,
  belge: 2,
  denetim_kaydi: 41,
  dogrudan_silinebilir: true,
  platform_admini_var: false,
};

interface Cagri {
  url: string;
  metot: string;
}

function sahtele(ozet: Record<string, unknown>, cagrilar: Cagri[] = []) {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({ url, metot: init?.method ?? "GET" });
    if (url.includes("/silme-ozeti")) return json(ozet);
    // YONETICI LISTESI AYRI BIR ISTEK: `{}` donunce sayfa
    // `yoneticiler.items.map` uzerinde patliyordu ve hata "silme" ile
    // ilgisiz gorunuyordu (ilk kosumda sekiz test bu yuzden kirmiziydi).
    if (url.includes("/yoneticiler")) return json({ items: [] });
    if (url.includes("/api/tenants/t-1")) return json(DETAY);
    return json({ items: [] });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

// DEPO `data-test` KULLANIR, `data-testid` DEGIL: `findByTestId` onu
// GORMEZ (P222'de de ayni tuzaga dustum, testler sebepsiz gibi gorunen
// "bulunamadi" hatasiyla kirmiziya dondu).
async function bul(ad: string): Promise<HTMLElement> {
  return (await waitFor(() => {
    const el = document.querySelector(`[data-test="${ad}"]`);
    if (!el) throw new Error(`oge yok: ${ad}`);
    return el as HTMLElement;
  })) as HTMLElement;
}

function belkiVar(ad: string): HTMLElement | null {
  return document.querySelector(`[data-test="${ad}"]`);
}

describe("P224 tesis silme paneli", () => {
  it("SILMEDEN ONCE ICERIK SAYILARI gosterilir", async () => {
    sahtele(OZET_TEMIZ);
    ciz(TenantDetayPage);
    const ozet = await bul("tesis-silme-ozeti");
    // Sayilar SUNUCUDAN: panelin kendi saymasi, iki yerde iki farkli
    // gercek uretmek olurdu.
    expect(within(ozet).getByText("3")).toBeInTheDocument();
    expect(within(ozet).getByText("12")).toBeInTheDocument();
    expect(within(ozet).getByText("41")).toBeInTheDocument();
  });

  it("ONAY TESISIN ADI — sabit kelime dugmeyi ACMAZ", async () => {
    sahtele(OZET_TEMIZ);
    ciz(TenantDetayPage);
    const alan = await bul("tesis-sil-onay");
    const dugme = belkiVar("tesis-sil-dugme")!;
    expect(dugme).toBeDisabled();

    // Eski onay kelimesi: artik HICBIR SEY ACMAZ.
    await userEvent.type(alan, "SİL");
    expect(dugme).toBeDisabled();
  });

  it("TESISIN ADI yazilinca dugme ACILIR", async () => {
    sahtele(OZET_TEMIZ);
    ciz(TenantDetayPage);
    const alan = await bul("tesis-sil-onay");
    await userEvent.type(alan, "Yönetio Platform");
    await waitFor(() =>
      expect(belkiVar("tesis-sil-dugme")!).toBeEnabled(),
    );
  });

  it("BUYUK/KUCUK HARF farki dugmeyi ACMAZ", async () => {
    // Sunucu da tolere etmiyor; panelin daha gevsek olmasi, kullaniciya
    // "kabul edildi" izlenimi verip 409 aldirirdi.
    sahtele(OZET_TEMIZ);
    ciz(TenantDetayPage);
    const alan = await bul("tesis-sil-onay");
    await userEvent.type(alan, "yönetio platform");
    expect(belkiVar("tesis-sil-dugme")!).toBeDisabled();
  });

  it("ONAY SUNUCUYA DA GONDERILIR (panel tek basina zorlamaz)", async () => {
    const cagrilar: Cagri[] = [];
    sahtele(OZET_TEMIZ, cagrilar);
    ciz(TenantDetayPage);
    const alan = await bul("tesis-sil-onay");
    await userEvent.type(alan, "Yönetio Platform");
    await userEvent.click(belkiVar("tesis-sil-dugme")!);

    await waitFor(() => {
      const sil = cagrilar.find((c) => c.metot === "DELETE");
      expect(sil, "DELETE cagrisi atilmadi").toBeTruthy();
      expect(sil!.url).toContain("onay=");
      expect(decodeURIComponent(sil!.url)).toContain("Yönetio Platform");
    });
  });

  it("GECMISI OLAN tesiste SILME DUGMESI YOK, ARSIVLE var", async () => {
    // Sunucu da reddediyor; dugmeyi gostermek kullaniciyi anlamsiz bir
    // 409'a surmekti.
    sahtele({ ...OZET_TEMIZ, sikayet: 7, dogrudan_silinebilir: false });
    ciz(TenantDetayPage);
    await bul("tesis-silme-ozeti");
    expect(belkiVar("tesis-sil-dugme")).toBeNull();
    expect(
      screen.getByRole("button", { name: "Arşivle" }),
    ).toBeInTheDocument();
  });

  it("PLATFORM ADMINI olan tesiste NE SILME NE ARSIVLE var", async () => {
    // Bugunku kazanin tam onlendigi yer.
    sahtele({
      ...OZET_TEMIZ,
      platform_admini_var: true,
      dogrudan_silinebilir: false,
    });
    ciz(TenantDetayPage);
    await bul("tesis-silme-ozeti");
    expect(belkiVar("tesis-sil-dugme")).toBeNull();
    expect(screen.queryByRole("button", { name: "Arşivle" })).toBeNull();
    expect(
      screen.getByText(/platform yöneticisi hesabı var/i),
    ).toBeInTheDocument();
  });

  it("ARSIVDEKI tesiste GERI GETIR gorunur", async () => {
    sahtele({ ...OZET_TEMIZ, arsivlendi_at: "2026-09-12T10:00:00Z" });
    ciz(TenantDetayPage);
    expect(
      await screen.findByRole("button", { name: "Arşivden geri getir" }),
    ).toBeInTheDocument();
  });
});
