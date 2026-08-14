// @vitest-environment jsdom
// (P160) SIKAYET HARITASI — 2D plan gorunumu.
//
// =========================================================================
// BU DOSYANIN EN ONEMLI TESTI: "COGRAFI DEGIL" IDDIASI
// =========================================================================
// Sikayet kaydi bir DAIREYE baglidir ve koordinat TASIMAZ (`unit_complaint`
// ve `unit`/`block` tablolarinda `lat/lng` YOK). Yani cografi bir harita
// ancak konum uydurularak cizilebilirdi. Harita bu yuzden Leaflet'in
// `CRS.Simple` kipinde ve ekranda bunu YAZIYOR — testler o cumlenin ve
// "haritada olmayan daire" sayacinin kaybolmamasini kilitliyor.
//
// LEAFLET JSDOM'DA CIZILMEZ (canvas/olcum ister) ve zaten `next/dynamic`
// + `ssr:false` ile yukleniyor. Testler haritanin KENDISINI degil,
// haritanin YERINE GECMEDIGI erisilebilir yuzeyi ve harita etrafindaki
// dogruluk cumlelerini olcer.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import CheckpointsPage from "@/app/(protected)/checkpoints/page";
import SchematicPage from "@/app/(protected)/schematic/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/schematic",
  useSearchParams: () => new URLSearchParams(),
}));

const HARITA = {
  bloklar: [
    {
      blok: "A",
      katlar: [
        {
          kat: 1,
          units: [
            { unit_id: "u1", unit_no: "A-1", blok: "A", kat: 1, sira: 1, color: "kirmizi", complaint_count: 5 },
            // KAT/SIRA YOK: haritaya girmemeli.
            { unit_id: "u2", unit_no: "A-2", blok: "A", kat: null, sira: null, color: "yesil", complaint_count: 0 },
          ],
        },
      ],
    },
  ],
  unplaced: [
    { unit_id: "u3", unit_no: "B-9", blok: null, kat: null, sira: null, color: "yesil", complaint_count: 0 },
  ],
};

function sahtele() {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    if (String(girdi).includes("/api/unit-complaints")) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ meta: { limit: 20, offset: 0, total: 0 }, items: [] }),
      } as Response;
    }
    return { ok: true, status: 200, json: async () => HARITA } as Response;
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) Sikayet haritasi — sema ERISILEBILIR yuzey olarak KALIR", () => {
  it("VARSAYILAN gorunum SEMADIR (harita onun yerine gecmez)", async () => {
    sahtele();
    ciz(SchematicPage);
    const sema = await screen.findByRole("tab", { name: "Şema" });
    expect(sema).toHaveAttribute("aria-selected", "true");
  });

  it("sema hucreleri GERCEK DUGMEDIR — klavyeyle gezilir", async () => {
    sahtele();
    ciz(SchematicPage);
    // Tuval uzerindeki bir dikdortgen bunu veremezdi.
    const hucre = await screen.findByRole("button", { name: /A-1/ });
    expect(hucre).toHaveAttribute("aria-pressed", "false");
    await userEvent.click(hucre);
    expect(hucre).toHaveAttribute("aria-pressed", "true");
  });

  it("HARITA sekmesi var ve gecilebilir", async () => {
    sahtele();
    ciz(SchematicPage);
    const harita = await screen.findByRole("tab", { name: "Plan haritası" });
    await userEvent.click(harita);
    expect(harita).toHaveAttribute("aria-selected", "true");
  });
});

describe("(P160) Harita COGRAFI OLMADIGINI soyler", () => {
  it("plan notu ekranda yazar", async () => {
    sahtele();
    ciz(SchematicPage);
    await userEvent.click(await screen.findByRole("tab", { name: "Plan haritası" }));
    await waitFor(() =>
      expect(screen.getByText(/coğrafi harita değil/)).toBeInTheDocument(),
    );
  });

  it("HARITADA OLMAYAN DAIRE sessiz gecilmez — sayilir", async () => {
    sahtele();
    ciz(SchematicPage);
    await userEvent.click(await screen.findByRole("tab", { name: "Plan haritası" }));
    // `u2` (kat/sira yok) + `u3` (unplaced) = 2 daire haritada yok.
    await waitFor(() =>
      expect(screen.getByText(/2 dairenin kat\/sıra bilgisi/)).toBeInTheDocument(),
    );
  });

  it("EKSIK YOKSA uyari da YOK (gereksiz gurultu uretmez)", async () => {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      if (String(girdi).includes("/api/unit-complaints")) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ meta: { limit: 20, offset: 0, total: 0 }, items: [] }),
        } as Response;
      }
      return {
        ok: true,
        status: 200,
        json: async () => ({
          bloklar: [
            {
              blok: "A",
              katlar: [
                {
                  kat: 1,
                  units: [
                    { unit_id: "u1", unit_no: "A-1", blok: "A", kat: 1, sira: 1, color: "yesil", complaint_count: 0 },
                  ],
                },
              ],
            },
          ],
          unplaced: [],
        }),
      } as Response;
    }) as typeof fetch;

    ciz(SchematicPage);
    await userEvent.click(await screen.findByRole("tab", { name: "Plan haritası" }));
    await waitFor(() =>
      expect(screen.getByText(/coğrafi harita değil/)).toBeInTheDocument(),
    );
    expect(screen.queryByText(/kat\/sıra bilgisi/)).toBeNull();
  });
});

describe("(P160) Yerlesimsiz daireler SEMA gorunumunde ERISILIR KALIR", () => {
  it("kat/sira girilmemis daire semada listelenir", async () => {
    sahtele();
    ciz(SchematicPage);
    // Haritada yoklar ama kaybolmuyorlar: sema onlari ciziyor.
    await waitFor(() => expect(screen.getByText("B-9")).toBeInTheDocument());
    const hucre = screen.getByRole("button", { name: /A-2/ });
    expect(hucre).toBeInTheDocument();
  });

  it("SECIM her iki gorunumde de AYNI detay panelini acar", async () => {
    sahtele();
    ciz(SchematicPage);
    await userEvent.click(await screen.findByRole("button", { name: /A-1/ }));
    await waitFor(() =>
      expect(screen.getByText(/A-1 dairesi|Daire A-1/i)).toBeInTheDocument(),
    );
    // Gorunum degistirmek SECIMI kaybetmez.
    await userEvent.click(screen.getByRole("tab", { name: "Plan haritası" }));
    expect(screen.getByText(/A-1 dairesi|Daire A-1/i)).toBeInTheDocument();
  });
});

/* ==================================================================== */
/* NFC NOKTALARI — COGRAFI HARITA (public OSM karolari)                 */
/* ==================================================================== */

describe("(P160) NFC noktalari cografi haritasi", () => {
  const NOKTALAR = {
    meta: { limit: 25, offset: 0, total: 3 },
    items: [
      // Koordinati OLAN nokta -> haritada.
      { id: "c1", ad: "A blok giris", nfc_tag_uid: "01", gps_lat: 41.0082, gps_lng: 28.9784, aktif: true },
      // Koordinati OLMAYAN aktif nokta -> haritada DEGIL, akista VAR.
      { id: "c2", ad: "Otopark", nfc_tag_uid: "02", gps_lat: null, gps_lng: null, aktif: true },
      // PASIF nokta -> hicbir yerde durum iddia edilmez.
      { id: "c3", ad: "Kapali nokta", nfc_tag_uid: "03", gps_lat: 41.01, gps_lng: 28.98, aktif: false },
    ],
  };

  function noktaSahtele(items = NOKTALAR) {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      const yanit = (govde: unknown) =>
        ({ ok: true, status: 200, json: async () => govde }) as Response;
      if (url.includes("/api/scans")) {
        return yanit({ tarih: "2026-08-14", konumsuz_sayisi: 0, items: [] });
      }
      if (url.includes("/api/dashboard/live")) {
        return yanit({ generated_at: "x", aktif_turlar: [], alarm_gruplari: [] });
      }
      return yanit(items);
    }) as typeof fetch;
  }

  it("HARITA varsayilan gorunum ve AKIS sekmesi de var", async () => {
    noktaSahtele();
    ciz(CheckpointsPage);
    const harita = await screen.findByRole("tab", { name: "Harita" });
    expect(harita).toHaveAttribute("aria-selected", "true");
    expect(screen.getByRole("tab", { name: "Akış" })).toBeInTheDocument();
  });

  it("KOORDINATSIZ nokta sessiz gecilmez — sayilir", async () => {
    noktaSahtele();
    ciz(CheckpointsPage);
    // `c2` aktif ama koordinati yok: haritada olamaz, sayilir.
    await waitFor(() =>
      expect(screen.getByText(/1 noktanın koordinatı girilmediği/)).toBeInTheDocument(),
    );
  });

  it("KOORDINATSIZ nokta AKIS gorunumunde ve TABLODA kaybolmaz", async () => {
    noktaSahtele();
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("Otopark")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("tab", { name: "Akış" }));
    // Akis notu: sira yok, cizgi yok.
    expect(screen.getByText(/çizgi çizilmez/)).toBeInTheDocument();
  });

  it("HICBIRINDE KOORDINAT YOKSA bos dunya haritasi CIZILMEZ", async () => {
    noktaSahtele({
      meta: { limit: 25, offset: 0, total: 1 },
      items: [
        { id: "c9", ad: "Tek nokta", nfc_tag_uid: "09", gps_lat: null, gps_lng: null, aktif: true },
      ],
    });
    ciz(CheckpointsPage);
    // Ekrani dolduran ama hicbir sey soylemeyen bir harita yerine, NE
    // YAPILACAGINI soyleyen bir bos durum.
    await waitFor(() =>
      expect(screen.getByText("Hiçbir noktanın koordinatı girilmemiş")).toBeInTheDocument(),
    );
    expect(screen.getByText(/GPS enlem\/boylam girin/)).toBeInTheDocument();
  });

  it("PASIF nokta koordinati olsa da haritaya GIRMEZ", async () => {
    noktaSahtele();
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("Kapali nokta")).toBeInTheDocument());
    // `c3` pasif: okutulmasi beklenmiyor, haritada durum iddia edilmez.
    // Koordinatsiz sayaci yalniz `c2`yi sayar (1), `c3`u DEGIL.
    expect(screen.getByText(/1 noktanın koordinatı girilmediği/)).toBeInTheDocument();
  });
});
