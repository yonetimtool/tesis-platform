// @vitest-environment jsdom
// (P160 / Asama 6) GOREVLER — tasima gerilemesi + OLU ZINCIRIN GERI GELMEMESI.
//
// Bu dosyanin en onemli testi sonuncusu: sayfa yillardir var olmayan bir
// `tip` alanini gonderiyordu. Sozlesmede `tip` YOK, `GET /tasks` o
// parametreyi ALMIYOR, `TaskOut` onu DONDURMUYOR. Yani:
//   * form secimi SESSIZCE ATILIYORDU,
//   * suzgec HICBIR SEY yapmiyordu,
//   * tablo sutunu `undefined` ciziyordu.
// Kaldirildi ve yerine GERCEK `kategori_id` suzgeci kondu. Test, o olu
// zincirin bir daha eklenmemesini kilitliyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TasksPage from "@/app/(protected)/tasks/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/tasks",
  useSearchParams: () => new URLSearchParams(),
}));

const KATEGORI = { id: "k1", ad: "Temizlik" };

const GOREV = {
  id: "g1",
  ad: "Ortak alan temizligi",
  aciklama: null,
  atanan_user_id: null,
  kategori_id: "k1",
  periyot_dakika: null,
  sonraki_planlanan: null,
  foto_zorunlu: false,
  aktif: true,
  created_at: "2026-08-01T09:00:00Z",
};

const PLANSIZ_OLMAYAN = {
  ...GOREV,
  id: "g2",
  ad: "Jenerator kontrolu",
  kategori_id: null,
  // Takvim testinde kullanilir; ay bagimsiz olsun diye sabit.
  sonraki_planlanan: "2026-08-14T10:00:00Z",
};

function sahte(gorevler: unknown[]) {
  const cagrilar: { url: string; method: string; body?: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url.includes("/api/task-categories")) {
      return { ok: true, status: 200, json: async () => ({ items: [KATEGORI] }) } as Response;
    }
    if (url.includes("/api/users")) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ meta: { limit: 200, offset: 0, total: 0 }, items: [] }),
      } as Response;
    }
    return {
      ok: true,
      status: 200,
      json: async () => ({
        meta: { limit: 25, offset: 0, total: gorevler.length },
        items: gorevler,
      }),
    } as Response;
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) Gorevler — OLU `tip` ZINCIRI GERI GELMESIN", () => {
  it("istekte `tip` parametresi GITMEZ", async () => {
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    // Sozlesmede yok; gondermek sessizce atilan bir alan demekti.
    expect(cagrilar.every((c) => !c.url.includes("tip="))).toBe(true);
  });

  it("KATEGORI suzgeci GERCEKTEN istege yansir", async () => {
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    await userEvent.selectOptions(screen.getByLabelText("Kategori"), "k1");
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url.includes("kategori_id=k1"))).toBe(true),
    );
  });

  it("KAYDEDERKEN govdede `tip` YOK", async () => {
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni görev" }));
    const modal = await screen.findByRole("dialog");
    await userEvent.type(within(modal).getByLabelText(/Başlık|Ad/), "Yeni is");
    await userEvent.click(within(modal).getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.method === "POST");
      expect(post, "POST atilmadi").toBeTruthy();
      expect(Object.keys(post!.body as object)).not.toContain("tip");
    });
  });
});

/* ==================================================================== */

describe("(P160) Gorevler — uc gorunum", () => {
  it("LISTE varsayilan gorunum", async () => {
    sahte([GOREV]);
    ciz(TasksPage);
    await waitFor(() => expect(screen.getByRole("table")).toBeInTheDocument());
  });

  it("PANO gorunumunde kategori sutunlari ve KATEGORISIZ sutunu var", async () => {
    sahte([GOREV, PLANSIZ_OLMAYAN]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("tab", { name: "Pano" }));

    // Kategorisiz sutun HER ZAMAN var — yoksa kategorisiz gorevler
    // panoda GORUNMEZ olurdu.
    expect(
      screen.getByRole("region", { name: "Kategorisiz" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("region", { name: "Temizlik" })).toBeInTheDocument();
  });

  it("PANODA surukleme TEK YOL DEGIL — klavye yedegi var", async () => {
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("tab", { name: "Pano" }));

    // Her kartta kategoriyi degistiren ADLI bir secim olmali; yalniz
    // surukleme sunmak klavye kullanicisini bu gorunumden dislardi.
    const secim = screen.getByLabelText(/Ortak alan temizligi görevini taşı/);
    await userEvent.selectOptions(secim, "diger");
    await waitFor(() => {
      const patch = cagrilar.find((c) => c.method === "PATCH");
      expect(patch, "kategori tasima istegi gitmedi").toBeTruthy();
      expect((patch!.body as { kategori_id: unknown }).kategori_id).toBeNull();
    });
  });

  it("TAKVIM gorunumu plansiz gorevleri GIZLEMEZ", async () => {
    sahte([GOREV]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("tab", { name: "Takvim" }));
    // `sonraki_planlanan` yok -> takvimde yeri yok ama VAR.
    expect(screen.getByText(/Planlanmamış/)).toBeInTheDocument();
  });
});

/* ==================================================================== */

describe("(P160) Gorevler — korunan davranislar", () => {
  it("form MODALDA acilir", async () => {
    sahte([GOREV]);
    ciz(TasksPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni görev" }));
    const modal = await screen.findByRole("dialog");
    expect(within(modal).getByRole("button", { name: "Kaydet" })).toBeInTheDocument();
  });

  it("FOTO ZORUNLU rozeti korundu", async () => {
    sahte([{ ...GOREV, foto_zorunlu: true }]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    expect(screen.getByText("foto zorunlu")).toBeInTheDocument();
  });

  it("UC DUSTUGUNDE hata + TEKRAR DENE", async () => {
    globalThis.fetch = (async () =>
      ({
        ok: false,
        status: 500,
        json: async () => ({ error: { message: "sunucu" } }),
      }) as Response) as typeof fetch;
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
  });
});
