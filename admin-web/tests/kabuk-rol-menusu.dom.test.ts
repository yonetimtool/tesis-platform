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

// (P126 sonrasi) YUZEY ARTIK UCLUDAN GELIR — duzen onu `Host` basligindan
// cozuyor. Eskiden `window.location.host` yamalaniyordu; o yol sunucu
// ciziminde calismiyordu ve ilk kare yanlis menuyle boyaniyordu.
function Kabuk(rol: string | null) {
  return () =>
    createElement(AppShell, { children: null, rol, yuzey: "tesis" as const });
}

/** Eski cagri yerlerini bozmamak icin: artik yapacak bir sey yok. */
function tesisKonagi() {}

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
    // (P132) "İçeriğe atla" MENU OGESI DEGILDIR — logo gibi kabugun
    // sabit parcasidir ve erisilebilirlik icin vardir. Menu sayimina
    // katmak, bos menu beklentisini yanlis yere dusururdu.
    .filter((a) => a.getAttribute("aria-label") !== "Yönetio")
    .filter((a) => (a.getAttribute("href") ?? "") !== "#icerik")
    .map((a) => a.textContent?.trim() ?? "")
    .filter((s) => s.length > 0);
}

afterEach(() => vi.restoreAllMocks());

describe("app.* menusu role gore", () => {
  it("(P129) MOBIL-YALNIZ ROLLERE MENU BOS cizilir", () => {
    // `app.*` artik yonetici + denetci yuzeyidir; bu roller giriste
    // kesiliyor. Elinde gecerli cerez kalmis biri girse bile menu BOS
    // olmali — yariya kadar dolu bir kabuk "sistem bozuk" demektir.
    for (const rol of ["resident", "security", "tesis_gorevlisi"]) {
      const { unmount } = ciz(Kabuk(rol));
      expect(menuAdlari(), rol).toEqual([]);
      unmount();
    }
  });

  it("(P129) DENETCI: raporlari gorur, para YAZAN sayfalari GORMEZ", () => {
    tesisKonagi();
    ciz(Kabuk("denetci"));
    const adlar = menuAdlari();
    expect(adlar).toContain("Rapor motoru");
    expect(adlar).toContain("Profilim");
    expect(adlar).not.toContain("Finans");
    expect(adlar).not.toContain("Tahakkuk");
    expect(adlar).not.toContain("Kullanıcılar");
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

  it("LOGO hedefi ROLE gore — denetci panoya yollanmaz", () => {
    ciz(Kabuk("denetci"));
    const logo = screen.getAllByLabelText("Yönetio")[0];
    expect(logo).toHaveAttribute("href", "/raporlar");
  });

  it("LOGO yonetimde PANO'ya gider", () => {
    ciz(Kabuk("yonetici"));
    expect(screen.getAllByLabelText("Yönetio")[0]).toHaveAttribute(
      "href",
      "/dashboard",
    );
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
    fetchSahtele({ "/api/me": { role: "denetci" } });
    ciz(Kabuk(null));
    await waitFor(() => expect(menuAdlari()).toContain("Rapor motoru"));
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
