// @vitest-environment jsdom
// (P126.7) KABUK MENUSU ROLE GORE CIZILIYOR MU?
//
// `rol-menusu.test.ts` KUMEYI olcuyor; bu dosya CIZIMI olcuyor — ikisi ayri
// hata sinifi. Kume dogru olup kabugun onu okumamasi (ya da bir gun
// suzgecin kaldirilmasi) mumkundur ve o durumda sakin yine yonetim menusunu
// gorurdu.
import { screen, waitFor } from "@testing-library/react";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { AppShell } from "@/components/AppShell";

import { ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  usePathname: () => "/profil",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
}));

/** `app.*` konagi: kabuk yuzeyi ADRESTEN turetiyor. */
function tesisKonagi() {
  Object.defineProperty(window, "location", {
    configurable: true,
    value: { ...window.location, host: "app.xn--ynetiyor-n4a.com" },
  });
}

function Kabuk(rol: string | null) {
  return () => createElement(AppShell, { children: null, rol });
}

/**
 * Menudeki baglanti etiketleri.
 *
 * Kenar cubugu masaustu + cekmece olarak IKI kez ciziliyor (yinelenen adlar
 * beklenir). LOGO baglantisi disarida birakilir: o menu ogesi degil, kok
 * hedefidir ve rolden bagimsiz her zaman durur.
 */
function menuAdlari(): string[] {
  return screen
    .getAllByRole("link")
    .filter((a) => a.getAttribute("aria-label") !== "Yönetio")
    .map((a) => a.textContent?.trim() ?? "")
    .filter((s) => s.length > 0);
}

afterEach(() => vi.restoreAllMocks());

describe("app.* menusu role gore", () => {
  it("SAKIN: kendi sayfalarini gorur, yonetim sayfalarini GORMEZ", () => {
    tesisKonagi();
    ciz(Kabuk("resident"));
    const adlar = menuAdlari();
    expect(adlar).toContain("Aidatım");
    expect(adlar).toContain("Taleplerim");
    expect(adlar).toContain("Profilim");
    expect(adlar).not.toContain("Kullanıcılar");
    expect(adlar).not.toContain("Finans");
    expect(adlar).not.toContain("Tahakkuk");
    expect(adlar).not.toContain("Ziyaretçiler");
  });

  it("YONETICI: yonetim seti var, sakinin kendi kayitlari YOK", () => {
    tesisKonagi();
    ciz(Kabuk("yonetici"));
    const adlar = menuAdlari();
    expect(adlar).toContain("Kullanıcılar");
    expect(adlar).toContain("Finans");
    expect(adlar).toContain("Kameralar");
    expect(adlar).not.toContain("Aidatım");
    // Uc ona 403 doner (matris) — menude olmamali.
    expect(adlar).not.toContain("Araç geçişleri");
  });

  it("GUVENLIK: kapi seti var, yonetim seti YOK", () => {
    tesisKonagi();
    ciz(Kabuk("security"));
    const adlar = menuAdlari();
    expect(adlar).toContain("Ziyaretçiler");
    expect(adlar).toContain("Kargolar");
    expect(adlar).toContain("Araç geçişleri");
    expect(adlar).toContain("Görevlerim");
    expect(adlar).not.toContain("Finans");
    expect(adlar).not.toContain("Aidatım");
  });

  it("TESIS GOREVLISI: yalniz kendi seti", () => {
    tesisKonagi();
    ciz(Kabuk("tesis_gorevlisi"));
    const adlar = menuAdlari();
    expect(adlar).toContain("Görevlerim");
    expect(adlar).not.toContain("Ziyaretçiler");
    expect(adlar).not.toContain("Kullanıcılar");
  });

  it("ROL BILINMIYORSA menu BOS cizilir (sizinti yok)", () => {
    tesisKonagi();
    // `/api/me` de yanit vermezse hicbir baglanti olmamali.
    fetchSahtele({});
    ciz(Kabuk(null));
    expect(menuAdlari()).toEqual([]);
  });

  it("ROL BILINMIYORSA `/api/me`den ogrenilir (cerez dustugunde toparlanir)", async () => {
    tesisKonagi();
    fetchSahtele({ "/api/me": { role: "resident" } });
    ciz(Kabuk(null));
    await waitFor(() => expect(menuAdlari()).toContain("Aidatım"));
    expect(menuAdlari()).not.toContain("Kullanıcılar");
  });

  it("ROL BILINIYORSA `/api/me`ye HIC gidilmez (gereksiz istek yok)", () => {
    tesisKonagi();
    // `fetchSahtele` cagrilari geri vermiyor; burada kendi kaydimizi tutuyoruz.
    const cagrilar: string[] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      cagrilar.push(String(girdi));
      return new Response("{}", {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }) as typeof fetch;
    ciz(Kabuk("yonetici"));
    expect(cagrilar.filter((u) => u.includes("/api/me"))).toEqual([]);
  });
});
