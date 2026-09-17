// @vitest-environment jsdom
// (P240 §5) UC KUCUK DUZELTME — ikisi web'de, biri (mobil devriye
// vardiyasi) P239'da zaten kapanmisti.
//
// (a) "Yeni vardiya" dugmesi gorunur yerde ve MAVI (birincil).
// (c) Gorev son tarihi TAKVIMDEN secilir; vardiya modali ve gorev
//     formu AYNI bileseni kullanir (mobildeki ay izgarasina esit).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import VardiyaPlaniPage from "@/app/(protected)/vardiya-plani/page";
import TasksPage from "@/app/(protected)/tasks/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/tasks",
  useSearchParams: () => new URLSearchParams(),
}));

const BUGUN = new Date().toISOString().slice(0, 10);
const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

function sahtele() {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    let govde: unknown = { ok: true };
    if (url.startsWith("/api/vardiya-plani/cizelge")) {
      govde = { baslangic: BUGUN, bitis: BUGUN, personel: [] };
    } else if (url.includes("/vardiya-plani/simdi")) {
      govde = { gorevdeki_vardiya: null, gorevdekiler: [], sonraki_vardiya: null, sonrakiler: [] };
    } else if (url === "/api/me") {
      govde = { id: "u-ben", role: "yonetici" };
    } else if (url.includes("/api/task-categories")) {
      govde = { items: [] };
    } else if (url.startsWith("/api/shifts") || url.startsWith("/api/users")) {
      govde = { meta: { limit: 200, offset: 0, total: 0 }, items: [] };
    } else {
      govde = { meta: { limit: 25, offset: 0, total: 0 }, items: [] };
    }
    return { ok: true, status: 200, json: async () => govde } as Response;
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P240 §5a) 'Yeni vardiya' dugmesi", () => {
  it("BIRINCIL (mavi dolgu) — gri yigin arasinda kaybolmaz", async () => {
    // Olculen kusur: dugme gorunum secici + filtreler + tazele ile ayni
    // sarilabilir satirdaydi ve hepsi gri (`ikincil`) oldugu icin
    // aralarinda kayboluyordu.
    sahtele();
    ciz(VardiyaPlaniPage);
    await waitFor(() => expect(el("vardiya-yeni")).toBeTruthy());
    const dugme = el("vardiya-yeni") as HTMLElement;
    // `birincil` = `--yz-metal-accent` dolgu (mavi gradyan).
    expect(dugme.style.background).toContain("--yz-metal-accent");
    // Yanindaki araclar HALA ikincil: "hepsini mavi yap" degil,
    // BIR tanesini one cikar.
    expect((el("vardiya-tazele") as HTMLElement).style.background).not.toContain(
      "--yz-metal-accent",
    );
  });

  it("GEZINME ARACLARIYLA AYNI KUMEDE DEGIL", async () => {
    // Bu bir GORUNUM secimi degil, KAYIT OLUSTURMA.
    sahtele();
    ciz(VardiyaPlaniPage);
    await waitFor(() => expect(el("vardiya-yeni")).toBeTruthy());
    const kume = (el("vardiya-gorunum-ay") as HTMLElement).parentElement!;
    expect(kume.contains(el("vardiya-yeni"))).toBe(false);
  });
});

describe("(P240 §5c) gorev son tarihi TAKVIMDEN", () => {
  it("AY IZGARASI cizilir — tarayici `datetime-local` DEGIL", async () => {
    sahtele();
    ciz(TasksPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni görev" }),
    );
    await screen.findByRole("dialog");
    expect(el("gorev-son-tarih-takvim")).toBeTruthy();
    // Eski girdi KALMADI: iki farkli secim yolu birakmak, hangisinin
    // gectigini belirsiz kilardi.
    expect(el("gorev-son-tarih")).toBeNull();
  });

  it("VARDIYA MODALI ve GOREV FORMU AYNI takvimi kullanir", async () => {
    // "Mobildeki vardiya plani takvimi gibi" istegi, iki ekranin AYNI
    // bileseni kullanmasiyla karsilanir; kopya cizim zamanla ayrisirdi.
    sahtele();
    ciz(VardiyaPlaniPage);
    await waitFor(() => expect(el("vardiya-yeni")).toBeTruthy());
    await userEvent.click(el("vardiya-yeni") as HTMLElement);
    await waitFor(() => expect(el("vardiya-ekle-takvim")).toBeTruthy());
    // Ortak bilesenin imzasi: 7 sutunlu izgara (haftaya hizali).
    const izgara = (el("vardiya-ekle-takvim") as HTMLElement).querySelector(
      ".grid-cols-7",
    );
    expect(izgara, "7 sutunlu izgara YOK").toBeTruthy();
  });

  it("GECMIS GUN de secilebilir — gecikmis is SONRADAN kaydedilebilir", async () => {
    // Gecmisi kapatmak, dun bitmesi gereken bir isi sisteme girmeyi
    // imkansiz kilardi (gecikme raporu tam bunun icin var).
    sahtele();
    ciz(TasksPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni görev" }),
    );
    const modal = await screen.findByRole("dialog");
    await userEvent.click(el("gorev-son-tarih-ay-geri") as HTMLElement);
    const hucreler = within(modal).getAllByRole("button", { pressed: false });
    const gecmis = hucreler.find((h) =>
      /^gorev-son-tarih-gun-/.test(h.getAttribute("data-test") ?? ""),
    );
    expect(gecmis, "gecmis ayda gun hucresi YOK").toBeTruthy();
    expect((gecmis as HTMLButtonElement).disabled).toBe(false);
  });
});
