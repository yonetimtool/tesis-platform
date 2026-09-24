// @vitest-environment jsdom
// (P247 §2) PROFIL MENUSUNDEKI ROL GECISI — cizim + tel uzerindeki govde.
// Kararlarin (jeton, middleware, menu, bildirim) olcumu: p247-rol-gecisi.test.ts.
import { fireEvent, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { RolSecimi } from "@/components/RolGecisi";

import { ciz } from "./yardimci";

describe("4. profil menusu + BFF", () => {
  afterEach(() => vi.restoreAllMocks());

  function fetchKaydet(me: unknown) {
    const cagrilar: { url: string; yontem: string; govde: unknown }[] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      cagrilar.push({
        url,
        yontem: init?.method ?? "GET",
        govde: init?.body ? JSON.parse(String(init.body)) : null,
      });
      if (url === "/api/me/rol-gecis" && (init?.method ?? "GET") === "GET") {
        return new Response(JSON.stringify(me), { status: 200 });
      }
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }) as typeof fetch;
    return cagrilar;
  }

  it("iki rol: iki secenek, aktif olan isaretli; Sakin -> POST {rol: resident}", async () => {
    const c = fetchKaydet({ role: "yonetici", roller: ["yonetici", "resident"] });
    const replace = vi.fn();
    Object.defineProperty(window, "location", {
      value: { ...window.location, replace },
      writable: true,
    });
    ciz(RolSecimi);
    const yon = await screen.findByRole("menuitemradio", { name: "Yönetici" });
    const sakin = screen.getByRole("menuitemradio", { name: "Sakin" });
    expect(yon.getAttribute("aria-checked")).toBe("true");
    expect(sakin.getAttribute("aria-checked")).toBe("false");
    fireEvent.click(sakin);
    // Perde HEMEN: eski mod tiklanabilir kalmaz.
    expect(await screen.findByText("Sakin moduna geçiliyor...")).toBeTruthy();
    await waitFor(() => expect(replace).toHaveBeenCalledWith("/"));
    const post = c.find((x) => x.yontem === "POST");
    expect(post?.url).toBe("/api/me/rol-gecis");
    expect(post?.govde).toEqual({ rol: "resident" });
  });

  it("tek rollu yonetici ve guvenlik: menu CIZILMEZ", async () => {
    for (const me of [
      { role: "yonetici", roller: ["yonetici"] },
      { role: "security", roller: ["security"] },
    ]) {
      const c = fetchKaydet(me);
      const { unmount } = ciz(RolSecimi);
      await waitFor(() => expect(c.some((x) => x.url === "/api/me/rol-gecis")).toBe(true));
      expect(screen.queryByRole("menuitemradio")).toBeNull();
      unmount();
    }
  });

});

