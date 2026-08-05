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
}));

function Kabuk(rol = "yonetici") {
  return () =>
    createElement(AppShell, { children: null, rol, yuzey: "tesis" as const });
}

/** Kenar cubugu masaustu + cekmece olarak IKI kez cizilir. */
function bolumDugmesi(ad: RegExp) {
  return screen.getAllByRole("button", { name: ad })[0];
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

describe("(P133.1) bolum acma/kapama", () => {
  it("ACILISTA yalniz bulunulan sayfanin bolumu acik", () => {
    ciz(Kabuk());
    // `/dashboard` Guvenlik bolumunde.
    expect(menuHrefleri()).toContain("/dashboard");
    expect(menuHrefleri()).toContain("/shifts");
    // Finans bolumu KAPALI: ogeleri DOM'a hic girmemis olmali.
    expect(menuHrefleri()).not.toContain("/dues");
  });

  it("BASLIGA tiklayinca acilir ve kapanir", () => {
    ciz(Kabuk());
    expect(menuHrefleri()).not.toContain("/dues");
    fireEvent.click(bolumDugmesi(/finans/i));
    expect(menuHrefleri()).toContain("/dues");
    fireEvent.click(bolumDugmesi(/finans/i));
    expect(menuHrefleri()).not.toContain("/dues");
  });

  it("KATLI bolumler 'Daha fazla'nin ardinda", () => {
    ciz(Kabuk());
    // Yonetim katlidir: basligi bile gorunmemeli.
    expect(screen.queryAllByRole("button", { name: /yönetim/i })).toEqual([]);
    fireEvent.click(screen.getAllByRole("button", { name: /daha fazla/i })[0]);
    expect(screen.getAllByRole("button", { name: /yönetim/i }).length).toBeGreaterThan(0);
  });

  it("KARAR SAKLANIR — yeniden cizimde acik kalir", () => {
    const ilk = ciz(Kabuk());
    fireEvent.click(bolumDugmesi(/finans/i));
    expect(menuHrefleri()).toContain("/dues");
    ilk.unmount();

    ciz(Kabuk());
    expect(menuHrefleri(), "kayit okunmadi").toContain("/dues");
  });

  it("GEZINME aktif bolumu ACAR (kapaliyken bile)", () => {
    // Kullanici "Daha fazla"dan Kullanicilar'a gitti; hedef sayfada
    // menude KENDI satirini gormeli, yoksa nerede oldugunu kaybeder.
    ciz(Kabuk());
    expect(menuHrefleri()).not.toContain("/users");
    yol.simdiki = "/users";
    const tekrar = ciz(Kabuk());
    expect(menuHrefleri()).toContain("/users");
    tekrar.unmount();
  });

  it("BOZUK KAYIT menuyu kirmaz", () => {
    localStorage.setItem("yonetio.menu.durum", "{bu gecerli json degil");
    ciz(Kabuk());
    // Varsayilana dusulur: bulunulan sayfanin bolumu acik.
    expect(menuHrefleri()).toContain("/dashboard");
  });

  it("DEPOLAMA YAZILAMAZSA (gizli sekme) menu yine calisir", () => {
    const asil = Storage.prototype.setItem;
    Storage.prototype.setItem = () => {
      throw new DOMException("QuotaExceededError");
    };
    try {
      ciz(Kabuk());
      fireEvent.click(bolumDugmesi(/finans/i));
      // Acilma CALISIR; yalnizca hatirlanmaz.
      expect(menuHrefleri()).toContain("/dues");
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
    expect(finans).toHaveAttribute("aria-expanded", "false");
    fireEvent.click(finans);
    expect(bolumDugmesi(/finans/i)).toHaveAttribute("aria-expanded", "true");
  });

  it("KAPALI bolumun ogeleri ODAKLANILABILIR DEGIL (DOM'da yok)", () => {
    // "Gorunmez ama Tab ile gezilebilir" satir, klavye kullanicisi icin
    // en can sikici hatadir: odak bos yere gider.
    ciz(Kabuk());
    expect(screen.queryByRole("link", { name: /tahakkuk/i })).toBeNull();
  });

  it("ACILIR OK dekoratiftir (ekran okuyucuya okunmaz)", () => {
    const { container } = ciz(Kabuk());
    const okler = container.querySelectorAll("svg[aria-hidden='true']");
    expect(okler.length).toBeGreaterThan(0);
  });
});
