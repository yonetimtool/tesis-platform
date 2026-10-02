// @vitest-environment jsdom
// (P252 §3) PERSONEL DETAYI ve kisinin gorunurlugu:
//   * detay: calisma bilgileri (kasa adiyla), bu ay vardiya/devriye, bu
//     yil odenen, odeme gecmisi (donem, tutar, kasa, tur, durum);
//   * `?kisi=` hesapla, `?kart=` karttan ister;
//   * Kisiler › Personel satirinda ad detaya baglanir;
//   * rapor modalinda "Personel" suzgeci (katalog alani) cizilir;
//   * adres tek yerden (`personelDetayYolu`).
import { screen, waitFor, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import PersonelDetayPage from "@/app/(protected)/kisiler/personel/page";
import KullaniciListesi from "@/components/kisiler/kullanici-listesi";
import { ALAN_TANIMLARI } from "@/lib/rapor-alanlari";
import { personelDetayYolu, type PersonelDetay } from "@/lib/personel";
import { ROTA_ROLLERI } from "@/lib/yuzey";

import { ciz } from "./yardimci";

const nav = vi.hoisted(() => ({ sorgu: "" }));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/kisiler/personel",
  useSearchParams: () => new URLSearchParams(nav.sorgu),
}));

afterEach(() => vi.restoreAllMocks());

const DETAY: PersonelDetay = {
  kart_id: "k1",
  user_id: "u1",
  ad: "Ahmet YILMAZ",
  rol: "security",
  calisma: {
    giris_tarihi: "2026-09-01", cikis_tarihi: null, gorev: "Güvenlik",
    maas_kurus: 2_500_000, odeme_gunu: 5, kasa_id: "kasa1", kasa_ad: "Merkez Kasa",
    iban: null, notlar: null, aktif: true,
  },
  odemeler: [
    { id: "h2", tarih: "2026-10-05", donem: "2026-10", tutar_kurus: 2_500_000, tur: "maas", durum: "odendi", kasa_ad: "Merkez Kasa" },
    { id: "h1", tarih: "2026-09-30", donem: null, tutar_kurus: 225_000, tur: "mesai", durum: "onay_bekliyor", kasa_ad: "Merkez Kasa" },
  ],
  bu_ay: { vardiya_sayisi: 12, vardiya_saat: 144, devriye_tur: 30, okutma_sayisi: 240 },
  yil_odenen_kurus: 2_500_000,
};

function taklit(harita: Record<string, unknown>) {
  const istekler: string[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL) => {
    const url = String(g);
    istekler.push(url);
    const k = Object.keys(harita).filter((a) => url.startsWith(a)).sort((a, b) => b.length - a.length)[0];
    return new Response(JSON.stringify(k ? harita[k] : { items: [] }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return istekler;
}

describe("(P252 §3) Personel detayi", () => {
  it("calisma, bu ay, yil toplami ve odeme gecmisi", async () => {
    nav.sorgu = "kisi=u1";
    const istekler = taklit({ "/api/personel/detay": DETAY });
    ciz(PersonelDetayPage);
    expect(await screen.findByRole("heading", { level: 1, name: "Ahmet YILMAZ" })).toBeTruthy();
    expect(istekler).toContain("/api/personel/detay?user_id=u1");
    const calisma = document.querySelector('[data-test="pd-calisma"]') as HTMLElement;
    expect(calisma.textContent).toContain("25.000,00");
    expect(calisma.textContent).toContain("Her ayın 5. günü");
    expect(calisma.textContent).toContain("Merkez Kasa");
    expect(document.querySelector('[data-test="pd-vardiya"]')!.textContent).toBe("12 vardiya · 144 saat");
    expect(document.querySelector('[data-test="pd-devriye"]')!.textContent).toBe("30 devriye turu · 240 okutma");
    expect(document.querySelector('[data-test="pd-yil"]')!.textContent).toContain("25.000,00");
    const tablo = screen.getByRole("table");
    expect(within(tablo).getByText("2026-10")).toBeTruthy();
    expect(within(tablo).getByText("Maaş")).toBeTruthy();
    expect(within(tablo).getByText("Fazla mesai")).toBeTruthy();
    expect(within(tablo).getByText("Onay bekliyor")).toBeTruthy();
  });

  it("kart kimligiyle (hesapsiz personel) karttan ister", async () => {
    nav.sorgu = "kart=k1";
    const istekler = taklit({ "/api/personel/detay": { ...DETAY, user_id: null } });
    ciz(PersonelDetayPage);
    await screen.findByRole("heading", { level: 1, name: "Ahmet YILMAZ" });
    expect(istekler).toContain("/api/personel/detay?kart_id=k1");
  });

  it("adres tek yerden; rota yalniz yonetime", () => {
    expect(personelDetayYolu({ kisi: "u1" })).toBe("/kisiler/personel?kisi=u1");
    expect(personelDetayYolu({ kart: "k1" })).toBe("/kisiler/personel?kart=k1");
    expect(ROTA_ROLLERI["/kisiler/personel"]).toEqual(["admin", "yonetici"]);
  });

  it("Kisiler › Personel satirinda AD detaya baglanir", async () => {
    nav.sorgu = "";
    taklit({
      "/api/users/acilabilir-roller": { roller: ["security"] },
      "/api/users": {
        meta: { total: 1, limit: 50, offset: 0 },
        items: [{ id: "u1", ad: "Ahmet YILMAZ", email: "a@ornek.com", role: "security",
          is_active: true, created_at: "2026-01-01T00:00:00Z" }],
      },
    });
    ciz(() => KullaniciListesi({
      kapsam: ["security"],
      adBaglantisi: (u) => personelDetayYolu({ kisi: u.id }),
    }));
    await waitFor(() => expect(document.querySelector('[data-test="kisi-detay-u1"]')).toBeTruthy());
    expect(document.querySelector('[data-test="kisi-detay-u1"]')!.getAttribute("href"))
      .toBe("/kisiler/personel?kisi=u1");
  });

  it("rapor modalinda kisi suzgeci alani tanimli", () => {
    expect(ALAN_TANIMLARI.personel_kayit_id).toEqual({ tur: "personel", etiket: "raporPersonel" });
  });
});
