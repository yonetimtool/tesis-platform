// @vitest-environment jsdom
// (P160 / Asama 5) ROTA SAHNESI — durum turetme + bagli sayfalar.
//
// =========================================================================
// SAHNENIN KENDISI BURADA CIZILMEZ
// =========================================================================
// R3F/WebGL jsdom'da calismaz. Ama sahnenin TASIDIGI SEY zaten WebGL
// degil: hangi noktanin hangi durumda oldugu. O karar `lib/rota-durumu`
// dosyasinda ve sayfalarin listelerinde METIN olarak duruyor — testler
// oraya bakiyor.
//
// EN ONEMLI TEST sonunculardan biri: `/checkpoints` sayfasinda CIZGI
// CIZILMEZ. Oradaki noktalar bir plana bagli degil; aralarinda sira
// yok. Cizgi cizmek, olmayan bir devriye yolu gostermek olurdu.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import CheckpointsPage from "@/app/(protected)/checkpoints/page";
import PatrolPlansPage from "@/app/(protected)/patrol-plans/page";
import { alarmHaritasi, noktaDurumu } from "@/lib/rota-durumu";
import type { AlarmGrubu } from "@/lib/types";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/checkpoints",
  useSearchParams: () => new URLSearchParams(),
}));

// 3D sahne jsdom'da acilmaz; yukleyici zaten WebGL yoksa METIN ozete
// duser. Testler o ozeti ve sayfa listelerini olcer.
vi.mock("@/components/3d/sahne-yukleyici", async (asil) => {
  const gercek = await asil<Record<string, unknown>>();
  return gercek;
});

const NOKTALAR = {
  meta: { limit: 25, offset: 0, total: 3 },
  items: [
    { id: "c1", ad: "A blok giris", nfc_tag_uid: "01", gps_lat: null, gps_lng: null, aktif: true },
    { id: "c2", ad: "Otopark", nfc_tag_uid: "02", gps_lat: null, gps_lng: null, aktif: true },
    { id: "c3", ad: "Kapali nokta", nfc_tag_uid: "03", gps_lat: null, gps_lng: null, aktif: false },
  ],
};

const OKUTMALAR = {
  tarih: "2026-08-14",
  konumsuz_sayisi: 0,
  items: [
    {
      id: "s1",
      checkpoint_id: "c1",
      checkpoint_ad: "A blok giris",
      guard_id: "g1",
      guard_ad: "Ali",
      okutma_zamani: "2026-08-14T23:10:00Z",
      konum_durumu: "var",
    },
  ],
};

const PANO = {
  generated_at: "2026-08-14T23:30:00Z",
  aktif_turlar: [],
  alarm_gruplari: [
    {
      tip: "gecikmis_okutma",
      patrol_plan_ad: "Gece",
      mesaj: "gecikti",
      sayi: 1,
      en_son: "2026-08-14T23:20:00Z",
      onem: "orta",
      olaylar: [{ olusma_zamani: "2026-08-14T23:20:00Z", checkpoint_id: "c2" }],
    },
  ],
};

const PLANLAR = {
  meta: { limit: 25, offset: 0, total: 1 },
  items: [
    {
      id: "p1",
      ad: "Gece devriyesi",
      shift_id: null,
      baslangic_saat: "23:00",
      bitis_saat: "06:00",
      periyot_dakika: 60,
      aktif: true,
    },
  ],
};

function sahtele(opts: { atama?: string[] } = {}) {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const yanit = (govde: unknown) =>
      ({ ok: true, status: 200, json: async () => govde }) as Response;

    if (/\/api\/patrol-plans\/[^/]+\/checkpoints/.test(url)) {
      if ((init?.method ?? "GET") === "GET") {
        return yanit((opts.atama ?? ["c1", "c2"]).map((cid, i) => ({
          checkpoint_id: cid,
          sira: i,
        })));
      }
      return yanit({});
    }
    if (url.includes("/api/scans")) return yanit(OKUTMALAR);
    if (url.includes("/api/dashboard/live")) return yanit(PANO);
    if (url.includes("/api/patrol-plans")) return yanit(PLANLAR);
    if (url.includes("/api/checkpoints")) return yanit(NOKTALAR);
    return yanit({ meta: { limit: 25, offset: 0, total: 0 }, items: [] });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) nokta durumu — TEK TANIM, uydurma yok", () => {
  const kaynak = { okutulanIdler: new Set(["c1"]), alarmGruplari: [] as AlarmGrubu[] };

  it("okutulan nokta OKUTULDU", () => {
    expect(noktaDurumu("c1", kaynak, new Map())).toBe("okutuldu");
  });

  it("okutulmayan ve alarmsiz nokta BEKLIYOR — 'atlandi' UYDURULMAZ", () => {
    expect(noktaDurumu("c9", kaynak, new Map())).toBe("bekliyor");
  });

  it("`gecikmis_okutma` alarmi GECIKTI verir", () => {
    const h = alarmHaritasi(PANO.alarm_gruplari as unknown as AlarmGrubu[]);
    expect(noktaDurumu("c2", kaynak, h)).toBe("gecikti");
  });

  it("ALARM OKUTMAYI EZER: dun okutulmus ama bugun atlanmis nokta yesil GORUNMEZ", () => {
    const h = new Map([["c1", "eksik_checkpoint"]]);
    // `c1` taramada VAR ama sunucu "eksik" diyor -> agir olan kazanir.
    expect(noktaDurumu("c1", kaynak, h)).toBe("atlandi");
  });

  it("ayni nokta hem gecikti hem eksikse ATLANDI kazanir", () => {
    const gruplar = [
      { ...PANO.alarm_gruplari[0], olaylar: [{ olusma_zamani: "x", checkpoint_id: "c5" }] },
      {
        ...PANO.alarm_gruplari[0],
        tip: "eksik_checkpoint",
        olaylar: [{ olusma_zamani: "y", checkpoint_id: "c5" }],
      },
    ] as unknown as AlarmGrubu[];
    expect(alarmHaritasi(gruplar).get("c5")).toBe("eksik_checkpoint");
  });

  it("ILGISIZ alarm tipi haritaya GIRMEZ", () => {
    const gruplar = [
      {
        ...PANO.alarm_gruplari[0],
        tip: "kacirilan_tur",
        olaylar: [{ olusma_zamani: "z", checkpoint_id: "c7" }],
      },
    ] as unknown as AlarmGrubu[];
    expect(alarmHaritasi(gruplar).has("c7")).toBe(false);
  });
});

/* ==================================================================== */

describe("(P160) NFC Noktalari — okutma durumu sutunu", () => {
  it("bugun okutulan nokta METINLE isaretlenir", async () => {
    sahtele();
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("A blok giris")).toBeInTheDocument());
    // Renk tek tasiyici degil: rozet METIN tasiyor.
    expect(screen.getByText("Okutuldu")).toBeInTheDocument();
  });

  it("alarmi olan nokta GECIKTI der", async () => {
    sahtele();
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("Gecikti")).toBeInTheDocument());
  });

  it("PASIF nokta icin okutma durumu IDDIA EDILMEZ", async () => {
    sahtele();
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("Kapali nokta")).toBeInTheDocument());
    // Pasif noktanin okutulmasi beklenmez; "bekliyor" demek olmayan bir
    // eksigi varmis gibi gostermekti.
    const satirlar = screen.getAllByRole("row");
    const pasif = satirlar.find((r) => r.textContent?.includes("Kapali nokta"))!;
    expect(within(pasif).queryByText("Bekliyor")).toBeNull();
  });

  it("AKIS gorunumu sirasiz oldugunu yazar (cizgi yok)", async () => {
    sahtele();
    ciz(CheckpointsPage);
    // (P160) Sayfa artik iki sekmeli: VARSAYILAN "Harita" (cografi),
    // akis ise koordinati olmayan noktalari da tasiyan ikinci gorunum.
    await userEvent.click(await screen.findByRole("tab", { name: "Akış" }));
    await waitFor(() =>
      expect(screen.getByText(/rotaya bağlı olmadığı için çizgi çizilmez/)).toBeInTheDocument(),
    );
  });
});

/* ==================================================================== */

describe("(P160) Devriye Planlari — rota sahnesi", () => {
  it("plan acilinca noktalar SIRAYLA ve DURUMLARIYLA listelenir", async () => {
    sahtele();
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(within(cekmece).getByText("A blok giris")).toBeInTheDocument(),
    );
    expect(within(cekmece).getByText("Okutuldu")).toBeInTheDocument();
    expect(within(cekmece).getByText("Gecikti")).toBeInTheDocument();
  });

  it("SAHNE NOTU konum verisi olmadigini SOYLER (harita sanilmasin)", async () => {
    sahtele();
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(
        within(cekmece).getByText(/akış şeması|harita değil/),
      ).toBeInTheDocument(),
    );
  });

  it("NOKTASIZ planda sahne CIZILMEZ", async () => {
    sahtele({ atama: [] });
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(within(cekmece).getByText("Henüz nokta eklenmedi.")).toBeInTheDocument(),
    );
    // Bos bir egri, olmayan bir rotayi cizmek olurdu.
    expect(within(cekmece).queryByText(/akış şeması/)).toBeNull();
  });

  it("SAHNE VERISI cekmece ACILANA KADAR istenmez (bedava istek yok)", async () => {
    const cagrilan: string[] = [];
    sahtele();
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (g: RequestInfo | URL, i?: RequestInit) => {
      cagrilan.push(String(g));
      return onceki(g, i);
    }) as typeof fetch;

    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    expect(cagrilan.some((u) => u.includes("/api/scans"))).toBe(false);

    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    await waitFor(() =>
      expect(cagrilan.some((u) => u.includes("/api/scans"))).toBe(true),
    );
  });
});
