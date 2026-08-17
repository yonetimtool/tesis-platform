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

describe("(P167 §1.2) ACILISTA TUM ANA BASLIKLAR KAPALI", () => {
  it("hicbir bolumun ogesi cizilmez; BAGIMSIZ sekme gorunur", () => {
    ciz(Kabuk());
    const h = menuHrefleri();
    // (P167 §1.3) OZET bir bolum degil, bagimsiz ust sekme — kapali
    // baslik kurali onu KAPSAMAZ ve ilk bakista gorunur olmali.
    expect(h).toContain("/dashboard");
    // (P167 §1.8) Kurulum sihirbazi alt cubukta, bolum disinda.
    expect(h).toContain("/kurulum");
    // Bolum ogelerinin HICBIRI yok: kullanici hangi basligi acacagini
    // secene kadar menu yedi satirlik bir icindekiler tablosudur.
    expect(h).not.toContain("/dues");
    expect(h).not.toContain("/users");
    expect(h).not.toContain("/announcements");
    expect(h).not.toContain("/units");
  });

  it("BASLIKLAR gorunur (gizlenen bir sey YOK)", () => {
    // Kapali olmak GIZLI olmak degildir: yedi ana baslik da ekranda,
    // tiklanabilir dugmeler olarak duruyor.
    ciz(Kabuk());
    // REGEX PARCALARI ASCII: JS'in `i` bayragi Turkce "I/i" ciftini
    // dogru esitlemez (`İ` -> `i` + birlesen nokta) ve /iletişim/i,
    // "Iletisim bolumunu ac" etiketini BULAMAZ. Ayirt edici ASCII
    // parcalar kullanildi.
    for (const ad of [/venlik/i, /tesis/i, /finans/i, /leti/i, /mlar/i, /netim/i]) {
      expect(screen.getAllByRole("button", { name: ad }).length).toBeGreaterThan(0);
    }
  });

  it("'Daha fazla' / 'Daha az' DUGMESI YOK", () => {
    ciz(Kabuk());
    expect(screen.queryAllByRole("button", { name: /daha fazla/i })).toEqual([]);
    expect(screen.queryAllByRole("button", { name: /daha az/i })).toEqual([]);
  });

  it("MENU KAYDIRILABILIR (uzun listede kirpilmaz)", () => {
    const { container } = ciz(Kabuk());
    const nav = container.querySelector("nav");
    expect(nav?.className).toContain("overflow-y-auto");
  });

  it("ESKI KAYIT (.v2) 'hepsi acik' halini GERI GETIRMEZ", () => {
    // P166'nin kayitlarinda sekiz bolumun hepsi listelidir. Surumlenmemis
    // bir anahtar okunsaydi, o kullanicilar degisikligi HIC gormezdi.
    localStorage.setItem(
      "yonetio.menu.durum.v2",
      JSON.stringify({ acik: ["guvenlik", "finans", "yonetim", "tanimlar"] }),
    );
    ciz(Kabuk());
    expect(menuHrefleri()).not.toContain("/users");
    expect(menuHrefleri()).not.toContain("/dues");
  });
});

describe("(P133.1) bolum acma/kapama", () => {
  it("BASLIGA tiklayinca ACILIR ve tekrar kapanir", () => {
    ciz(Kabuk());
    expect(menuHrefleri()).not.toContain("/dues");
    bolumCevir(/finans/i);
    expect(menuHrefleri()).toContain("/dues");
    bolumCevir(/finans/i);
    expect(menuHrefleri()).not.toContain("/dues");
  });

  it("KARAR SAKLANIR — yeniden cizimde ACIK kalir", () => {
    const ilk = ciz(Kabuk());
    bolumCevir(/finans/i);
    expect(menuHrefleri()).toContain("/dues");
    ilk.unmount();

    ciz(Kabuk());
    expect(menuHrefleri(), "kayit okunmadi").toContain("/dues");
  });

  it("GEZINME aktif bolumu ACAR (kullanici acmamis olsa bile)", () => {
    // Kullanici hicbir bolum acmadi ama komut paletinden Kullanicilar
    // sayfasina gitti; hedef sayfada menude KENDI satirini gormeli.
    yol.simdiki = "/users";
    ciz(Kabuk());
    expect(menuHrefleri()).toContain("/users");
  });

  it("BOZUK KAYIT menuyu kirmaz", () => {
    localStorage.setItem("yonetio.menu.durum.v3", "{bu gecerli json degil");
    ciz(Kabuk());
    // Varsayilana dusulur: hepsi kapali, bagimsiz sekme yerinde.
    expect(menuHrefleri()).toContain("/dashboard");
    expect(menuHrefleri()).not.toContain("/users");
  });

  it("DEPOLAMA YAZILAMAZSA (gizli sekme) menu yine calisir", () => {
    const asil = Storage.prototype.setItem;
    Storage.prototype.setItem = () => {
      throw new DOMException("QuotaExceededError");
    };
    try {
      ciz(Kabuk());
      bolumCevir(/finans/i);
      // Acilma CALISIR; yalnizca hatirlanmaz.
      expect(menuHrefleri()).toContain("/dues");
    } finally {
      Storage.prototype.setItem = asil;
    }
  });
});

describe("(P167 §1.1) IKON KURALI TERSINE", () => {
  it("ANA BASLIK ikon tasir, ALT SATIR tasimaz", () => {
    const { container } = ciz(Kabuk());
    const finans = bolumDugmesi(/finans/i);
    expect(finans.querySelector("svg")).toBeTruthy();
    bolumCevir(/finans/i);
    // Alt satir: ikonsuz ve GIRINTILI (`ps-9`).
    const aidat = container.querySelector('a[href="/dues"]');
    expect(aidat?.querySelector("svg")).toBeNull();
    expect(aidat?.className).toContain("ps-9");
  });

  it("BAGIMSIZ SEKME (Ozet) ikon tasir ve basligi YOK", () => {
    const { container } = ciz(Kabuk());
    // NAV ICINDEN secilir: logo baglantisi da `/dashboard`a gider
    // (`kokRotaRol`) ve `container.querySelector` ONU bulurdu.
    const ozet = container.querySelector('nav a[href="/dashboard"]');
    expect(ozet?.querySelector("svg")).toBeTruthy();
    expect(ozet?.className).toContain("ps-3");
    // Ozet icin bir acilir baslik dugmesi CIZILMEZ.
    expect(screen.queryAllByRole("button", { name: /özet/i })).toEqual([]);
  });
});

describe("(P133.1) erisilebilirlik", () => {
  it("bolum basligi DUGME ve durumunu bildiriyor", () => {
    ciz(Kabuk());
    const finans = bolumDugmesi(/finans/i);
    expect(finans.tagName).toBe("BUTTON");
    // (P167 §1.2) KAPALI baslar.
    expect(finans).toHaveAttribute("aria-expanded", "false");
    fireEvent.click(finans);
    expect(bolumDugmesi(/finans/i)).toHaveAttribute("aria-expanded", "true");
  });

  it("KAPALI bolumun ogeleri ODAKLANILABILIR DEGIL (DOM'da yok)", () => {
    // "Gorunmez ama Tab ile gezilebilir" satir, klavye kullanicisi icin
    // en can sikici hatadir: odak bos yere gider.
    ciz(Kabuk());
    expect(menuHrefleri()).not.toContain("/dues");
    bolumCevir(/finans/i);
    expect(menuHrefleri()).toContain("/dues");
  });

  it("ACILIR OK dekoratiftir (ekran okuyucuya okunmaz)", () => {
    const { container } = ciz(Kabuk());
    const okler = container.querySelectorAll("svg[aria-hidden='true']");
    expect(okler.length).toBeGreaterThan(0);
  });
});
