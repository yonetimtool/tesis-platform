// @vitest-environment jsdom
// (P239 §4) GOREVE SON TARIH — form artik onu GONDERIYOR.
//
// OLCULEN KUSUR: `son_tarih` kolonu P230 §4'te eklendi, arka uc
// create/update'te KABUL EDIYOR, liste "gecikti" rozetini ondan
// hesapliyor — ama FORM ONU HIC GONDERMIYORDU. Yani "gecikti" durumu
// arayuzden kurulamiyor, yalnizca okunuyordu.
//
// `sonraki_planlanan` ILE KARISTIRILMAMALI: o yalniz PERIYODIK
// gorevlerde dolu ve anlami "bir sonraki tekrar". Testin son maddesi
// ikisinin AYRI alanlar olarak gittigini olcer.
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

const GOREV = {
  id: "g1",
  ad: "Ortak alan temizligi",
  aciklama: null,
  atanan_user_id: null,
  kategori_id: null,
  periyot_dakika: null,
  sonraki_planlanan: null,
  son_tarih: null,
  foto_zorunlu: false,
  aktif: true,
  created_at: "2026-08-01T09:00:00Z",
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
    const govde = url.includes("/api/task-categories")
      ? { items: [] }
      : url.includes("/api/users")
        ? { meta: { limit: 200, offset: 0, total: 0 }, items: [] }
        : {
            meta: { limit: 25, offset: 0, total: gorevler.length },
            items: gorevler,
          };
    return { ok: true, status: 200, json: async () => govde } as Response;
  }) as typeof fetch;
  return cagrilar;
}

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

/** Takvimde hedef aya GEZINIR ve gunu secer (bugunden bagimsiz). */
async function gunuSec(iso: string) {
  const hedefAy = iso.slice(0, 7);
  for (let i = 0; i < 36; i++) {
    const simdiki = (el("gorev-son-tarih-ay") as HTMLElement).textContent;
    if (simdiki === hedefAy) break;
    const ileri = (simdiki ?? "") < hedefAy;
    await userEvent.click(
      el(ileri ? "gorev-son-tarih-ay-ileri" : "gorev-son-tarih-ay-geri") as HTMLElement,
    );
  }
  await userEvent.click(el(`gorev-son-tarih-gun-${iso}`) as HTMLElement);
}

afterEach(() => vi.restoreAllMocks());

describe("(P239 §4) gorev son tarihi", () => {
  it("TAKVIMDEN secilen gun GOVDEYE GIRER (ISO)", async () => {
    // (P240 §5c) Alan artik `datetime-local` DEGIL, ay izgarasi.
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni görev" }),
    );
    const modal = await screen.findByRole("dialog");
    await userEvent.type(within(modal).getByLabelText("Başlık"), "Yeni is");

    // Takvim BU AYDA acilir; gezinerek hedef aya gidilir.
    expect(el("gorev-son-tarih-takvim"), "takvim YOK").toBeTruthy();
    const hedef = "2026-09-20";
    await gunuSec(hedef);

    await userEvent.click(within(modal).getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.method === "POST");
      expect(post, "POST atilmadi").toBeTruthy();
      const govde = post!.body as Record<string, unknown>;
      expect(govde.son_tarih).toBeTruthy();
      // ISO DIZESINDE GUN ARANMAZ: yerel 23:59, saat dilimine gore
      // ERTESI GUNUN UTC damgasi olabilir (ilk yazimda test tam
      // bundan kirmizi dondu — dogru olarak). Olculen sey, degerin
      // YEREL olarak 20 Eylul 23:59'a denk gelmesi.
      const d = new Date(String(govde.son_tarih));
      expect(
        [d.getFullYear(), d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes()],
      ).toEqual([2026, 9, 20, 23, 59]);
      // AYRI ALAN: periyodik tekrar alani DOLMAZ.
      expect(govde.sonraki_planlanan).toBeNull();
    });
  });

  it("SAAT VERILMEZSE GUN SONU (23:59) — gun basi DEGIL", async () => {
    // "Tarih verdim ama saat vermedim" -> "o gunun sonuna kadar"
    // demektir. 00:00 almak isi daha baslamadan gecikmis yapardi.
    sahte([GOREV]);
    ciz(TasksPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni görev" }),
    );
    await screen.findByRole("dialog");
    await gunuSec("2026-09-20");
    expect((el("gorev-son-tarih-ozet") as HTMLElement).textContent).toBe(
      "2026-09-20T23:59",
    );
  });

  it("AYNI GUNE IKINCI TIKLAMA secimi KALDIRIR", async () => {
    // Son tarihi SILMENIN baska yolu yok.
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni görev" }),
    );
    const modal = await screen.findByRole("dialog");
    await userEvent.type(within(modal).getByLabelText("Başlık"), "Yeni is");
    await gunuSec("2026-09-20");
    await userEvent.click(el("gorev-son-tarih-gun-2026-09-20") as HTMLElement);

    await userEvent.click(within(modal).getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.method === "POST");
      expect(post).toBeTruthy();
      expect((post!.body as Record<string, unknown>).son_tarih).toBeNull();
    });
  });

  it("BOS BIRAKILIRSA null gider — bugun VARSAYILMAZ", async () => {
    // Varsayilan bir tarih koymak, kullanicinin koymadigi bir sozu
    // kaydetmek ve her gorevi bir gun sonra "gecikti" yapmak olurdu.
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni görev" }),
    );
    const modal = await screen.findByRole("dialog");
    await userEvent.type(within(modal).getByLabelText("Başlık"), "Yeni is");
    await userEvent.click(within(modal).getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      const post = cagrilar.find((c) => c.method === "POST");
      expect(post).toBeTruthy();
      expect((post!.body as Record<string, unknown>).son_tarih).toBeNull();
    });
  });

  it("DUZENLEMEDE takvim GOREVIN AYINA ATLAR ve gun ISARETLI", async () => {
    // Atlamazsa, son tarihi baska bir ayda olan gorevde takvim BOS
    // gorunur ve kullanici "tarih silinmis" sanir; kaydet'e basmak da
    // var olan tarihi SESSIZCE silerdi (PATCH tam-govde).
    sahte([{ ...GOREV, son_tarih: "2026-09-20T17:30:00Z" }]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getAllByRole("button", { name: "Düzenle" })[0]);
    await waitFor(() => expect(el("gorev-son-tarih-ay")).toBeTruthy());
    expect((el("gorev-son-tarih-ay") as HTMLElement).textContent).toBe(
      "2026-09",
    );
    expect(
      (el("gorev-son-tarih-gun-2026-09-20") as HTMLElement).getAttribute(
        "aria-pressed",
      ),
    ).toBe("true");
  });
});
