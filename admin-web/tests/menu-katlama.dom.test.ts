// @vitest-environment jsdom
// (P133.1) BOLUM ACMA/KAPAMA — cizim, kaliciklik ve klavye.
//
// `menu-gruplari.test.ts` VERIYI olcuyor; burada olculen sey DAVRANIS:
// bolum gercekten aciliyor mu, karar SAKLANIYOR mu, klavyeyle
// gezilebiliyor mu, ve depolama erisilemezse menu KIRILIYOR mu.
//
// EN PAHALI SONUC: kullanicinin her sayfa acilisinda bolumleri yeniden
// acmak zorunda kalmasi — 28 satiri 10'a indirmenin bedeli bu olsaydi
// degistirme zahmete degmezdi.
import { fireEvent, screen } from "@testing-library/react";
import { createElement } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { AppShell } from "@/components/AppShell";

import { ciz } from "./yardimci";

const yol = { simdiki: "/dashboard" };
vi.mock("next/navigation", () => ({
  usePathname: () => yol.simdiki,
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  // (P154 / Asama 7.1) Menu artik ayni rotanin ALT GORUNUMLERINI tasiyor
  // (`/finans?tip=gelir`); kabuk aktif satiri bulmak icin sorguyu da
  // okuyor. Sahte olmadan `useSearchParams` tanimsiz doner ve kabuk cizim
  // aninda patlar.
  useSearchParams: () => new URLSearchParams(),
}));

function Kabuk(rol = "yonetici") {
  return () =>
    createElement(AppShell, { children: null, rol, yuzey: "tesis" as const });
}

/** Kenar cubugu masaustu + cekmece olarak IKI kez cizilir. */
function bolumDugmesi(ad: RegExp) {
  return screen.getAllByRole("button", { name: ad })[0];
}

/**
 * Bolumu HER IKI kopyada cevirir.
 *
 * (P166 §1) Bu yardimci ZORUNLU hâle geldi: `menuHrefleri()` iki
 * kopyanin baglantilarini BIRLIKTE toplar. Varsayilan kapaliyken tek
 * kopyaya tiklamak yeterliydi ("acildi mi" sorusuna bir kopya cevap
 * verir); varsayilan ACIK olunca olculen sey "kapandi mi" oldu ve
 * kapanmayan ikinci kopya sonucu kirletiyor.
 */
function bolumCevir(ad: RegExp): void {
  for (const b of screen.getAllByRole("button", { name: ad })) fireEvent.click(b);
}

function menuHrefleri(): string[] {
  return screen
    .queryAllByRole("link")
    .map((a) => a.getAttribute("href") ?? "")
    .filter((h) => h && h !== "#icerik");
}

beforeEach(() => {
  yol.simdiki = "/dashboard";
  localStorage.clear();
});
afterEach(() => vi.restoreAllMocks());

describe("(P166 §1) TEK LISTE — 'Daha fazla' katmani yok", () => {
  it("ACILISTA TUM bolumler acik", () => {
    ciz(Kabuk());
    const h = menuHrefleri();
    // Guvenlik (bulunulan bolum) — eskiden de aciliyordu.
    expect(h).toContain("/dashboard");
    // Finans — eskiden KAPALIYDI.
    expect(h).toContain("/dues");
    // Eskiden "Daha fazla"nin ARDINDA olan dort bolumun ogeleri.
    expect(h).toContain("/users");
    expect(h).toContain("/announcements");
    expect(h).toContain("/tanimlar");
    expect(h).toContain("/finans?tip=gelir");
  });

  it("'Daha fazla' / 'Daha az' DUGMESI YOK", () => {
    ciz(Kabuk());
    expect(screen.queryAllByRole("button", { name: /daha fazla/i })).toEqual([]);
    expect(screen.queryAllByRole("button", { name: /daha az/i })).toEqual([]);
  });

  it("MENU KAYDIRILABILIR (gizleme yerine kaydirma)", () => {
    // Brief: "Liste uzarsa menu kaydirilabilir olsun; gizleme cozumu
    // kullanma." jsdom duzen hesaplamaz, olculen sey KURALIN VARLIGI.
    const { container } = ciz(Kabuk());
    const nav = container.querySelector("nav");
    expect(nav?.className).toContain("overflow-y-auto");
  });

  it("ESKI KAYIT gizli menuyu GERI GETIRMEZ", () => {
    // Surumlenmemis anahtar okunsaydi, eski `{acik:["guvenlik"]}` kaydi
    // olan kullanici yeni surumde yine tek bolum gorurdu.
    localStorage.setItem(
      "yonetio.menu.durum",
      JSON.stringify({ acik: ["guvenlik"], dahaFazla: false }),
    );
    ciz(Kabuk());
    expect(menuHrefleri()).toContain("/users");
  });
});

describe("(P133.1) bolum acma/kapama", () => {
  it("BASLIGA tiklayinca KAPANIR ve tekrar acilir", () => {
    // Katlama YETENEGI korundu: degisen sey varsayilan, kullanicinin
    // kendi karari degil.
    ciz(Kabuk());
    expect(menuHrefleri()).toContain("/dues");
    bolumCevir(/finans/i);
    expect(menuHrefleri()).not.toContain("/dues");
    bolumCevir(/finans/i);
    expect(menuHrefleri()).toContain("/dues");
  });

  it("KARAR SAKLANIR — yeniden cizimde kapali kalir", () => {
    const ilk = ciz(Kabuk());
    bolumCevir(/finans/i);
    expect(menuHrefleri()).not.toContain("/dues");
    ilk.unmount();

    ciz(Kabuk());
    expect(menuHrefleri(), "kayit okunmadi").not.toContain("/dues");
  });

  it("GEZINME aktif bolumu ACAR (kullanici kapatmis olsa bile)", () => {
    // Kullanici Yonetim'i kapatti, sonra Kullanicilar sayfasina gitti;
    // hedef sayfada menude KENDI satirini gormeli.
    const ilk = ciz(Kabuk());
    bolumCevir(/yönetim/i);
    expect(menuHrefleri()).not.toContain("/users");
    ilk.unmount();

    yol.simdiki = "/users";
    const tekrar = ciz(Kabuk());
    expect(menuHrefleri()).toContain("/users");
    tekrar.unmount();
  });

  it("BOZUK KAYIT menuyu kirmaz", () => {
    localStorage.setItem("yonetio.menu.durum.v2", "{bu gecerli json degil");
    ciz(Kabuk());
    // Varsayilana dusulur: hepsi acik.
    expect(menuHrefleri()).toContain("/dashboard");
    expect(menuHrefleri()).toContain("/users");
  });

  it("DEPOLAMA YAZILAMAZSA (gizli sekme) menu yine calisir", () => {
    const asil = Storage.prototype.setItem;
    Storage.prototype.setItem = () => {
      throw new DOMException("QuotaExceededError");
    };
    try {
      ciz(Kabuk());
      bolumCevir(/finans/i);
      // Kapanma CALISIR; yalnizca hatirlanmaz.
      expect(menuHrefleri()).not.toContain("/dues");
    } finally {
      Storage.prototype.setItem = asil;
    }
  });
});

describe("(P133.1) erisilebilirlik", () => {
  it("bolum basligi DUGME ve durumunu bildiriyor", () => {
    ciz(Kabuk());
    const finans = bolumDugmesi(/finans/i);
    expect(finans.tagName).toBe("BUTTON");
    // (P166 §1) ACIK baslar.
    expect(finans).toHaveAttribute("aria-expanded", "true");
    fireEvent.click(finans);
    expect(bolumDugmesi(/finans/i)).toHaveAttribute("aria-expanded", "false");
  });

  it("KULLANICI KAPATINCA ogeler ODAKLANILABILIR DEGIL (DOM'da yok)", () => {
    // "Gorunmez ama Tab ile gezilebilir" satir, klavye kullanicisi icin
    // en can sikici hatadir: odak bos yere gider.
    ciz(Kabuk());
    expect(menuHrefleri()).toContain("/dues");
    bolumCevir(/finans/i);
    expect(menuHrefleri()).not.toContain("/dues");
  });

  it("ACILIR OK dekoratiftir (ekran okuyucuya okunmaz)", () => {
    const { container } = ciz(Kabuk());
    const okler = container.querySelectorAll("svg[aria-hidden='true']");
    expect(okler.length).toBeGreaterThan(0);
  });
});
