// @vitest-environment jsdom
// (P211 §1) COK TESISLI YONETICI — SSO'da TESIS ID SORULMAZ, SECIM SUNULUR.
//
// =========================================================================
// OLCULEN CIKMAZ
// =========================================================================
// Ayni dogrulanmis e-posta birden cok tesiste yoneticiyse backend
// eslesmeyi "tekil degil" sayip `baglama_gerekli` donuyordu; web de bu
// duruma TESIS ID formu ciziyordu. Yani tam da hicbir kullanicinin
// ezberlemedigi kodu, EN COK tesisi olan kisiden istiyorduk.
//
// Yeni davranis: `durum=tesis_secimi` -> tesis ADLARI ile secim; secilen
// tesis `POST /api/auth/oauth/tesis-sec` ile jetona cevrilir.
//
// Taklit HTTP KATMANINDA (P200 dersi): sayfa gercek fetch cagrilarini
// yapar, gonderilen govde olculur.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import { ciz } from "./yardimci";

const replace = vi.fn();
let arama = new URLSearchParams();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
  usePathname: () => "/giris/oauth",
  useSearchParams: () => arama,
}));

type Cagri = { url: string; govde: Record<string, unknown> };

function taklit(yanit: (url: string) => Response): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    return yanit(url);
  }) as typeof fetch;
  return cagrilar;
}

function json(govde: unknown, durum = 200) {
  return new Response(JSON.stringify(govde), {
    status: durum,
    headers: { "Content-Type": "application/json" },
  });
}

const SECIM = {
  durum: "tesis_secimi",
  saglayici: "google",
  eposta: "kerem@ornek.com",
  secim_jetonu: "secim-1",
  tesisler: [
    { tenant_id: "11111111-1111-1111-1111-111111111111", ad: "Mavi Konaklari", slug: "mavi" },
    { tenant_id: "22222222-2222-2222-2222-222222222222", ad: "Yesil Sitesi", slug: "yesil" },
  ],
};

beforeEach(() => {
  arama = new URLSearchParams({ oauth: "sonuc-1" });
  replace.mockClear();
  sessionStorage.clear();
});

afterEach(() => {
  vi.restoreAllMocks();
  sessionStorage.clear();
});

async function oauthSayfasi() {
  const mod = await import("@/app/giris/oauth/page");
  return ciz(mod.default);
}

it("`tesis_secimi` -> tesis ADLARI cizilir, TESIS ID istenmez", async () => {
  taklit((url) => (url.includes("/oauth/sonuc") ? json(SECIM) : json({})));

  await oauthSayfasi();

  await screen.findByText("Mavi Konaklari");
  expect(screen.getByText("Yesil Sitesi")).toBeTruthy();
  // Kusur geri gelirse burasi kirilir: eski dal Tesis ID formu cizerdi.
  expect(document.querySelector("[data-test='oauth-tesis-kodu']")).toBeNull();
  expect(replace).not.toHaveBeenCalled();
});

it("secilen tesis + jeton `tesis-sec` ucuna GONDERILIR, oturum acilir", async () => {
  const cagrilar = taklit((url) =>
    url.includes("/oauth/sonuc") ? json(SECIM) : json({ durum: "giris" }),
  );

  await oauthSayfasi();
  await userEvent.click(await screen.findByText("Yesil Sitesi"));

  await waitFor(() => expect(replace).toHaveBeenCalledWith("/"));
  const son = cagrilar[cagrilar.length - 1];
  expect(son.url).toBe("/api/auth/oauth/tesis-sec");
  expect(son.govde).toEqual({
    secim_jetonu: "secim-1",
    tenant_id: "22222222-2222-2222-2222-222222222222",
  });
});

it("`tesis-sec` reddederse HATA gosterilir, oturum acilmis SAYILMAZ", async () => {
  taklit((url) =>
    url.includes("/oauth/sonuc")
      ? json(SECIM)
      : json({ error: { message: "Bu tesise uyeliginiz yok." } }, 403),
  );

  await oauthSayfasi();
  await userEvent.click(await screen.findByText("Mavi Konaklari"));

  await screen.findByText("Bu tesise uyeliginiz yok.");
  expect(replace).not.toHaveBeenCalled();
});

it("TEK tesisli yonetici SECIM GORMEZ (gerileme yok)", async () => {
  taklit((url) =>
    url.includes("/oauth/sonuc") ? json({ durum: "giris" }) : json({}),
  );

  await oauthSayfasi();

  await waitFor(() => expect(replace).toHaveBeenCalledWith("/"));
  expect(document.querySelector("[data-test='oauth-tesis-secimi']")).toBeNull();
});
