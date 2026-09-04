// @vitest-environment jsdom
// (P201) SAGLAYICIDAN DONUS — DURUMUN TASINDIGI YER.
//
// =========================================================================
// OLCULEN CIKMAZ (prod)
// =========================================================================
// Google ile yonetici kaydi donguye giriyordu. Iki ayri kirilganlik
// vardi ve ikisi de "durumun kaybolmasi" seklinde gorunuyordu:
//
//   1. Callback `?oauth=<id>` ile `/kayit`a donuyorsa, o sayfa
//      parametreyi OKUMUYORDU (`sessionStorage` bekliyordu). Sonuc
//      kimligi hicbir yerde tuketilmiyor, kullanici kayda BASTAN
//      basliyordu.
//   2. `/giris/oauth` niyeti YALNIZ `sessionStorage`dan okuyordu.
//      `sessionStorage` KOKEN BASINADIR: donus baska konaga duserse
//      (ya da kullanici sekme degistirirse) kayit niyeti "giris"
//      sanilip kullaniciya TESIS ID soruluyordu.
//
// Bu dosya ikisini de kilitler.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import { OAUTH_NIYET, kayitSosyalSonucOku } from "@/components/SosyalGiris";

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

beforeEach(() => {
  arama = new URLSearchParams();
  replace.mockClear();
  sessionStorage.clear();
});

afterEach(() => {
  vi.restoreAllMocks();
  sessionStorage.clear();
});

// ===================== 1) /kayit?oauth= DEVREDER ======================= //

it("/kayit `?oauth=` ile acilirsa sonucu COZEN sayfaya DEVREDER", async () => {
  // Kusur olsaydi sayfa bombos acilir, `POST /auth/oauth/sonuc` HIC
  // cagrilmaz ve kullanici kayda BASTAN baslardi — prod izinde
  // `303` ardindan yalnizca `saglayicilar` gorunmesinin sebebi buydu.
  const gidilen: string[] = [];
  const yerine = vi.fn((adres: string) => void gidilen.push(adres));
  Object.defineProperty(window, "location", {
    configurable: true,
    value: {
      ...window.location,
      search: "?oauth=sonuc-123",
      replace: yerine,
    },
  });
  taklit(() => json({ saglayicilar: [] }));

  const mod = await import("@/app/kayit/page");
  ciz(mod.default);

  await waitFor(() => expect(gidilen).toHaveLength(1));
  expect(gidilen[0]).toBe("/giris/oauth?oauth=sonuc-123");
});

// ============ 2) /giris/oauth NIYETI SUNUCUDAN DA OKUR ================= //

async function oauthSayfasi() {
  const mod = await import("@/app/giris/oauth/page");
  return ciz(mod.default);
}

it("niyet YEREL KOPYADA YOKKEN de `durum=kayit` KAYIT dalina gider", async () => {
  // sessionStorage BOS — koken degistiyse gercekte olan budur.
  arama = new URLSearchParams({ oauth: "sonuc-123" });
  const cagrilar = taklit((url) =>
    url.includes("/oauth/sonuc")
      ? json({
          durum: "kayit",
          saglayici: "google",
          ad: "Kerem Yonetici",
          baglama_jetonu: "baglama-1",
        })
      : json({}),
  );

  await oauthSayfasi();

  await waitFor(() => expect(replace).toHaveBeenCalledWith("/kayit"));
  // Dogru uc cagrildi ve sonuc kimligi gonderildi.
  expect(cagrilar[0].url).toBe("/api/auth/oauth/sonuc");
  expect(cagrilar[0].govde).toEqual({ sonuc_id: "sonuc-123" });
  // Kayit sayfasinin devam edebilmesi icin durum BIRAKILDI.
  const s = kayitSosyalSonucOku();
  expect(s?.baglamaJetonu).toBe("baglama-1");
  expect(s?.rol).toBe("yonetici");
  expect(s?.ad).toBe("Kerem Yonetici");
});

it("niyet YEREL KOPYADA VARKEN de ayni sonuc (gerileme yok)", async () => {
  arama = new URLSearchParams({ oauth: "sonuc-123" });
  sessionStorage.setItem(OAUTH_NIYET, "kayit");
  taklit((url) =>
    url.includes("/oauth/sonuc")
      ? json({ durum: "kayit", saglayici: "google", baglama_jetonu: "b-2" })
      : json({}),
  );

  await oauthSayfasi();

  await waitFor(() => expect(replace).toHaveBeenCalledWith("/kayit"));
  expect(kayitSosyalSonucOku()?.baglamaJetonu).toBe("b-2");
});

it("KAYIT niyetinde TESIS ID formu CIKMAZ", async () => {
  // Kullanicinin bildirdigi belirti tam olarak buydu: "Google ile devam
  // et deyince benden Tesis ID isteniyor". Yeni tesis acan bir
  // yoneticiden Tesis ID ISTENMEZ — o kimligi sistem uretir.
  arama = new URLSearchParams({ oauth: "sonuc-123" });
  taklit((url) =>
    url.includes("/oauth/sonuc")
      ? json({ durum: "kayit", saglayici: "google", baglama_jetonu: "b-3" })
      : json({}),
  );

  await oauthSayfasi();
  await waitFor(() => expect(replace).toHaveBeenCalledWith("/kayit"));
  expect(screen.queryByLabelText(/tesis/i)).toBeNull();
});

it("GIRIS niyetinde `baglama_gerekli` -> KAYDA devreder (TESIS ID SORULMAZ)", async () => {
  // (P211-ek3) DEGISEN DAVRANIS. P191'de burasi Tesis ID soruyordu;
  // kural artik mobille AYNI: Tesis ID YALNIZ kayit akisinda sorulur.
  // Jeton `/kayit`a tasinir, saglayici akisi TEKRARLANMAZ.
  arama = new URLSearchParams({ oauth: "sonuc-9" });
  taklit((url) =>
    url.includes("/oauth/sonuc")
      ? json({
          durum: "baglama_gerekli",
          saglayici: "google",
          eposta: "kerem@ornek.com",
          baglama_jetonu: "b-9",
        })
      : json({ saglayicilar: [] }),
  );

  await oauthSayfasi();

  await waitFor(() => expect(replace).toHaveBeenCalledWith("/kayit"));
  const s = kayitSosyalSonucOku();
  expect(s?.baglamaJetonu).toBe("b-9");
  // ROL BOS: giristen gelindi, rolu kullanici SECER (kayit ekraninin
  // rol adimi). Varsayilan bir rol yazmak, kisiyi yanlis kayit turune
  // sokmanin sessiz yoluydu.
  expect(s?.rol).toBe("");
  expect(screen.queryByLabelText(/tesis/i)).toBeNull();
});
