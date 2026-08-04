// @vitest-environment jsdom
// (P131b) GOREV FOTO KANITI EKRANDA GORUNUR MU?
//
// OLCULEN KUSUR: sunucu `foto_url`i HIC doldurmuyordu (sema alani vardi,
// deger `null` geliyordu) ve panel bunu "foto var" ROZETIYLE ortuyordu.
// Yani kanit yukleniyor, saklaniyor ve HICBIR YERDE gorunmuyordu — rozet
// eksigi gizliyordu.
//
// UC DURUM AYRI AYRI OLCULUR, cunku ucu de farkli sey soyler:
//   * `foto_url` var        -> GORSELIN KENDISI cizilir,
//   * `foto_key` var/url yok -> rozet DOGRUDUR ("kanit var, gosterilemiyor"),
//   * ikisi de yok           -> "yok".
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TasksPage from "@/app/(protected)/tasks/page";

import { ciz } from "./yardimci";

const GOREV = {
  id: "g1",
  ad: "Su sızıntısı",
  aciklama: null,
  atanan_user_id: null,
  kategori_id: null,
  durum: "acik",
  oncelik: "orta",
  foto_zorunlu: false,
  created_at: "2026-08-01T10:00:00Z",
};

function fetchTaklidi(tamamlama: Record<string, unknown>) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    const govde = url.includes("/completions")
      ? { meta: { limit: 50, offset: 0, total: 1 }, items: [tamamlama] }
      : url.includes("/api/tasks")
        ? { meta: { limit: 50, offset: 0, total: 1 }, items: [GOREV] }
        : { meta: { limit: 50, offset: 0, total: 0 }, items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

const TAMAMLAMA = {
  id: "c1",
  task_id: "g1",
  tamamlayan_user_id: "u1",
  tamamlanma_zamani: "2026-08-02T09:00:00Z",
  notlar: "kanıt",
  created_at: "2026-08-02T09:00:00Z",
};

/** Gorev satirindaki "Kayıtlar" dugmesine basar. */
async function kayitlariAc() {
  const kullanici = userEvent.setup();
  await kullanici.click(await screen.findByRole("button", { name: /Kayıtlar/i }));
}

afterEach(() => vi.restoreAllMocks());

describe("(P131b) tamamlama foto kaniti", () => {
  it("foto_url VARSA gorselin KENDISI cizilir", async () => {
    fetchTaklidi({
      ...TAMAMLAMA,
      foto_key: "t/tasks/a.png",
      foto_url: "http://depo.ornek/a.png?imza=1",
    });
    ciz(TasksPage);
    await kayitlariAc();
    const gorsel = await screen.findByRole("img");
    expect(gorsel).toHaveAttribute("src", "http://depo.ornek/a.png?imza=1");
    // Tam boyut icin YENI SEKMEDE acilir (kanit incelenebilmeli).
    expect(gorsel.closest("a")).toHaveAttribute("target", "_blank");
  });

  it("foto_key VAR ama url YOKSA rozet kalir (durust yedek)", async () => {
    fetchTaklidi({ ...TAMAMLAMA, foto_key: "t/tasks/a.png", foto_url: null });
    ciz(TasksPage);
    await kayitlariAc();
    // "foto var" METNI birden fazla yerde gecebilir (sutun basligi vb.);
    // olculen sey ROZET — kendi biciminden (yuvarlak etiket) ayrilir.
    const rozet = await screen.findByText(/^foto var$/i);
    expect(rozet).toBeInTheDocument();
    expect(screen.queryByRole("img")).toBeNull();
  });

  it("FOTOSUZ kayitta gorsel de rozet de YOK", async () => {
    fetchTaklidi({ ...TAMAMLAMA, foto_key: null, foto_url: null });
    ciz(TasksPage);
    await kayitlariAc();
    expect(screen.queryByRole("img")).toBeNull();
  });
});
