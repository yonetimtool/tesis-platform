// @vitest-environment jsdom
// (P247-bekleyen 1.2) DAIRE NOTLARI — "saha personeli gorebilir" isareti.
//
// Suzme SUNUCUDA (backend/tests/test_p247_bekleyen.py). Burada olculen
// arayuz sozlesmesi:
//  1. Daire ekinde isaret kutusu VAR, VARSAYILAN KAPALI ve ne anlama
//     geldigi acikca yazili ("Guvenlik ve tesis gorevlileri bu notu
//     gorebilir").
//  2. Isaretsiz not `saha_gorebilir:false`, isaretli not `true` gider.
//  3. Listede her notun durumu yazili; dugme PATCH ile tersine cevirir.
//  4. Daire DISI eklerde kutu YOK ve govdeye alan HIC yazilmaz.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { Ekler } from "@/components/Ekler";

import { ciz } from "./yardimci";

type Cagri = { url: string; method: string; body: unknown };

function taklit(items: unknown[]): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const method = init?.method ?? "GET";
    cagrilar.push({ url, method, body: init?.body ? JSON.parse(String(init.body)) : undefined });
    const govde = method === "GET" ? { items } : { id: "yeni" };
    return new Response(JSON.stringify(govde), {
      status: method === "POST" ? 201 : 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

const NOT = {
  id: "e1",
  tur: "not",
  metin: "borc anlasmazligi",
  saha_gorebilir: false,
  created_at: "2026-09-20T09:00:00Z",
};

function daire(tip = "unit") {
  return () => createElement(Ekler, { varlikTipi: tip, varlikId: "u1" });
}

describe("(P247-bekleyen 1.2) daire notu saha isareti", () => {
  it("kutu var, varsayilan KAPALI, anlami yazili; govdeye false/true gider", async () => {
    const c = taklit([]);
    ciz(daire());
    const kutu = (await screen.findByLabelText(
      "Güvenlik ve tesis görevlileri bu notu görebilir",
    )) as HTMLInputElement;
    expect(kutu.checked).toBe(false);
    expect(screen.getByText(/yalnızca yönetim tarafından görülür/)).toBeTruthy();

    const u = userEvent.setup();
    await u.type(screen.getByRole("textbox"), "kapi kodu");
    await u.click(screen.getByRole("button", { name: "Not ekle" }));
    await waitFor(() => expect(c.some((x) => x.method === "POST")).toBe(true));
    expect(c.find((x) => x.method === "POST")!.body).toMatchObject({
      varlik_tipi: "unit",
      saha_gorebilir: false,
    });

    await u.type(screen.getByRole("textbox"), "ikinci");
    await u.click(kutu);
    await u.click(screen.getByRole("button", { name: "Not ekle" }));
    await waitFor(() => expect(c.filter((x) => x.method === "POST").length).toBe(2));
    expect(c.filter((x) => x.method === "POST")[1].body).toMatchObject({ saha_gorebilir: true });
    // Gonderimden sonra kutu yine KAPALI (bir sonraki not varsayilandan baslar).
    expect(kutu.checked).toBe(false);
  });

  it("listede durum yazili; dugme PATCH ile tersine cevirir", async () => {
    const c = taklit([NOT]);
    ciz(daire());
    expect(await screen.findByText(/Yalnız yönetim/)).toBeTruthy();
    const u = userEvent.setup();
    await u.click(screen.getByRole("button", { name: "Sahaya aç" }));
    await waitFor(() => expect(c.some((x) => x.method === "PATCH")).toBe(true));
    const p = c.find((x) => x.method === "PATCH")!;
    expect(p.url).toBe("/api/panel/ekler/e1");
    expect(p.body).toEqual({ saha_gorebilir: true });
  });

  it("daire DISI ekte kutu YOK ve alan govdeye yazilmaz", async () => {
    const c = taklit([]);
    ciz(daire("task"));
    await screen.findByRole("button", { name: "Not ekle" });
    expect(screen.queryByLabelText("Güvenlik ve tesis görevlileri bu notu görebilir")).toBeNull();
    const u = userEvent.setup();
    await u.type(screen.getByRole("textbox"), "x");
    await u.click(screen.getByRole("button", { name: "Not ekle" }));
    await waitFor(() => expect(c.some((x) => x.method === "POST")).toBe(true));
    expect(c.find((x) => x.method === "POST")!.body).not.toHaveProperty("saha_gorebilir");
  });
});
