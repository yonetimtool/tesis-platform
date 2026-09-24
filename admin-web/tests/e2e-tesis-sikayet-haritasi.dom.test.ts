// @vitest-environment jsdom
// (E2E 2026-09) TESIS-17 + TESIS-20 — sikayet haritasi.
//
// TESIS-20: lejant "0–2 / 3–4 / 5+ (kirmizi)" diyordu; backend P24'ten beri
// DORT kademe (0 yesil, 1–2 sari, 3–4 kirmizi, 5+ mor) uretiyor ve "mor"
// tipte YOKTU — 5+ sikayetli daire haritada YESIL ciziliyordu. Daire
// detayinda `goruntu_kirliligi` ham anahtar olarak yaziliyordu.
// TESIS-17: tur secicisi yoktu; secim artik `?kategori=` ile sunucuya gider.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import SchematicPage from "@/app/(protected)/schematic/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

const MOR = {
  unit_id: "u1", unit_no: "A-12", blok: "A", kat: 1, sira: 1,
  complaint_count: 6, color: "mor",
};
const HARITA = {
  shows_density: true,
  bloklar: [{ blok: "A", katlar: [{ kat: 1, units: [MOR] }] }],
  unplaced: [],
};

afterEach(() => vi.restoreAllMocks());

describe("Şikayet haritası (E2E 2026-09)", () => {
  it("lejant DORT kademeyi backend esikleriyle yazar", async () => {
    fetchSahtele({ "/api/building-map": HARITA });
    ciz(SchematicPage);
    await waitFor(() => expect(screen.getByText("5+ (mor)")).toBeInTheDocument());
    expect(screen.getByText("0 (yeşil)")).toBeInTheDocument();
    expect(screen.getByText("1–2 (sarı)")).toBeInTheDocument();
    expect(screen.getByText("3–4 (kırmızı)")).toBeInTheDocument();
    expect(screen.queryByText("0–2 (yeşil)")).not.toBeInTheDocument();
  });

  it("mor daire 'yogun daire' sayilir", async () => {
    fetchSahtele({ "/api/building-map": HARITA });
    ciz(SchematicPage);
    await waitFor(() => expect(screen.getByText(/A-12/)).toBeInTheDocument());
    expect(screen.getByText("3+ açık şikayet (kırmızı/mor)")).toBeInTheDocument();
  });

  it("goruntu_kirliligi ham anahtar olarak YAZILMAZ", async () => {
    fetchSahtele({
      "/api/building-map": HARITA,
      "/api/unit-complaints": {
        meta: { limit: 200, offset: 0, total: 1 },
        items: [{
          id: "c1", target_unit_id: "u1", unit_no: "A-12",
          kategori: "goruntu_kirliligi", durum: "acik",
          created_at: "2026-09-20T08:00:00Z",
        }],
      },
    });
    ciz(SchematicPage);
    await waitFor(() => expect(screen.getByText(/A-12/)).toBeInTheDocument());
    await userEvent.click(screen.getAllByText(/A-12/)[0]);
    // Tur secicisinin <option>'i da ayni metni tasir — detay satiri ayrilir.
    await waitFor(() =>
      expect(
        screen
          .getAllByText("Görüntü kirliliği")
          .filter((e) => e.tagName !== "OPTION"),
      ).toHaveLength(1),
    );
    expect(screen.queryByText("goruntu_kirliligi")).not.toBeInTheDocument();
  });

  it("tur secimi sunucuya ?kategori= olarak gider", async () => {
    fetchSahtele({ "/api/building-map": HARITA });
    ciz(SchematicPage);
    await waitFor(() => expect(screen.getByText(/A-12/)).toBeInTheDocument());
    const secim = document.querySelector(
      '[data-test="harita-tur-suzgeci"]',
    ) as HTMLSelectElement;
    expect(secim).not.toBeNull();
    await userEvent.selectOptions(secim, "gurultu");
    await waitFor(() =>
      expect(cagrilanUrller()).toContain("/api/building-map?kategori=gurultu"),
    );
  });
});
