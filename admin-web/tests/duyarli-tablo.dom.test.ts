// @vitest-environment jsdom
// (P169 §3.1) DataTable KART MODU — "yetenek kaybi yok" kilidi.
//
// =========================================================================
// BRIEF'IN KIRMIZI CIZGISI
// =========================================================================
// "Masaustunde olup mobilde kaybolan yetenek OLMAYACAK."
//
// Kart modunun kolay ama YANLIS yapilis bicimi, satiri iki-uc alana
// indirip gerisini ATMAKTIR. O zaman tablo dar ekranda "temiz" gorunur
// ama kullanici bir veriye ulasmak icin masaustune gecmek zorunda kalir —
// ve bunu kimse hata olarak bildirmez, cunku ekran DUZGUN gorunuyordur.
//
// Bu dosya kart modunun bir OZET oldugunu, bir KIRPMA olmadigini olcer:
// rolsuz kolonlar "Detay"da GORUNUR, secim/siralama/sayfalama/toplu islem
// CALISIR.
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import React from "react";

import { VeriTablosu, type Kolon } from "@/components/ui";

import { ciz } from "./yardimci";

interface Satir {
  id: string;
  no: string;
  ad: string;
  borc: string;
  durum: string;
  telefon: string;
}

const SATIRLAR: Satir[] = [
  { id: "1", no: "A-1", ad: "Ayşe Yılmaz", borc: "1.250,00", durum: "Borçlu", telefon: "0532" },
  { id: "2", no: "A-2", ad: "Mehmet Kaya", borc: "0,00", durum: "Ödendi", telefon: "0533" },
];

const KOLONLAR: Kolon<Satir>[] = [
  { id: "no", baslik: "Daire", hucre: (s) => s.no, deger: (s) => s.no, kartRolu: "baslik" },
  { id: "ad", baslik: "Ad Soyad", hucre: (s) => s.ad, deger: (s) => s.ad, kartRolu: "ozet" },
  { id: "borc", baslik: "Borç", hucre: (s) => s.borc, kartRolu: "ozet" },
  { id: "durum", baslik: "Durum", hucre: (s) => s.durum, kartRolu: "rozet" },
  // ROLSUZ: kartta gizli, "Detay"da gorunur.
  { id: "telefon", baslik: "Telefon", hucre: (s) => s.telefon },
];

/**
 * `matchMedia` sahtesi.
 *
 * `matches` BIR GETTER — cunku gercek `MediaQueryList` CANLIDIR: ayni
 * nesne pencere boyutu degisince farkli deger doner. `useMedya` sorgu
 * basina tek bir liste nesnesi ONBELLEKLER (dogru davranis: tarayicida
 * her cagri icin yeni dinleyici kurmak israf olurdu), yani donuk bir
 * `matches` ile ILK testin genisligi sonraki testlere sizardi.
 */
let suankiGenislik = 1440;

function genislik(px: number) {
  suankiGenislik = px;
}

vi.stubGlobal("matchMedia", (sorgu: string) => ({
  media: sorgu,
  get matches() {
    const px = suankiGenislik;
    if (/pointer:\s*coarse/.test(sorgu)) return px < 640;
    const enAz = /min-width:\s*(\d+)px/.exec(sorgu);
    const enCok = /max-width:\s*(\d+)px/.exec(sorgu);
    let esles = true;
    if (enAz) esles &&= px >= Number(enAz[1]);
    if (enCok) esles &&= px <= Number(enCok[1]);
    return esles;
  },
  addEventListener: () => {},
  removeEventListener: () => {},
}));

function tablo(props: Partial<React.ComponentProps<typeof VeriTablosu<Satir>>> = {}) {
  return () =>
    React.createElement(VeriTablosu<Satir>, {
      kolonlar: KOLONLAR,
      satirlar: SATIRLAR,
      satirId: (s: Satir) => s.id,
      ...props,
    } as React.ComponentProps<typeof VeriTablosu<Satir>>);
}

afterEach(() => genislik(1440));

describe("(P169 §3.1) DataTable mod gecisi", () => {
  it("GENIS ekranda TABLO cizilir", () => {
    genislik(1440);
    ciz(tablo());
    expect(screen.getByRole("table")).toBeInTheDocument();
    // Butun kolonlar basliklariyla orada.
    expect(screen.getByText("Telefon")).toBeInTheDocument();
  });

  it("DAR ekranda KART cizilir — `<table>` YOK", () => {
    // `<table>` icinde hucreleri blok yapmak (`display:block`) satir/kolon
    // iliskisini ekran okuyucudan GIZLER: goze duzelen sey kulaga bozulur.
    genislik(360);
    ciz(tablo());
    expect(screen.queryByRole("table")).toBeNull();
    expect(screen.getByRole("list")).toBeInTheDocument();
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
  });

  it("KART MODU BIR OZETTIR, BIR KIRPMA DEGIL", () => {
    // Bu dosyanin en pahali olcumu: rolsuz kolon SILINMEZ, KATLANIR.
    genislik(360);
    ciz(tablo());
    // Ozet alanlar dogrudan gorunur.
    expect(screen.getByText("A-1")).toBeInTheDocument();
    expect(screen.getByText("Ayşe Yılmaz")).toBeInTheDocument();
    expect(screen.getByText("Borçlu")).toBeInTheDocument();
    // Rolsuz kolon ONCE gizli...
    expect(screen.queryByText("0532")).toBeNull();
    // ...ama ULASILABILIR.
    expect(screen.getAllByRole("button", { name: "Detay" })).toHaveLength(2);
  });

  it("DETAY acilinca gizli kolon GORUNUR", async () => {
    genislik(360);
    ciz(tablo());
    await userEvent.click(screen.getAllByRole("button", { name: "Detay" })[0]);
    expect(screen.getByText("0532")).toBeInTheDocument();
    // Etiketiyle birlikte: "0532" tek basina neyin degeri oldugunu
    // soylemez.
    expect(screen.getAllByText("Telefon").length).toBeGreaterThan(0);
  });

  it("OZET ALANLAR ETIKETLERIYLE cizilir", () => {
    // Kart modunda kolon basligi kaybolur; "1.250,00" tek basina neyin
    // tutari oldugunu soylemez.
    genislik(360);
    ciz(tablo());
    const ilk = screen.getAllByRole("listitem")[0];
    expect(within(ilk).getByText("Borç")).toBeInTheDocument();
    expect(within(ilk).getByText("1.250,00")).toBeInTheDocument();
  });

  it("SECIM kart modunda da CALISIR", async () => {
    const secildi = vi.fn();
    genislik(360);
    ciz(tablo({ secilebilir: true, secili: [], onSeciliDegisti: secildi }));
    const kutular = screen.getAllByRole("checkbox");
    await userEvent.click(kutular[0]);
    expect(secildi).toHaveBeenCalled();
  });

  it("SAYFALAMA SERIDI kart modunda da cizilir", () => {
    // Sayfalama, toplam kayit ve sayfa boyu secimi tablonun DISINDA
    // cizilir; kart moduna gecerken bunlarin dusmesi, dar ekranda ikinci
    // sayfaya HIC gidilememesi demekti.
    genislik(360);
    ciz(tablo());
    const seciciler = screen.getAllByRole("combobox");
    // Sayfa boyu secici (10/25/50/100) her iki modda da var.
    expect(seciciler.length).toBeGreaterThan(0);
  });

  it("`darMod=kaydirma` KART ALANLARI OLSA BILE tabloyu korur", () => {
    // Kolon iliskisi kritik olan finansal tablolarda karta bolmek anlami
    // bozar; karar CAGIRANINDIR.
    genislik(360);
    ciz(tablo({ darMod: "kaydirma" }));
    expect(screen.getByRole("table")).toBeInTheDocument();
  });

  it("`kartRolu` YOKSA otomatik mod KAYDIRMA secer", () => {
    // Kart tanimi verilmemis bir tabloyu karta zorlamak, basligi
    // belirsiz kartlar uretirdi.
    genislik(360);
    ciz(() =>
      React.createElement(VeriTablosu<Satir>, {
        kolonlar: KOLONLAR.map(({ kartRolu, ...k }) => k),
        satirlar: SATIRLAR,
        satirId: (s: Satir) => s.id,
      } as React.ComponentProps<typeof VeriTablosu<Satir>>),
    );
    expect(screen.getByRole("table")).toBeInTheDocument();
  });
});
