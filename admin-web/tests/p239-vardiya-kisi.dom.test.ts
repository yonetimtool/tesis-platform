// @vitest-environment jsdom
// (P239 §5) "SU AN GOREVDE" — kisiler TIKLANABILIR, kendi kaydim CIZILMEZ.
//
// Olculen kusur: gorevdekiler duz metindi (`ad.join(", ")`). Yonetici kim
// gorevde goruyordu ama ONA ULASAMIYORDU — numara icin kullanicilar
// sayfasina gidip adi aramak gerekiyordu.
//
// NUMARA KAYNAGI: `GET /users/{id}` (tek-kayit YONETIM gorunumu, telefonu
// zaten doner). `/call-target` DEGIL — o C1a arama kapisi yalniz
// security+resident'a acik ve bu tur onu GENISLETMEZ.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/vardiya-plani/page";

import { ciz } from "./yardimci";

const BUGUN = new Date().toISOString().slice(0, 10);

const kanca = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

/** Cagrilan URL'ler — "istek ATILMADI" iddiasi bunlarla olculur. */
let cagrilan: string[] = [];

function taklit(opts: { telefon?: string | null; benim?: string } = {}) {
  cagrilan = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilan.push(url);
    let govde: unknown = { ok: true };
    if (url.startsWith("/api/vardiya-plani/cizelge")) {
      govde = { baslangic: BUGUN, bitis: BUGUN, personel: [] };
    } else if (url.includes("/vardiya-plani/simdi")) {
      govde = {
        gorevdeki_vardiya: {
          shift_ad: "Gece",
          baslangic_saat: "22:00:00",
          bitis_saat: "05:00:00",
        },
        gorevdekiler: [
          { plan_id: "p-1", user_id: "u-1", ad: "Ali Guvenlik", rol: "security" },
          { plan_id: "p-2", user_id: "u-ben", ad: "Ben Kendim", rol: "yonetici" },
        ],
        sonraki_vardiya: null,
        sonrakiler: [],
      };
    } else if (url === "/api/me") {
      govde = { id: opts.benim ?? "u-ben", role: "yonetici" };
    } else if (/^\/api\/users\/[^/?]+$/.test(url)) {
      govde = { id: "u-1", ad: "Ali Guvenlik", telefon: opts.telefon ?? null };
    } else if (url.startsWith("/api/users")) {
      govde = { items: [] };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

it("GOREVDEKILER TIKLANABILIR; KENDI kaydim CIZILMEZ", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorevde-u-1")).toBeTruthy());
  // Kendi gorevde oldugumu zaten biliyorum; kendi numaramı aramak anlamsiz.
  expect(kanca("vardiya-gorevde-u-ben")).toBeNull();
});

it("KISI PANELI: rol + vardiya satiri + DOKUNULABILIR numara", async () => {
  taklit({ telefon: "+905551110000" });
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorevde-u-1")).toBeTruthy());
  await userEvent.click(kanca("vardiya-gorevde-u-1") as HTMLElement);

  await waitFor(() => expect(kanca("kisi-telefon")).toBeTruthy());
  const bag = kanca("kisi-telefon") as HTMLAnchorElement;
  // DUZ METIN DEGIL BAG: kullanici numarayi elle kopyalamasin.
  expect(bag.getAttribute("href")).toBe("tel:+905551110000");
  expect(kanca("kisi-rol")?.textContent).toBe("Güvenlik");
  expect(kanca("kisi-alt-satir")?.textContent).toBe("22:00–05:00");
});

it("NUMARA YOKSA bos birakilmaz — 'kayitli degil' YAZAR", async () => {
  // Bos satir "yuklenmedi mi, yok mu" sorusunu dogururdu.
  taklit({ telefon: null });
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorevde-u-1")).toBeTruthy());
  await userEvent.click(kanca("vardiya-gorevde-u-1") as HTMLElement);

  await waitFor(() => expect(kanca("kisi-telefon-yok")).toBeTruthy());
  expect(kanca("kisi-telefon")).toBeNull();
});

it("PANEL ACILMADAN /users/{id} ISTEGI ATILMAZ", async () => {
  // Serit acilir acilmaz N istek atmak, gorulmeyecek numaralari
  // toplu cozmek olurdu (KVKK: amac-sinirli).
  taklit({ telefon: "+905551110000" });
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorevde-u-1")).toBeTruthy());
  expect(cagrilan.some((u) => /^\/api\/users\/[^/?]+$/.test(u))).toBe(false);

  await userEvent.click(kanca("vardiya-gorevde-u-1") as HTMLElement);
  await waitFor(() =>
    expect(cagrilan.some((u) => u === "/api/users/u-1")).toBe(true),
  );
});
