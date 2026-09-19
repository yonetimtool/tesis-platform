// @vitest-environment jsdom
// (P243 §6d/§6e) ILK GIRIS TURU + BAGLAM ICI YARDIM.
//
// =========================================================================
// OLCULEN SEY
// =========================================================================
// Brief: "(d) Yöneticiye 3-4 ekranlık kısa tanıtım. Atlanabilir, bir kez
// gösterilir, sonradan tekrar açılabilir. (e) Her ekranda soru işareti."
//
// "BIR KEZ" nerede tutuldugu bu turun asil karari: `localStorage`
// olsaydi ofiste turu atlayan yonetici evdeki bilgisayarda onu yeniden
// gorurdu. Isaret hesapta (`app_user.tur_goruldu_at`, goc 0148) ve bu
// dosya SUNUCUYA GIDILDIGINI olcer — pencerenin kapanmasini degil.
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import { EkranYardimi } from "@/components/EkranYardimi";
import { IlkGirisTuru } from "@/components/IlkGirisTuru";

import { ciz, fetchSahtele } from "./yardimci";

let yol = "/dashboard";
vi.mock("next/navigation", () => ({ usePathname: () => yol }));

afterEach(() => {
  vi.restoreAllMocks();
  yol = "/dashboard";
});

/** Sahte ucu kurar ve `fetch`i CASUSLAR — testin olctugu sey yazma
 *  istegidir, pencerenin kapanmasi degil. */
function kurProfil(profil: Record<string, unknown>) {
  fetchSahtele({ "/api/me": profil, "/api/me/tur-goruldu": profil });
  return vi.spyOn(globalThis, "fetch");
}

describe("(P243 §6d) ilk giris turu", () => {
  it("YENI YONETICIYE acilir ve DORT EKRAN gezilir", async () => {
    kurProfil({ role: "yonetici", tur_goruldu_at: null });
    ciz(IlkGirisTuru);
    expect(await screen.findByText(/Önce bloklar ve daireler/)).toBeInTheDocument();
    // Ilk ekranda "Geri" YOK: gidilecek bir yer yok.
    expect(screen.queryByRole("button", { name: /^Geri$/ })).toBeNull();
    for (const beklenen of [
      /Kişiler davetle girer/,
      /Aidat ve tahsilat/,
      /Takıldığınız yerde soru işareti/,
    ]) {
      await userEvent.click(screen.getByRole("button", { name: /^İleri$/ }));
      // BASLIGA bak, gövdeye degil: son ekranin basligi ile govdesi ayni
      // kelimeyi ("soru işareti") tasiyor ve `getByText` ikisini birden
      // bulup "multiple elements" ile duserdi.
      expect(screen.getByRole("heading", { name: beklenen })).toBeInTheDocument();
    }
    // Son ekranda "İleri" degil "Başlayalım".
    expect(screen.getByRole("button", { name: /Başlayalım/ })).toBeInTheDocument();
  });

  it("TURU GOREN kullaniciya BIR DAHA acilmaz", async () => {
    kurProfil({ role: "yonetici", tur_goruldu_at: "2026-09-01T10:00:00Z" });
    const { container } = ciz(IlkGirisTuru);
    // Beklemeyi zamanlama ile degil, cizimin BOS kalmasiyla olc.
    await new Promise((c) => setTimeout(c, 0));
    expect(container.textContent).not.toMatch(/Önce bloklar/);
  });

  it("SAKINE acilmaz (tur kurulumu anlatiyor)", async () => {
    kurProfil({ role: "resident", tur_goruldu_at: null });
    const { container } = ciz(IlkGirisTuru);
    await new Promise((c) => setTimeout(c, 0));
    expect(container.textContent).not.toMatch(/Önce bloklar/);
  });

  it("ATLAMAK da 'gordu'dur — SUNUCUYA yazilir", async () => {
    // Aksi hâlde "atla" dugmesi bir sonraki girisde HICBIR SEY yapmamis
    // olurdu: kullanici her girisde ayni pencereyle karsilasirdi.
    const cagri = kurProfil({ role: "yonetici", tur_goruldu_at: null });
    ciz(IlkGirisTuru);
    await userEvent.click(await screen.findByRole("button", { name: /Turu atla/ }));
    const yazma = cagri.mock.calls.find(
      ([url, secenek]) =>
        String(url).includes("/api/me/tur-goruldu") &&
        (secenek as RequestInit | undefined)?.method === "POST",
    );
    expect(yazma).toBeDefined();
  });

  it("SON EKRANDA 'Başlayalım' da ayni isareti yazar", async () => {
    const cagri = kurProfil({ role: "yonetici", tur_goruldu_at: null });
    ciz(IlkGirisTuru);
    await screen.findByText(/Önce bloklar/);
    for (let i = 0; i < 3; i += 1) {
      await userEvent.click(screen.getByRole("button", { name: /^İleri$/ }));
    }
    await userEvent.click(screen.getByRole("button", { name: /Başlayalım/ }));
    expect(
      cagri.mock.calls.some(([url]) => String(url).includes("/api/me/tur-goruldu")),
    ).toBe(true);
  });
});

describe("(P243 §6e) baglam ici yardim", () => {
  it("KAYDI OLAN ekranda dugme VAR ve metni gosterir", async () => {
    yol = "/kurulum";
    ciz(EkranYardimi);
    await userEvent.click(screen.getByTestId("ekran-yardimi"));
    expect(screen.getByText(/Başlamak için blok ve daire yeter/)).toBeInTheDocument();
  });

  it("KAYDI OLMAYAN ekranda dugme HIC CIZILMEZ", () => {
    // Acip "aciklama yazilmadi" demek, dugmenin hic olmamasindan
    // KOTUDUR: kullanici bir kez tiklar, bos cikar, bir daha tiklamaz.
    yol = "/kvkk-metinler";
    const { container } = ciz(EkranYardimi);
    expect(container.querySelector('[data-testid="ekran-yardimi"]')).toBeNull();
  });

  it("ALT SAYFA ust kaydi devralir, EN UZUN onek kazanir", async () => {
    yol = "/finans/butce";
    ciz(EkranYardimi);
    await userEvent.click(screen.getByTestId("ekran-yardimi"));
    expect(screen.getByText(/Tek defter/)).toBeInTheDocument();
  });
});
