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

afterEach(() => vi.restoreAllMocks());

describe("(P239 §4) gorev son tarihi", () => {
  it("ALAN VAR ve girilen deger GOVDEYE GIRER (ISO)", async () => {
    const cagrilar = sahte([GOREV]);
    ciz(TasksPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni görev" }),
    );
    const modal = await screen.findByRole("dialog");
    await userEvent.type(within(modal).getByLabelText("Başlık"), "Yeni is");

    const alan = el("gorev-son-tarih") as HTMLInputElement;
    expect(alan, "son tarih alani YOK").toBeTruthy();
    await userEvent.type(alan, "2026-09-20T17:30");

    await userEvent.click(within(modal).getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const post = cagrilar.find((c) => c.method === "POST");
      expect(post, "POST atilmadi").toBeTruthy();
      const govde = post!.body as Record<string, unknown>;
      expect(govde.son_tarih).toBeTruthy();
      // Yerel girdi ISO'ya cevrilir; gun/saat korunur.
      expect(String(govde.son_tarih)).toContain("2026-09-20");
      // AYRI ALAN: periyodik tekrar alani DOLMAZ.
      expect(govde.sonraki_planlanan).toBeNull();
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

  it("DUZENLEMEDE mevcut son tarih ALANA YUKLENIR", async () => {
    // Yuklenmeseydi kaydet'e basmak, var olan son tarihi SESSIZCE
    // silerdi (PATCH govdesi alani her zaman tasiyor).
    sahte([{ ...GOREV, son_tarih: "2026-09-20T17:30:00Z" }]);
    ciz(TasksPage);
    await waitFor(() =>
      expect(screen.getByText("Ortak alan temizligi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getAllByRole("button", { name: "Düzenle" })[0]);
    await waitFor(() => expect(el("gorev-son-tarih")).toBeTruthy());
    expect((el("gorev-son-tarih") as HTMLInputElement).value).toContain(
      "2026-09-20",
    );
  });
});
