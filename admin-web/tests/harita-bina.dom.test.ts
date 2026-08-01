// @vitest-environment jsdom
// (P61) HATA VARKEN "YOK" DENMEZ — harita ve bina duzenleme.
//
// Uc sayfa bos-durum metnini yalniz `!isLoading` ile kosullamisti:
// istek dustugunde `isLoading` false olur, liste bostur ve sayfa hem
// hatayi hem "kayit yok"u gosterirdi. Haritada celiski daha da actikti:
// baslikta haritadan gelen "3 acik sikayet" yazarken altta "Acik
// sikayet yok".
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import SchematicPage from "@/app/(protected)/schematic/page";

import { ciz, fetchSahtele } from "./yardimci";

const DAIRE = {
  unit_id: "u1", unit_no: "A-12", blok: "A", kat: 1, sira: 2,
  complaint_count: 3, color: "kirmizi",
};
const HARITA = {
  shows_density: true,
  bloklar: [{ blok: "A", katlar: [{ kat: 1, units: [DAIRE] }] }],
  unplaced: [],
};

afterEach(() => vi.restoreAllMocks());

describe("Şikayet haritası", () => {
  it("sikayet listesi DUSTUGUNDE 'acik sikayet yok' YAZILMAZ", async () => {
    // Harita gelir, daire detayindaki sikayet listesi DUSER.
    fetchSahtele({ "/api/building-map": HARITA });
    ciz(SchematicPage);
    await waitFor(() => expect(screen.getByText(/A-12/)).toBeInTheDocument());
    await userEvent.click(screen.getByText(/A-12/));

    await waitFor(() =>
      expect(screen.getByText(/yüklenemedi/i)).toBeInTheDocument(),
    );
    // Baslikta "3 acik sikayet" varken altta "yok" demek CELISKIYDI.
    expect(screen.queryByText(/Açık şikayet yok/i)).not.toBeInTheDocument();
  });

  it("GERCEKTEN bos listede 'acik sikayet yok' YAZILIR", async () => {
    fetchSahtele({
      "/api/building-map": HARITA,
      "/api/unit-complaints": { meta: { limit: 20, offset: 0, total: 0 }, items: [] },
    });
    ciz(SchematicPage);
    await waitFor(() => expect(screen.getByText(/A-12/)).toBeInTheDocument());
    await userEvent.click(screen.getByText(/A-12/));
    await waitFor(() =>
      expect(screen.getByText(/Açık şikayet yok/i)).toBeInTheDocument(),
    );
  });
});
