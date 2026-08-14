// @vitest-environment jsdom
// (P160 / Asama 6) KAMERALAR · SIKAYET HARITASI · DIS HIZMETLER.
//
// Bu grubun ortak riski GORSEL: uc sayfa da bilgiyi RENKLE tasiyor
// (yogunluk, oynatilamaz rozeti, esnaf turu). Tasima sirasinda en kolay
// kaybolan sey rengin YANINDAKI metin oluyor — o yuzden testler rengi
// degil, rengin yaninda duran METNI ve durumu olcuyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DisHizmetlerPage from "@/app/(protected)/dis-hizmetler/page";
import KameralarPage from "@/app/(protected)/kameralar/page";
import SchematicPage from "@/app/(protected)/schematic/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/kameralar",
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) Kameralar", () => {
  const KAMERALAR = {
    items: [
      {
        id: "k1",
        ad: "Ana kapi",
        konum: "Giris",
        tur: "hls",
        stream_url: "https://ornek/1.m3u8",
        restream_url: null,
        snapshot_url: "https://ornek/1.jpg",
        sakin_gorebilir: true,
        aktif: true,
        oynatilabilir: true,
      },
      {
        id: "k2",
        ad: "Otopark",
        konum: null,
        tur: "rtsp",
        stream_url: "rtsp://ornek/2",
        restream_url: null,
        snapshot_url: null,
        sakin_gorebilir: false,
        aktif: true,
        oynatilabilir: false,
      },
    ],
  };

  function sahtele(hata = false) {
    globalThis.fetch = (async () =>
      hata
        ? ({
            ok: false,
            status: 500,
            json: async () => ({ error: { message: "sunucu" } }),
          } as Response)
        : ({ ok: true, status: 200, json: async () => KAMERALAR } as Response)) as typeof fetch;
  }

  it("kartlar cizilir; OYNATILAMAZ kamera METINLE isaretlenir", async () => {
    sahtele();
    ciz(KameralarPage);
    await waitFor(() => expect(screen.getByText("Ana kapi")).toBeInTheDocument());
    // Rozet METIN tasir — renk tek tasiyici degil.
    expect(screen.getByText("Tarayıcıda oynatılamaz")).toBeInTheDocument();
  });

  it("OYNATILAMAZ kameraya basinca SEBEP acilir, oynatici DEGIL", async () => {
    sahtele();
    ciz(KameralarPage);
    await waitFor(() => expect(screen.getByText("Otopark")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /Otopark/ }));
    await waitFor(() =>
      expect(screen.getByText(/RTSP/i)).toBeInTheDocument(),
    );
  });

  it("form MODALDA acilir", async () => {
    sahtele();
    ciz(KameralarPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni kamera" }));
    const modal = await screen.findByRole("dialog");
    expect(within(modal).getByRole("textbox", { name: "Ad" })).toBeInTheDocument();
  });

  it("UC DUSTUGUNDE 'kamera yok' YAZMAZ", async () => {
    sahtele(true);
    ciz(KameralarPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
    expect(screen.queryByText(/Kamera yok|Tanımlı kamera yok/i)).toBeNull();
  });
});

/* ==================================================================== */

describe("(P160) Sikayet Haritasi", () => {
  const HARITA = {
    bloklar: [
      {
        blok: "A",
        katlar: [
          {
            kat: 1,
            units: [
              { unit_id: "u1", unit_no: "A-1", blok: "A", kat: 1, sira: 1, color: "kirmizi", complaint_count: 5 },
              { unit_id: "u2", unit_no: "A-2", blok: "A", kat: 1, sira: 2, color: "yesil", complaint_count: 0 },
            ],
          },
        ],
      },
    ],
    unplaced: [],
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

  it("hucrede SAYI yazar — yogunluk renk TEK basina tasimiyor", async () => {
    sahtele();
    ciz(SchematicPage);
    const hucre = await screen.findByRole("button", { name: /A-1/ });
    // Daire no + acik sikayet sayisi, ikisi de METIN.
    expect(hucre.textContent).toContain("A-1");
    expect(hucre.textContent).toContain("5");
  });

  it("SECILI DAIRE ekran okuyucuya bildirilir (aria-pressed)", async () => {
    sahtele();
    ciz(SchematicPage);
    const hucre = await screen.findByRole("button", { name: /A-1/ });
    expect(hucre).toHaveAttribute("aria-pressed", "false");
    await userEvent.click(hucre);
    expect(hucre).toHaveAttribute("aria-pressed", "true");
  });

  it("daire secilince DETAY paneli acilir", async () => {
    sahtele();
    ciz(SchematicPage);
    await userEvent.click(await screen.findByRole("button", { name: /A-1/ }));
    await waitFor(() => expect(screen.getByText(/A-1 dairesi|Daire A-1/i)).toBeInTheDocument());
  });
});

/* ==================================================================== */

describe("(P160) Dis Hizmetler", () => {
  const LISTE = {
    note: "Rehberdeki numaralar yonetimce dogrulanmistir.",
    items: [
      {
        id: "h1",
        tur: "Tesisatci",
        ad: "Ali",
        soyad: "Veli",
        telefon: "+905321112233",
        aciklama: "7/24",
      },
    ],
  };

  it("kayit cizilir; telefon ARANABILIR bag olarak durur", async () => {
    globalThis.fetch = (async () =>
      ({ ok: true, status: 200, json: async () => LISTE }) as Response) as typeof fetch;
    ciz(DisHizmetlerPage);
    await waitFor(() => expect(screen.getByText("Ali Veli")).toBeInTheDocument());
    const bag = screen.getByRole("link", { name: /532/ });
    expect(bag).toHaveAttribute("href", "tel:+905321112233");
  });

  it("BOLUM NOTU korundu", async () => {
    globalThis.fetch = (async () =>
      ({ ok: true, status: 200, json: async () => LISTE }) as Response) as typeof fetch;
    ciz(DisHizmetlerPage);
    await waitFor(() =>
      expect(screen.getByText(/dogrulanmistir/)).toBeInTheDocument(),
    );
  });

  it("UC DUSTUGUNDE 'esnaf yok' YAZMAZ — tekrar dene cikar", async () => {
    globalThis.fetch = (async () =>
      ({
        ok: false,
        status: 500,
        json: async () => ({ error: { message: "sunucu" } }),
      }) as Response) as typeof fetch;
    ciz(DisHizmetlerPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
    expect(screen.queryByText(/Kayıtlı hizmet yok|Henüz kayıt yok/i)).toBeNull();
  });
});
