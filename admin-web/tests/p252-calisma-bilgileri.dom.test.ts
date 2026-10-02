// @vitest-environment jsdom
// (P252 §1) CALISMA BILGILERI — tek form, tek kaynak.
//
//   * Personel eklerken ucret/odeme gunu/kasa AYNI istekte gider
//     (`POST /users` `calisma`); bos birakilirsa `calisma` hic gitmez.
//   * Ucret girilip gun secilmezse istek ATILMAZ (gunsuz ucret otomasyona
//     hic girmez).
//   * Sakin eklerken bolum cizilmez.
//   * Satirdaki pencere: bagli kart VARSA onu PATCH'ler; YOKSA hesabin
//     adi/e-postasi/telefonuyla BAGLI kart olusturur (ikinci kart yok).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { CalismaEylemi, calismaGovdesi, BOS_CALISMA } from "@/components/kisiler/calisma-bilgileri";
import KullaniciListesi from "@/components/kisiler/kullanici-listesi";
import type { UserRow } from "@/lib/types";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/kisiler",
  useSearchParams: () => new URLSearchParams(""),
}));

type Cagri = { url: string; method: string; body: unknown };
let cagrilar: Cagri[] = [];

function sahte(harita: Record<string, unknown>) {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const method = init?.method ?? "GET";
    cagrilar.push({ url, method, body: init?.body ? JSON.parse(String(init.body)) : undefined });
    const anahtar = Object.keys(harita)
      .filter((k) => {
        const [m, yol] = k.includes(" ") ? k.split(" ") : ["GET", k];
        return m === method && url.startsWith(yol);
      })
      .sort((a, b) => b.length - a.length)[0];
    const govde = anahtar ? harita[anahtar] : { error: { message: "yok" } };
    return new Response(JSON.stringify(govde), {
      status: anahtar ? 200 : 404,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

const BOS_LISTE = { meta: { total: 0, limit: 50, offset: 0 }, items: [] };
const KASALAR = { items: [{ id: "kasa1", ad: "Merkez Kasa", aktif: true }] };
const TEMEL = {
  "/api/users/acilabilir-roller": { roller: ["security", "tesis_gorevlisi", "resident"] },
  "/api/users": BOS_LISTE,
  "/api/tanimlar/kasalar": KASALAR,
  "POST /api/users": { id: "u9", personel_kayit_id: "k9" },
};

function Personel() {
  return KullaniciListesi({
    kapsam: ["security", "tesis_gorevlisi", "guvenlik_amiri"],
    calismaBolumu: true,
  });
}

async function formuDoldur() {
  await userEvent.click(await screen.findByRole("button", { name: "Yeni kullanıcı" }));
  await userEvent.type(screen.getByLabelText(/^Ad/), "Ahmet");
  await userEvent.type(screen.getByLabelText(/^Soyad/), "Yılmaz");
  await userEvent.type(screen.getByLabelText(/^E-posta/), "ahmet@ornek.com");
}

beforeEach(() => sahte(TEMEL));
afterEach(() => vi.restoreAllMocks());

describe("(P252 §1) Personel ekleme formu", () => {
  it("ucret + gun + kasa hesapla AYNI istekte gider", async () => {
    ciz(Personel);
    await formuDoldur();
    expect(screen.getByText("Çalışma bilgileri")).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText("Aylık ücret (₺, net)"), "25000");
    await userEvent.selectOptions(screen.getByLabelText(/^Ödeme günü/), "5");
    const kasa = screen.getByLabelText("Ödendiği kasa");
    await waitFor(() => expect(kasa.querySelectorAll("option").length).toBe(2));
    await userEvent.selectOptions(kasa, "kasa1");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(cagrilar.some((c) => c.method === "POST")).toBe(true));
    const post = cagrilar.find((c) => c.method === "POST" && c.url === "/api/users");
    expect((post?.body as { calisma: unknown }).calisma).toEqual({
      giris_tarihi: null,
      gorev: null,
      maas_kurus: 2_500_000,
      odeme_gunu: 5,
      kasa_id: "kasa1",
      iban: null,
      notlar: null,
    });
  });

  it("bos birakilirsa yalniz hesap: `calisma` GONDERILMEZ", async () => {
    ciz(Personel);
    await formuDoldur();
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(cagrilar.some((c) => c.method === "POST")).toBe(true));
    const post = cagrilar.find((c) => c.method === "POST");
    expect(post?.body).not.toHaveProperty("calisma");
  });

  it("ucret var gun yok: istek ATILMAZ, kural yazilir", async () => {
    ciz(Personel);
    await formuDoldur();
    await userEvent.type(screen.getByLabelText("Aylık ücret (₺, net)"), "25000");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    expect(await screen.findByText("Ücret girildiyse ödeme günü de seçilmeli.")).toBeInTheDocument();
    expect(cagrilar.some((c) => c.method === "POST")).toBe(false);
  });

  it("odeme gunu kurali formda YAZILI", async () => {
    ciz(Personel);
    await formuDoldur();
    expect(screen.getByText(/ayın son günü ödenir/)).toBeInTheDocument();
  });

  it("calismaGovdesi: gecersiz ucret ve IBAN reddedilir", () => {
    expect(calismaGovdesi(BOS_CALISMA)).toEqual({ govde: null, hata: null });
    expect(calismaGovdesi({ ...BOS_CALISMA, ucret: "abc", gun: "5" }).hata).toBe("calismaUcretGecersiz");
    expect(calismaGovdesi({ ...BOS_CALISMA, iban: "TR00 0000" }).hata).not.toBeNull();
  });
});

describe("(P252 §1) Satirdaki Calisma bilgileri penceresi", () => {
  const KISI: UserRow = {
    id: "u1", ad: "Ali Kaya", email: "ali@ornek.com", role: "security",
    is_active: true, created_at: "2026-01-01T00:00:00Z",
  };

  it("kart VARSA: alanlar dolar, kaydet PATCH (yeni kart yok)", async () => {
    sahte({
      "/api/tanimlar/kasalar": KASALAR,
      "/api/tanimlar/personel-kayitlari": {
        items: [{ id: "k1", giris_tarihi: "2026-09-01", gorev: "Güvenlik", maas_kurus: 2_500_000,
          odeme_gunu: 5, kasa_id: "kasa1", iban: null, notlar: null }],
      },
      "PATCH /api/tanimlar/personel-kayitlari/k1": { id: "k1" },
    });
    ciz(() => CalismaEylemi({ kullanici: KISI }));
    await userEvent.click(await screen.findByRole("button", { name: "Çalışma bilgileri" }));
    const ucret = await screen.findByLabelText("Aylık ücret (₺, net)");
    expect(ucret).toHaveValue("25.000,00");
    expect(cagrilar.some((c) => c.url.includes("app_user_id=u1"))).toBe(true);
    await userEvent.clear(ucret);
    await userEvent.type(ucret, "26000");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(cagrilar.some((c) => c.method === "PATCH")).toBe(true));
    expect(cagrilar.find((c) => c.method === "PATCH")?.body).toMatchObject({ maas_kurus: 2_600_000, odeme_gunu: 5 });
    expect(cagrilar.some((c) => c.method === "POST")).toBe(false);
  });

  it("kart YOKSA: hesabin bilgileriyle BAGLI kart olusturur", async () => {
    sahte({
      "/api/tanimlar/kasalar": KASALAR,
      "/api/tanimlar/personel-kayitlari": { items: [] },
      "/api/users/u1": { ...KISI, telefon: "+905321112233" },
      "POST /api/tanimlar/personel-kayitlari": { id: "k9" },
    });
    ciz(() => CalismaEylemi({ kullanici: KISI }));
    await userEvent.click(await screen.findByRole("button", { name: "Çalışma bilgileri" }));
    await userEvent.type(await screen.findByLabelText("Aylık ücret (₺, net)"), "20000");
    await userEvent.selectOptions(screen.getByLabelText(/^Ödeme günü/), "1");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(cagrilar.some((c) => c.method === "POST")).toBe(true));
    expect(cagrilar.find((c) => c.method === "POST")?.body).toMatchObject({
      ad: "Ali Kaya",
      email: "ali@ornek.com",
      telefon: "+905321112233",
      app_user_id: "u1",
      gorev: expect.any(String),
      maas_kurus: 2_000_000,
      odeme_gunu: 1,
    });
  });
});
