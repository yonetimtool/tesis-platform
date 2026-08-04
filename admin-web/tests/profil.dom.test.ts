// @vitest-environment jsdom
// (P126.3) PROFIL — `app.*`in ilk KENDINE AIT sayfasi.
//
// Bugune kadar paneldeki 25 sayfa yonetimin BASKALARINI yonettigi
// ekranlardi; bu, kullanicinin KENDI kaydina dokundugu ilk yer ve tesis
// calisma alaninin (P126.3-.6) temel tasi.
//
// UC OLCUM, ucu de sessizce yanlis olabilecek cinsten:
//  1. Telefon P123 maskesinden GECIYOR mu (yoksa alan gruplanmadan yazilir);
//  2. Sunucuya NORMALLESTIRILMIS gidiyor mu (ayni numaranin iki yazimi,
//     telefon global benzersiz oldugu icin cakisma uretir);
//  3. Bos birakmak numarayi KALDIRIYOR mu (acik null) — "degistirme" ile
//     "kaldir" arasindaki fark.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import ProfilPage from "@/app/(protected)/profil/page";

import { ciz } from "./yardimci";

/**
 * YEREL fetch taklidi — paylasilan `fetchSahtele` GOVDE yakalamiyor ve bu
 * testin asil olcumu gonderilen govdedir (normallestirilmis telefon).
 * Paylasilan yardimciyi genisletmek, 40+ testin davranisini degistirme
 * riskiydi; yerel taklit o riski almadan ayni iSi yapiyor.
 */
function fetchTaklidi(profil: unknown) {
  const cagrilar: { url: string; method: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url.startsWith("/api/me/contact")) {
      return new Response(null, { status: 204 });
    }
    if (url.startsWith("/api/me")) {
      return new Response(JSON.stringify(profil), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ error: { message: "yok" } }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const PROFIL = {
  id: "u1",
  ad: "Ayşe Yılmaz",
  email: "ayse@ornek.com",
  telefon: "+905431992904",
  aranabilir: true,
  role: "resident",
};

afterEach(() => vi.restoreAllMocks());

describe("Profilim", () => {
  it("KIMLIK bilgileri gosterilir", async () => {
    fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    expect(await screen.findByText("Ayşe Yılmaz")).toBeInTheDocument();
    expect(screen.getByText("ayse@ornek.com")).toBeInTheDocument();
  });

  it("TELEFON P123 maskesiyle GRUPLANMIS gelir", async () => {
    // Sunucudan E.164 gelir; kullanici yerel bicimi gormeli.
    fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    await waitFor(() =>
      expect(screen.getByDisplayValue("0543 199 29 04")).toBeInTheDocument(),
    );
  });

  it("KAYDETTE sunucuya NORMALLESTIRILMIS numara gider", async () => {
    const cagrilar = fetchTaklidi(PROFIL);
    ciz(ProfilPage);
    await waitFor(() =>
      expect(screen.getByDisplayValue("0543 199 29 04")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/i }));
    await waitFor(() => {
      const c = cagrilar.find((x) => x.url.includes("/api/me/contact"));
      expect(c?.body).toMatchObject({ telefon: "+905431992904" });
    });
  });

  it("GECERSIZ on ek KAYDETTIRMEZ", async () => {
    fetchTaklidi({ ...PROFIL, telefon: null });
    ciz(ProfilPage);
    const kutu = await screen.findByPlaceholderText(/05/);
    await userEvent.type(kutu, "02125554433");
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/i }));
    expect(await screen.findByText(/5 ile başlamalı/i)).toBeInTheDocument();
  });
});
