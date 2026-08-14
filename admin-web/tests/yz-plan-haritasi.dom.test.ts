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

/* ==================================================================== */
/* OKUTMA KATMANI — "olcum, yargi degil"                                */
/* ==================================================================== */

describe("(P160) Okutma katmani", () => {
  const NOKTA = {
    id: "c1",
    ad: "A blok giris",
    nfc_tag_uid: "01",
    gps_lat: 41.0082,
    gps_lng: 28.9784,
    aktif: true,
  };

  /** ~50 m kuzeyde bir okutma (enlemde 0.00045 derece ≈ 50 m). */
  const OKUTMA_KONUMLU = {
    id: "s1",
    checkpoint_id: "c1",
    checkpoint_ad: "A blok giris",
    guard_id: "g1",
    guard_ad: "Ali Veli",
    okutma_zamani: "2026-08-14T23:10:00Z",
    gps_lat: 41.00865,
    gps_lng: 28.9784,
    konum_durumu: "var",
    gps_dogruluk_m: 12,
  };
  /** Konumu OLMAYAN okutma — haritaya giremez. */
  const OKUTMA_KONUMSUZ = {
    id: "s2",
    checkpoint_id: "c1",
    checkpoint_ad: "A blok giris",
    guard_id: "g1",
    guard_ad: "Ali Veli",
    okutma_zamani: "2026-08-14T23:40:00Z",
    gps_lat: null,
    gps_lng: null,
    konum_durumu: "izin_yok",
    gps_dogruluk_m: null,
  };

  function katmanSahtele(okutmalar: unknown[]) {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      const yanit = (govde: unknown) =>
        ({ ok: true, status: 200, json: async () => govde }) as Response;
      if (url.includes("/api/scans")) {
        return yanit({ tarih: "2026-08-14", konumsuz_sayisi: 0, items: okutmalar });
      }
      if (url.includes("/api/dashboard/live")) {
        return yanit({ generated_at: "x", aktif_turlar: [], alarm_gruplari: [] });
      }
      return yanit({ meta: { limit: 25, offset: 0, total: 1 }, items: [NOKTA] });
    }) as typeof fetch;
  }

  it("KATMAN ANAHTARI var ve VARSAYILAN ACIK", async () => {
    katmanSahtele([OKUTMA_KONUMLU]);
    ciz(CheckpointsPage);
    const dugme = await screen.findByRole("button", { name: "Okutmaları göster" });
    expect(dugme).toHaveAttribute("aria-pressed", "true");
  });

  it("KATMAN KAPATILABILIR", async () => {
    katmanSahtele([OKUTMA_KONUMLU]);
    ciz(CheckpointsPage);
    const dugme = await screen.findByRole("button", { name: "Okutmaları göster" });
    await userEvent.click(dugme);
    expect(dugme).toHaveAttribute("aria-pressed", "false");
  });

  it("KONUMSUZ okutma sessiz gecilmez — sayilir", async () => {
    katmanSahtele([OKUTMA_KONUMLU, OKUTMA_KONUMSUZ]);
    ciz(CheckpointsPage);
    // `izin_yok` konumu olmayan bir okutmadir; haritaya konamaz.
    await waitFor(() =>
      expect(screen.getByText(/1 okutmanın konumu yok/)).toBeInTheDocument(),
    );
  });

  it("HIC KONUMLU OKUTMA YOKSA bunu SOYLER", async () => {
    katmanSahtele([OKUTMA_KONUMSUZ]);
    ciz(CheckpointsPage);
    await waitFor(() =>
      expect(screen.getByText("Bugün konumu olan okutma yok.")).toBeInTheDocument(),
    );
  });

  it("KATMAN KAPALIYKEN konumsuz uyarisi da CIKMAZ (gurultu yok)", async () => {
    katmanSahtele([OKUTMA_KONUMLU, OKUTMA_KONUMSUZ]);
    ciz(CheckpointsPage);
    await waitFor(() =>
      expect(screen.getByText(/1 okutmanın konumu yok/)).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: "Okutmaları göster" }));
    expect(screen.queryByText(/1 okutmanın konumu yok/)).toBeNull();
  });
});

describe("(P160) mesafe OLCUMDUR, yargi DEGIL", () => {
  it("haversine bilinen bir araligi dogru olcer", async () => {
    const { mesafeMetre } = await import("@/lib/mesafe");
    // Enlemde 0.00045 derece ≈ 50 m (1 derece ≈ 111,32 km).
    const m = mesafeMetre(41.0082, 28.9784, 41.00865, 28.9784);
    expect(m).toBeGreaterThan(45);
    expect(m).toBeLessThan(55);
  });

  it("ayni nokta icin sifir doner", async () => {
    const { mesafeMetre } = await import("@/lib/mesafe");
    expect(mesafeMetre(41.0082, 28.9784, 41.0082, 28.9784)).toBe(0);
  });

  it("esik metni SUCLAMA degil OLCUM dili kullanir", async () => {
    // Esik artik VAR (urun karari, tesis ayari). Ama metin hala bir
    // GOZLEM bildirir ("esik disi"), bir SUC atfetmez ("ihlal",
    // "supheli"): 60 m uzakta okutma yapmis bir gorevliyi panelin
    // suclamasi, olcumun tasiyabileceginden fazlasini iddia etmekti.
    const { SOZLUKLER } = await import("@/lib/i18n/sozluk");
    const metinler = Object.entries(SOZLUKLER.tr)
      .filter(
        ([k]) =>
          k.startsWith("haritaOkutma") ||
          k.startsWith("haritaEsik") ||
          k.startsWith("haritaOlcum"),
      )
      .map(([, v]) => String(v));
    expect(metinler.length).toBeGreaterThan(0);
    for (const metin of metinler) {
      expect(metin).not.toMatch(/şüpheli|ihlal|kural dışı|suç/i);
    }
  });
});

/* ==================================================================== */
/* ESIK — urun karari, tesis ayari                                      */
/* ==================================================================== */

describe("(P160) esik karari — 'belirsiz' UCUNCU sonuctur", () => {
  it("esigin ALTINDA -> icinde", async () => {
    const { esikSonucu } = await import("@/lib/mesafe");
    expect(esikSonucu(30, 50, 10)).toBe("icinde");
  });

  it("esigin USTUNDE -> disinda", async () => {
    const { esikSonucu } = await import("@/lib/mesafe");
    expect(esikSonucu(80, 50, 10)).toBe("disinda");
  });

  it("TAM esikte -> icinde (sinir DAHIL)", async () => {
    const { esikSonucu } = await import("@/lib/mesafe");
    expect(esikSonucu(50, 50, 10)).toBe("icinde");
  });

  it("GPS HATASI ESIKTEN BUYUKSE -> belirsiz, 'disinda' DEGIL", async () => {
    // EN ONEMLI KURAL: ±100 m hatayla olculmus 80 m'lik bir mesafenin
    // 50 m esigini gecip gecmedigi BILINEMEZ. Bunu "esik disi" saymak,
    // olcum hatasini ihlal diye raporlamak — yani birini yanlis
    // suclamakti.
    const { esikSonucu } = await import("@/lib/mesafe");
    expect(esikSonucu(80, 50, 100)).toBe("belirsiz");
    // Mesafe esigin altinda olsa bile karar VERILEMEZ.
    expect(esikSonucu(10, 50, 100)).toBe("belirsiz");
  });

  it("DOGRULUK BILINMIYORSA karsilastirma YAPILIR", async () => {
    // Eski istemci alani gondermiyor. Her okutmayi "belirsiz" saymak,
    // esigi tamamen ise yaramaz kilardi.
    const { esikSonucu } = await import("@/lib/mesafe");
    expect(esikSonucu(80, 50, null)).toBe("disinda");
    expect(esikSonucu(30, 50, undefined)).toBe("icinde");
  });
});

describe("(P160) esik AYARDAN gelir, sabit degil", () => {
  const NOKTA = {
    id: "c1",
    ad: "A blok giris",
    nfc_tag_uid: "01",
    gps_lat: 41.0082,
    gps_lng: 28.9784,
    aktif: true,
  };
  /** ~50 m kuzeyde, ±5 m dogrulukla. */
  const OKUTMA = {
    id: "s1",
    checkpoint_id: "c1",
    checkpoint_ad: "A blok giris",
    guard_id: "g1",
    guard_ad: "Ali Veli",
    okutma_zamani: "2026-08-14T23:10:00Z",
    gps_lat: 41.00865,
    gps_lng: 28.9784,
    konum_durumu: "var",
    gps_dogruluk_m: 5,
  };

  function esikSahtele(esik: number | undefined) {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      const yanit = (govde: unknown) =>
        ({ ok: true, status: 200, json: async () => govde }) as Response;
      if (url.includes("/api/tenant/settings")) {
        return yanit({
          tenant_id: "t1",
          ad: "Demo",
          slug: "demo",
          timezone: "Europe/Istanbul",
          kurulum_tamamlandi: true,
          okutma_mesafe_esigi_m: esik,
        });
      }
      if (url.includes("/api/scans")) {
        return yanit({ tarih: "2026-08-14", konumsuz_sayisi: 0, items: [OKUTMA] });
      }
      if (url.includes("/api/dashboard/live")) {
        return yanit({ generated_at: "x", aktif_turlar: [], alarm_gruplari: [] });
      }
      return yanit({ meta: { limit: 25, offset: 0, total: 1 }, items: [NOKTA] });
    }) as typeof fetch;
  }

  it("DAR esikte (10 m) ayni okutma ESIK DISI sayilir", async () => {
    esikSahtele(10);
    ciz(CheckpointsPage);
    await waitFor(() =>
      expect(screen.getByText(/1 okutma eşiğin \(10 m\) dışında/)).toBeInTheDocument(),
    );
  });

  it("GENIS esikte (200 m) ayni okutma ESIK ICINDE — uyari YOK", async () => {
    esikSahtele(200);
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("A blok giris")).toBeInTheDocument());
    expect(screen.queryByText(/eşiğin .* dışında/)).toBeNull();
  });

  it("AYAR HENUZ GELMEMISKEN semadaki varsayilan (50) kullanilir", async () => {
    // ~50 m'lik okutma, 50 m esikte SINIR DAHIL -> icinde.
    esikSahtele(undefined);
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("A blok giris")).toBeInTheDocument());
    expect(screen.queryByText(/eşiğin .* dışında/)).toBeNull();
  });
});
