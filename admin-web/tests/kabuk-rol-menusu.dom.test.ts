// @vitest-environment jsdom
// (P126.7) KABUK MENUSU ROLE GORE CIZILIYOR MU?
//
// `rol-menusu.test.ts` KUMEYI olcuyor; bu dosya CIZIMI olcuyor — ikisi ayri
// hata sinifi. Kume dogru olup kabugun onu okumamasi (ya da bir gun
// suzgecin kaldirilmasi) mumkundur ve o durumda sakin yine yonetim menusunu
// gorurdu.
import { fireEvent, screen, waitFor } from "@testing-library/react";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { AppShell } from "@/components/AppShell";

import { ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  usePathname: () => "/profil",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  // (P154 / Asama 7.1) Menu artik ayni rotanin ALT GORUNUMLERINI tasiyor
  // (`/finans?tip=gelir`); kabuk aktif satiri bulmak icin sorguyu da
  // okuyor. Sahte olmadan `useSearchParams` tanimsiz doner ve kabuk cizim
  // aninda patlar.
  useSearchParams: () => new URLSearchParams(),
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
/**
 * (P133.1) MENU BOLUMLU cizilir.
 *
 * Bu dosyanin olctugu sey ROL KAPISIDIR ("sakin yonetim menusunu gormez"),
 * gorunurlugun kac tiklama uzakta oldugu degil. Bu yuzden sayim ONCESINDE
 * her bolum acilir — aksi hâlde test, rol kapisi bozulsa bile "zaten
 * kapaliydi" diye gecerdi.
 *
 * (P166 §1) "Daha fazla" ACMA ADIMI KALDIRILDI: o katman artik yok,
 * bolumler zaten acik baslar. Dongu yine de duruyor cunku kullanici bir
 * bolumu KENDI kapatabilir ve test o durumda da rol kapisini olcmeli.
 */
function tumBolumleriAc(): void {
  // Kapali bolumler: `aria-expanded="false"` tasiyan her baslik.
  //
  // (P160) TARAMA `nav` ICINE DARALTILDI. Eskiden EKRANDAKI her
  // `aria-expanded="false"` dugmesine tikliyordu; bildirim merkezi ust
  // barra eklenince onun ACILIR dugmesi de bu kaliba uydu, panel acildi
  // ve icindeki "Tumunu gor" baglantisi MENU SAYIMINA karisti — "sakine
  // menu bos cizilir" testi hatali kirmizi dondu.
  //
  // Dongunun AMACI zaten "katli MENU BOLUMLERINI ac"; bir bildirim
  // aciliri menu bolumu degildir. Kapsami daraltmak testi GEVSETMEZ,
  // kendi tanimina sadik kilar — ve menu disi bir dugmenin sayimi
  // kirletmesini yapisal olarak imkansizlastirir.
  let guvenlik = 0;
  for (;;) {
    const kapali = screen
      .queryAllByRole("navigation")
      .flatMap((n) => [...n.querySelectorAll<HTMLElement>("button")])
      .filter((b) => b.getAttribute("aria-expanded") === "false");
    if (kapali.length === 0 || guvenlik++ > 20) break;
    for (const b of kapali) fireEvent.click(b);
  }
}

function menuAdlari(): string[] {
  tumBolumleriAc();
  const baglantilar = screen.queryAllByRole("link");
  if (baglantilar.length === 0) return [];
  return baglantilar
    // (P132) "İçeriğe atla" MENU OGESI DEGILDIR — logo gibi kabugun
    // sabit parcasidir ve erisilebilirlik icin vardir. Menu sayimina
    // katmak, bos menu beklentisini yanlis yere dusururdu.
    .filter((a) => a.getAttribute("aria-label") !== "Yönetiyor")
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
    // (P167 §1.7) "Profilim" ARTIK KENAR CUBUGUNDA DEGIL — sag ust
    // kullanici menusune tasindi. Sayfa kaybolmadi, YERI degisti; bu
    // yuzden burada YOKLUGU olculuyor, gorunurlugu ise asagidaki
    // "hesap menusu" testinde.
    expect(adlar).not.toContain("Profilim");
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
    const logo = screen.getAllByLabelText("Yönetiyor")[0];
    expect(logo).toHaveAttribute("href", "/raporlar");
  });

  it("LOGO yonetimde PANO'ya gider", () => {
    ciz(Kabuk("yonetici"));
    expect(screen.getAllByLabelText("Yönetiyor")[0]).toHaveAttribute(
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

  it("ROL BILINIYORSA menu AGA HIC SORMADAN dogru cizilir", () => {
    // (P167 §1.7) ESKI OLCUM: "`/api/me`ye HIC gidilmez". O olcum artik
    // yanlis soruyu soruyor — sag ust kullanici menusu ADI ve AVATARI
    // icin `/api/me`yi CAGIRMAK ZORUNDA. Korunmasi gereken sey istegin
    // yoklugu degil, ROLUN AGDAN OGRENILMEMESI: cerezde rol varken menu
    // ilk karede tam olmali.
    //
    // Bu yuzden fetch HIC COZULMEYEN bir soz doner. Menu yine de eksiksiz
    // ciziliyorsa, kume yalnizca cerezden gelmis demektir — `useRol`
    // bir gun kosulsuz istek atmaya baslarsa bu test kirmizi doner.
    tesisKonagi();
    globalThis.fetch = (() => new Promise(() => {})) as unknown as typeof fetch;
    ciz(Kabuk("yonetici"));
    const adlar = menuAdlari();
    expect(adlar).toContain("Kullanıcılar");
    expect(adlar).toContain("Kameralar");
  });

  it("(P167 §1.7) HESAP MENUSU sag ustte ve profil bolumlerini acar", () => {
    tesisKonagi();
    fetchSahtele({ "/api/me": { ad: "Kerem D", email: null, avatar_url: null } });
    ciz(Kabuk("yonetici"));
    // Kenar cubugu iki kez cizildigi icin ust bar da iki kopyadir
    // (masaustu seridi + mobil baslik) — ilkine tiklamak yeterli.
    const dugme = screen.getAllByRole("button", { name: "Hesabım" })[0];
    fireEvent.click(dugme);
    const menu = screen.getAllByRole("menu", { name: "Hesabım" })[0];
    const adlar = [...menu.querySelectorAll("a")].map((a) => a.textContent);
    expect(adlar).toContain("Hesap bilgileri");
    expect(adlar).toContain("Güvenlik ve giriş");
    expect(adlar).toContain("Bildirim ayarları");
    expect(adlar).toContain("Şifre değiştir");
    expect(adlar).toContain("Hesabımı sil");
    // Cikis MENUNUN ICINDE bir dugme (baglanti degil — bir sayfaya
    // gitmiyor, bir eylem yapiyor).
    expect(
      [...menu.querySelectorAll("button")].map((b) => b.textContent),
    ).toContain("Çıkış yap");
  });
});
