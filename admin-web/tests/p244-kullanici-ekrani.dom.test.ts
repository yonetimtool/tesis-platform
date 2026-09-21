// @vitest-environment jsdom
//
// (P244 §9b) KULLANICI EKRANI — SERIT SAYILARI ve SUZGEC CUBUGU.
//
// ===========================================================================
// IKI IDDIA
// ===========================================================================
// 1. SAYAÇLAR AYRI SORGULARDAN. Kullanici listesi hem SAYFALI (25'lik)
//    hem SUZGECLI. Gorunen sayfadan saymak "12 aktif hesap" gibi
//    yanlis bir sayi uretirdi; ustelik rol suzgeci acikken sayac da
//    suzulurdu ("Sakin: 0" — oysa sakin var, yalnizca listede yok).
//
// 2. SUZGECLER HATA HALINDE DE DURUYOR. Suzgecler tablonun `araclar`
//    yuvasindaydi; tablo hata alinca "tekrar dene" cizer ve suzgecler
//    ONUNLA BIRLIKTE KAYBOLURDU — oysa kullanicinin ilk refleksi
//    suzgeci degistirip tekrar denemektir. `FiltreCubugu` tablonun
//    DISINDA ve hatadan etkilenmiyor.
//
// (2) bu turda KENDI ELIMLE uretebilecegim bir gerilemeydi: suzgecleri
// cubuga tasirken tablonun icinde birakmak da mumkundu.
import { screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import UsersPage from "@/app/(protected)/users/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/users",
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.restoreAllMocks());

function kur(opts: { hataliListe?: boolean } = {}) {
  fetchSahtele({
    "/api/units": { meta: { total: 0 }, items: [] },
    "/api/users": opts.hataliListe
      ? { __durum: 500, error: { message: "sunucu hatasi" } }
      : { meta: { limit: 25, offset: 0, total: 0 }, items: [] },
  });
}

describe("(P244 §9b) kullanicilar — serit sayaclari", () => {
  it("AKTIF / SAKIN / PASIF sayaclari AYRI sorulur", async () => {
    kur();
    ciz(UsersPage);
    await screen.findByRole("combobox", { name: "Rol" });
    const urller = cagrilanUrller();
    expect(
      urller.some((u) => u.includes("is_active=true") && u.includes("limit=1")),
      "aktif sayaci ayri sorulmuyor",
    ).toBe(true);
    expect(
      urller.some((u) => u.includes("is_active=false") && u.includes("limit=1")),
      "pasif sayaci ayri sorulmuyor",
    ).toBe(true);
    expect(
      urller.some((u) => u.includes("role=resident") && u.includes("limit=1")),
      "sakin sayaci ayri sorulmuyor",
    ).toBe(true);
  });
});

describe("(P244 §9b) kullanicilar — suzgecler hatadan bagimsiz", () => {
  it("LISTE DUSSE BILE rol/durum/arama EKRANDA KALIR", async () => {
    // Suzgecler tablonun `araclar` yuvasinda kalsaydi, tablo hata
    // durumuna gecince hepsi birden kaybolurdu.
    kur({ hataliListe: true });
    ciz(UsersPage);
    expect(await screen.findByRole("combobox", { name: "Rol" })).toBeInTheDocument();
    expect(screen.getByRole("combobox", { name: "Durum" })).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: /ara/i })).toBeInTheDocument();
  });

  it("SUZGEC CUBUGU tablonun DISINDA (yapisal iddia)", async () => {
    kur();
    ciz(UsersPage);
    const rol = await screen.findByRole("combobox", { name: "Rol" });
    expect(rol.closest("table"), "suzgec tablonun icinde").toBeNull();
  });
});
