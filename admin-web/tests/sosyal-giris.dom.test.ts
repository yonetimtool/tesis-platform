// @vitest-environment jsdom
// (P154 / Asama 4) SOSYAL GIRIS DUGMELERI.
//
// Olculen dort sey — dordu de "yanlisi kullaniciyi cikmaza sokar" sinifi:
//   1. YAPILANDIRILMAMISSA HIC CIZILMEZ. Calismayacak bir dugme
//      gostermek, kullaniciyi kesin basarisiz bir yola sokmak olurdu ve
//      brief'in sarti "tikanirsa Asama 3 tek basina calissin".
//   2. NIYET SAGLAYICIYA GITMEDEN ONCE yazilir. Donusteki sayfa hangi isi
//      yapacagini oradan ogrenir; saglayici bize kendi parametremizi geri
//      vermez.
//   3. YUZEY govdede gider — mobil ve web ayni ucu FARKLI donus adresiyle
//      kullanir.
//   4. LISTE ALINAMAZSA PAROLA GIRISI ETKILENMEZ (sessiz basarisizlik
//      BURADA dogrudur: sosyal giris bir EK yoldur).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createElement } from "react";

import { OAUTH_NIYET, SosyalGiris } from "@/components/SosyalGiris";

import { ciz } from "./yardimci";

type Cagri = { url: string; body: unknown };

function taklit(saglayicilar: string[] | null): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url.includes("saglayicilar")) {
      if (saglayicilar === null) {
        return new Response("bozuk", { status: 503 });
      }
      return new Response(JSON.stringify({ saglayicilar }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ adres: "https://saglayici/yetki" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => {
  vi.restoreAllMocks();
  sessionStorage.clear();
});

describe("(P154/4) sosyal giris dugmeleri", () => {
  it("YAPILANDIRILMAMISSA hicbir sey cizilmez", async () => {
    taklit([]);
    ciz(() => createElement(SosyalGiris, { niyet: "giris" as const }));
    // Ayrac ("veya") da cizilmemeli: bos bir ayrac, olmayan bir secenek
    // varmis izlenimi verirdi.
    await waitFor(() => expect(screen.queryByText("veya")).toBeNull());
    expect(screen.queryAllByRole("button")).toEqual([]);
  });

  it("ACIK saglayicilar dugme olur", async () => {
    taklit(["google", "apple"]);
    ciz(() => createElement(SosyalGiris, { niyet: "giris" as const }));
    expect(await screen.findByRole("button", { name: /Google/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Apple/ })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Microsoft/ })).toBeNull();
  });

  it("NIYET saglayiciya gidilmeden ONCE yazilir", async () => {
    const c = taklit(["google"]);
    ciz(() => createElement(SosyalGiris, { niyet: "bagla" as const }));
    await userEvent.click(await screen.findByRole("button", { name: /Google/ }));

    await waitFor(() =>
      expect(c.some((x) => x.url.includes("/baslat/google"))).toBe(true),
    );
    expect(sessionStorage.getItem(OAUTH_NIYET)).toBe("bagla");
  });

  it("YUZEY govdede gider", async () => {
    const c = taklit(["google"]);
    ciz(() =>
      createElement(SosyalGiris, { niyet: "giris" as const, yuzey: "mobil" as const }),
    );
    await userEvent.click(await screen.findByRole("button", { name: /Google/ }));
    await waitFor(() => {
      const b = c.find((x) => x.url.includes("/baslat/"));
      expect(b?.body).toEqual({ yuzey: "mobil" });
    });
  });

  it("LISTE ALINAMAZSA sessizce cizilmez (parola girisi etkilenmez)", async () => {
    taklit(null);
    ciz(() => createElement(SosyalGiris, { niyet: "giris" as const }));
    await waitFor(() => expect(screen.queryAllByRole("button")).toEqual([]));
  });
});
