// @vitest-environment jsdom
// (P43) Yetki matrisi sayfasi — P41'in UC AYRIMI cizimde de duruyor mu?
//
// Backend testi (`test_yetki_matrisi.py`) ucun DOGRU VERIYI urettigini
// olcer. Bu test, o verinin EKRANDA dogru anlatildigini olcer: `roller:
// null` ile "hicbir rol izinli degil" AYNI GORUNURSE, kullanici kimliksiz
// erisilebilir bir uc varmis gibi okur.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import YetkiPage from "@/app/(protected)/yetki/page";

import { ciz, fetchSahtele } from "./yardimci";

const MATRIS = {
  roller: ["admin", "yonetici", "security", "tesis_gorevlisi", "resident", "guvenlik_amiri"],
  items: [
    { metot: "GET", yol: "/health", roller: null, moda_bagli: false },
    { metot: "POST", yol: "/shifts", roller: ["admin", "yonetici", "guvenlik_amiri"], moda_bagli: true },
    { metot: "GET", yol: "/portal", roller: ["admin", "yonetici"], moda_bagli: false },
  ],
};

afterEach(() => vi.restoreAllMocks());

describe("Yetki matrisi sayfasi", () => {
  it("sutunlar SUNUCUDAN gelir — sayfa rol listesi TASIMAZ", async () => {
    fetchSahtele({ "/api/panel/yetki-matrisi": MATRIS });
    ciz(YetkiPage);
    await waitFor(() => expect(screen.getByText("Güv. amiri")).toBeInTheDocument());
    // Alti sutun + Metot + Yol.
    expect(screen.getAllByRole("columnheader")).toHaveLength(8);
  });

  it("`roller: null` AYRI ROZET — 'izin yok' ile karistirilmaz", async () => {
    fetchSahtele({ "/api/panel/yetki-matrisi": MATRIS });
    ciz(YetkiPage);
    await waitFor(() => expect(screen.getByText("/health")).toBeInTheDocument());

    const satir = screen.getByText("/health").closest("tr");
    expect(satir).not.toBeNull();
    // Alti rol sutununun HEPSI "?" (rol kapisi yok) — "—" (izin yok) DEGIL.
    const hucreler = satir!.querySelectorAll("td");
    const isaretler = Array.from(hucreler).slice(2).map((h) => h.textContent);
    expect(isaretler).toEqual(["?", "?", "?", "?", "?", "?"]);
  });

  it("MODA BAGLI uc isaretlenir (P35)", async () => {
    fetchSahtele({ "/api/panel/yetki-matrisi": MATRIS });
    ciz(YetkiPage);
    await waitFor(() => expect(screen.getByText("/shifts")).toBeInTheDocument());
    const satir = screen.getByText("/shifts").closest("tr");
    expect(satir!.textContent).toContain("(mod)");
    // Moda bagli OLMAYAN satirda isaret YOK.
    expect(screen.getByText("/portal").closest("tr")!.textContent).not.toContain("(mod)");
  });

  it("arama YOL uzerinde suzer", async () => {
    fetchSahtele({ "/api/panel/yetki-matrisi": MATRIS });
    ciz(YetkiPage);
    await waitFor(() => expect(screen.getByText("/shifts")).toBeInTheDocument());

    await userEvent.type(screen.getByPlaceholderText("Yol ara"), "portal");
    expect(screen.getByText("/portal")).toBeInTheDocument();
    expect(screen.queryByText("/shifts")).not.toBeInTheDocument();
  });

  it("uc dustugunde HATA gorunur", async () => {
    fetchSahtele({});
    ciz(YetkiPage);
    await waitFor(() =>
      expect(screen.getByText("Yetki matrisi alınamadı.")).toBeInTheDocument(),
    );
  });
});
