// @vitest-environment jsdom
// (P160 / Asama 6) TASIMA GERILEMESI — Kullanicilar ve Daireler.
//
// KILITLI KURAL 2: "HICBIR MEVCUT OZELLIK KAYBOLMAYACAK."
//
// Tasima sirasinda en kolay kaybolan sey GORUNEN bir sey degil, bir
// DAVRANISTIR: bir suzgecin istegi degistirmemesi, bir dugmenin artik
// dogru ucu cagirmamasi, sayfalamanin sifirlanmamasi. Bu dosya o
// davranislari olcer — gorunumu degil.
//
// Yeni kazanimlar da kilitleniyor (skeleton, modal, sayfa basina kayit):
// bir sonraki tur onlari yanlislikla geri almasin.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import UnitsPage from "@/app/(protected)/units/page";
import UsersPage from "@/app/(protected)/users/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/users",
  useSearchParams: () => new URLSearchParams(),
}));

const KULLANICI = {
  id: "u1",
  ad: "Ayse Yilmaz",
  email: "ayse@ornek.com",
  role: "yonetici",
  is_active: true,
  aranabilir: true,
};

const DAIRE = {
  id: "d1",
  no: "A-12",
  blok: "A",
  unit_tip_ad: "2+1",
  kat: 3,
  sira: 2,
  metrekare: 110,
  aktif: true,
};

/** Cagrilan URL'leri kaydeden sahte `fetch`. */
function sahte(items: unknown[], toplam = 1) {
  const cagrilar: string[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push(`${init?.method ?? "GET"} ${url}`);
    if (url.includes("acilabilir-roller")) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ roller: ["yonetici", "security", "denetci"] }),
      } as Response;
    }
    if (url.includes("/api/blocks") || url.includes("/api/unit-tipleri")) {
      return { ok: true, status: 200, json: async () => ({ items: [] }) } as Response;
    }
    return {
      ok: true,
      status: 200,
      json: async () => ({ meta: { limit: 25, offset: 0, total: toplam }, items }),
    } as Response;
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) Kullanicilar — tasima sonrasi", () => {
  it("liste cizilir ve rol/durum ROZET olarak gorunur", async () => {
    sahte([KULLANICI]);
    ciz(UsersPage);
    await waitFor(() => expect(screen.getByText("Ayse Yilmaz")).toBeInTheDocument());
    // "Yönetici" hem rol SUZGECI seceneginde hem satir rozetinde geciyor.
    expect(screen.getAllByText("Yönetici").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Aktif").length).toBeGreaterThan(0);
  });

  it("SUZGEC degisince istek YENI parametreyle gider", async () => {
    const cagrilar = sahte([KULLANICI]);
    ciz(UsersPage);
    await waitFor(() => expect(screen.getByText("Ayse Yilmaz")).toBeInTheDocument());

    await userEvent.selectOptions(
      screen.getByLabelText("Durum"),
      "false",
    );
    await waitFor(() =>
      expect(cagrilar.some((c) => c.includes("is_active=false"))).toBe(true),
    );
  });

  it("SAYFA BASINA KAYIT secimi ISTEGE yansir (yeni kazanim)", async () => {
    const cagrilar = sahte([KULLANICI], 300);
    ciz(UsersPage);
    await waitFor(() => expect(screen.getByText("Ayse Yilmaz")).toBeInTheDocument());

    // Sayfa boyu secimi `Sayfa başına` etiketli `select` (VeriTablosu).
    await userEvent.selectOptions(
      screen.getByLabelText(/Sayfa başına/),
      "100",
    );
    await waitFor(() =>
      expect(cagrilar.some((c) => c.includes("limit=100"))).toBe(true),
    );
  });

  it("form MODALDA acilir (sayfa ustunde alan degil)", async () => {
    sahte([KULLANICI]);
    ciz(UsersPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni kullanıcı" }));
    const modal = await screen.findByRole("dialog");
    expect(within(modal).getByRole("button", { name: "Kaydet" })).toBeInTheDocument();
  });

  it("ESC modali kapatir", async () => {
    sahte([KULLANICI]);
    ciz(UsersPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni kullanıcı" }));
    await screen.findByRole("dialog");
    await userEvent.keyboard("{Escape}");
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  });

  it("TOPLU YUKLEME bagi KORUNDU (ice aktarim catisina)", async () => {
    sahte([KULLANICI]);
    ciz(UsersPage);
    const bag = await screen.findByRole("link", { name: /toplu/i });
    expect(bag).toHaveAttribute("href", "/ice-aktarim?tur=kisi");
  });

  it("UC DUSTUGUNDE hata + TEKRAR DENE cikar, bos liste gosterilmez", async () => {
    globalThis.fetch = (async () =>
      ({ ok: false, status: 500, json: async () => ({ error: { message: "sunucu" } }) }) as Response) as typeof fetch;
    ciz(UsersPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
    expect(screen.queryByText("Kullanıcı yok.")).toBeNull();
  });
});

/* ==================================================================== */

describe("(P160) Daireler — tasima sonrasi", () => {
  it("liste cizilir; DAIRE TIPI sutunu korunur (P26 duzeltmesi)", async () => {
    sahte([DAIRE]);
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    // Tip sutunu tasima sirasinda dusurulmesi en kolay sutundu.
    expect(screen.getByText("2+1")).toBeInTheDocument();
  });

  it("SATIR SECIMI ve toplu islem seridi calisir", async () => {
    sahte([DAIRE]);
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("checkbox", { name: "Satırı seç" }));
    expect(screen.getByText("1 kayıt seçili")).toBeInTheDocument();
    // Toplu degistirme dugmesi ancak SECIM VARKEN cikar.
    expect(
      screen.getByRole("button", { name: /Seçilenleri değiştir|1/ }),
    ).toBeInTheDocument();
  });

  it("HEPSINI SEC gorunen sayfayi secer", async () => {
    sahte([DAIRE]);
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("checkbox", { name: "Tümünü seç" }));
    expect(screen.getByText("1 kayıt seçili")).toBeInTheDocument();
  });

  it("(P163 §4) YAPISAL ARACLAR BU SAYFADAN KALKTI — KAYBOLMADI, TASINDI", async () => {
    // Testin ASIL NIYETI "arac kaybolmasin"di ve o niyet KORUNUYOR:
    // araclar artik BINA DUZENLEME ekraninda ve orada
    // `bina-yapisal-araclar.dom.test.ts` ile olculuyor.
    //
    // Burada olculen sey, tasimanin GERCEKTEN yapildigi: bu sayfa bir
    // liste/CRUD yuzeyi olarak kaldi. Iki yerde birden durursa hangisinin
    // gecerli oldugu belirsizlesir.
    sahte([DAIRE]);
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    expect(screen.queryByRole("button", { name: "Seç" })).toBeNull();
    expect(screen.queryByRole("button", { name: "Toplu daire oluştur" })).toBeNull();
    // (P165 §2) "YENI DAIRE" DE KALKTI: daire ekleme tek yerde (bina
    // duzenleme). Iki giris noktasi "hangisi dogru" sorusunu birakiyordu.
    expect(screen.queryByRole("button", { name: "Yeni daire" })).toBeNull();
    // AMA CIKMAZ YOK: bina duzenlemeye goturen bag DURUYOR.
    expect(screen.getByRole("link", { name: "Bina düzenleme" })).toBeInTheDocument();
    // DUZENLEME KORUNDU — kaldirilan sey OLUSTURMA girisi.
    expect(screen.getByRole("button", { name: "Düzenle" })).toBeInTheDocument();
  });

  // KAT SIL testi KALDIRILDI: dugme bu sayfada yok artik. Yikici islem
  // korumasi (blok secilmeden silinemez) yeni yerinde olculuyor.

  it("UC DUSTUGUNDE hata + TEKRAR DENE cikar", async () => {
    globalThis.fetch = (async () =>
      ({ ok: false, status: 500, json: async () => ({ error: { message: "sunucu" } }) }) as Response) as typeof fetch;
    ciz(UnitsPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
  });
});
