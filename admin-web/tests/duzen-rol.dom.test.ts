// @vitest-environment jsdom
// (P126.7) CEREZDEN MENUYE — korumali duzen rolu SUNUCUDA cozuyor mu?
//
// Zincirin bu halkasi kirilirsa hicbir sey "bozulmaz": kabuk `/api/me`ye
// sorar ve menu bir kare GECIKMEYLE dogru gelir. Yani hata SESSIZDIR —
// tam olarak bir testin yakalamasi gereken tur. Olculen sey: ilk cizimde
// menu ZATEN dogru.
import { screen } from "@testing-library/react";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { ACCESS_COOKIE } from "@/lib/cookies";
import { tokenRolu } from "@/lib/rol-token";

import { ciz, fetchSahtele } from "./yardimci";

/** Imzasiz sahte JWT — govde okunuyor, imza DOGRULANMIYOR (bkz. rol-token). */
function jwt(govde: Record<string, unknown>): string {
  const b64 = Buffer.from(JSON.stringify(govde)).toString("base64url");
  return `sahte.${b64}.imza`;
}

const cerezler = new Map<string, string>();
let konak = "app.xn--ynetiyor-n4a.com";
vi.mock("next/headers", () => ({
  cookies: () => ({
    get: (ad: string) => {
      const value = cerezler.get(ad);
      return value === undefined ? undefined : { name: ad, value };
    },
  }),
  // (P126 sonrasi) duzen YUZEYI de sunucuda coziyor: `Host` basligi.
  headers: () => ({
    get: (ad: string) => (ad.toLowerCase() === "host" ? konak : null),
  }),
}));
vi.mock("next/navigation", () => ({
  usePathname: () => "/profil",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
}));

async function cizDuzen() {
  fetchSahtele({});
  const { default: Duzen } = await import("@/app/(protected)/layout");
  // ASENKRON SUNUCU BILESENI: React'e uclu olarak veremeyiz (Promise
  // cocuk olarak cizilemez); once CAGIRIP donen agaci cizeriz — sunucunun
  // yaptigi da tam olarak budur.
  const agac = await Duzen({ children: null });
  ciz(() => agac);
}

function menuAdlari(): string[] {
  return screen
    .getAllByRole("link")
    // (P132) "İçeriğe atla" MENU OGESI DEGILDIR — logo gibi kabugun
    // sabit parcasidir ve erisilebilirlik icin vardir. Menu sayimina
    // katmak, bos menu beklentisini yanlis yere dusururdu.
    .filter((a) => a.getAttribute("aria-label") !== "Yönetio")
    .filter((a) => (a.getAttribute("href") ?? "") !== "#icerik")
    .map((a) => a.textContent?.trim() ?? "");
}

afterEach(() => {
  cerezler.clear();
  vi.restoreAllMocks();
});

describe("tokenRolu", () => {
  it("govdedeki `role` okunur", () => {
    expect(tokenRolu(jwt({ role: "security" }))).toBe("security");
  });

  it("base64URL govdesi (`-`/`_` iceren) DOGRU cozulur", () => {
    // Middleware Edge'de calisiyor; orada `Buffer` yok, `atob` var ve `atob`
    // base64url'i KENDILIGINDEN cozmez. `-`/`_` cevrilmezse govde bozulur ve
    // rol `null` doner — yani rol kapisi SESSIZCE devre disi kalirdi.
    // Bu ornek gercekten `_` iceriyor (govdedeki `?` karakterinden).
    const govde = { role: "resident", ad: "Zöe?" };
    const token = jwt(govde);
    expect(token.split(".")[1]).toMatch(/[-_]/);
    expect(tokenRolu(token)).toBe("resident");
  });

  it("BOZUK/eksik token `null` doner (cokmez)", () => {
    expect(tokenRolu(undefined)).toBeNull();
    expect(tokenRolu("")).toBeNull();
    expect(tokenRolu("tek-parca")).toBeNull();
    expect(tokenRolu(jwt({}))).toBeNull();
    expect(tokenRolu(jwt({ role: 42 }))).toBeNull();
  });
});

describe("korumali duzen", () => {
  it("cerezdeki rol ILK CIZIMDE menuye yansir", async () => {
    // (P129) Olcum rolu `resident`ten `denetci`ye cevrildi: `app.*`
    // artik yonetici + denetci yuzeyidir ve sakinin menusu BOSTUR —
    // bos menu ile "cerez okunmadi" ayirt edilemezdi, yani test
    // olcmek istedigi seyi olcmez hâle gelirdi.
    cerezler.set(ACCESS_COOKIE, jwt({ role: "denetci" }));
    await cizDuzen();
    // `/api/me` yaniti gelmeden, tek cizimde dogru menu.
    expect(menuAdlari()).toContain("Rapor motoru");
    expect(menuAdlari()).not.toContain("Kullanıcılar");
  });

  it("CEREZ YOKSA menu bos baslar (sizinti yok)", async () => {
    await cizDuzen();
    expect(menuAdlari()).toEqual([]);
  });
});
