// @vitest-environment jsdom
// (P160 / Asama 3) ORTAK BILESEN KATMANI — davranis ve erisilebilirlik.
//
// OLCULEN SEY GORUNUM DEGIL, SOZLESME:
//   * bilesenler token disi SABIT RENK yazmiyor (iki dil karismasin),
//   * erisilebilirlik kurallari (etiket bagi, aria-invalid, aria-busy,
//     sayan rakamin ekran okuyucuya okunmamasi) YERINDE,
//   * dugme yuklenirken CIFT GONDERIM yapmiyor.
//
// Bu dosya `.dom.test.ts` (`.tsx` DEGIL) ve JSX kullanmiyor: depo kurali
// (bkz. tests/yardimci.ts basligi) — JSX eklentisi `next build`i kiriyor.
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { describe, expect, it, vi } from "vitest";

import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  IkonDugmesi,
  Kpi,
  Rozet,
} from "@/components/ui";

/** `ciz` yardimcisi bir SAYFA bileseni bekliyor; burada tekil bilesenleri
 *  suruyoruz, o yuzden ince bir sarmalayici. Toast saglayicisi gerekmiyor
 *  (bu bilesenlerin hicbiri toast atmiyor). */
function ciz(el: React.ReactElement) {
  return render(
    createElement(I18nProvider, {
      baslangicDili: "tr" as const,
      baslangicSozlugu: SOZLUKLER.tr,
      children: el,
    }),
  );
}

/* ======================================================================
   1) TOKEN DISCIPLINI — sabit renk sizmasin
   ====================================================================== */

const UI_DIZIN = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "components",
  "ui",
);

/** Yorumlar AYIKLANIR: kurallar KODA dairdir, belgeye degil. `yuzey.tsx`
 *  basligi "bg-white BILEREK kullanilmiyor" diye yaziyor ve bu dogru bir
 *  aciklama — onu ihlal saymak, gerekce yazmayi cezalandirmak olurdu. */
function yorumsuz(govde: string): string {
  return govde.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*\/\/.*$/gm, "");
}

function uiDosyalari(): { ad: string; govde: string }[] {
  return readdirSync(UI_DIZIN)
    .filter((f) => f.endsWith(".tsx"))
    .map((f) => ({
      ad: f,
      govde: yorumsuz(readFileSync(join(UI_DIZIN, f), "utf8")),
    }));
}

describe("(P160) token disiplini", () => {
  it("bilesenlerde SABIT HEX RENK yok (belgelenmis istisna disinda)", () => {
    // TEK ISTISNA: `dugme.tsx`teki `#ffffff` — accent gradyani uzerindeki
    // metin. Token'dan gelemez cunku o zemin HER IKI temada da accent'tir
    // ve `--yz-text` acik temada koyu olup okunmazdi. Gerekce dosyada
    // yazili; kontrast olculdu.
    const izinli = new Map([["dugme.tsx", ['"#ffffff"']]]);
    for (const { ad, govde } of uiDosyalari()) {
      const hexler = [...govde.matchAll(/"#[0-9a-fA-F]{3,8}"/g)].map((m) => m[0]);
      const kalan = hexler.filter((h) => !(izinli.get(ad) ?? []).includes(h));
      expect(kalan, `${ad} icinde token disi renk: ${kalan.join(", ")}`).toEqual([]);
    }
  });

  it("bilesenler ESKI dil siniflarini kullanmiyor", () => {
    // `bg-yuzey-*`, `text-metin-*`, `kart-kenar` eski dile ait ve
    // `globals.css`te `.dark` ile yeniden eslenmis. Yeni yuzeylerde
    // kullanmak iki dili birbirine karistirirdi.
    const yasak = /\b(bg-yuzey-|text-metin-|kart-kenar|bg-white|border-slate-)/;
    for (const { ad, govde } of uiDosyalari()) {
      expect(yasak.test(govde), `${ad} eski dil sinifi kullaniyor`).toBe(false);
    }
  });

  it("bilesenlerde SABIT TURKCE METIN yok (i18n kurali)", () => {
    // Kilitli kural 5. Gorunen her metin `useT()`den gelmeli; bilesenler
    // metni PROP olarak alir.
    const turkce = /[çğıöşüÇĞİÖŞÜ]/;
    for (const { ad, govde } of uiDosyalari()) {
      // `uiDosyalari` yorumlari zaten ayikladi (aciklamalar Turkce ve
      // bu dogru); geriye yalniz kod dizeleri kaliyor.
      const dizeler = [...govde.matchAll(/"([^"\\]{2,})"/g)].map((m) => m[1]);
      const supheli = dizeler.filter((d) => turkce.test(d));
      expect(supheli, `${ad} icinde sabit Turkce: ${supheli.join(" | ")}`).toEqual([]);
    }
  });
});

/* ======================================================================
   2) DUGME
   ====================================================================== */

describe("(P160) Dugme", () => {
  it("yuklenirken CIFT GONDERIM yapmaz ve aria-busy tasir", async () => {
    const tikla = vi.fn();
    ciz(createElement(Dugme, { yukleniyor: true, onClick: tikla }, "Kaydet"));
    const d = screen.getByRole("button");
    expect(d).toHaveAttribute("aria-busy", "true");
    expect(d).toBeDisabled();
    await userEvent.click(d).catch(() => undefined);
    expect(tikla, "yuklenirken tiklama gecti — cift gonderim mumkun").not.toHaveBeenCalled();
  });

  it("ikon dugmesi ekran okuyucuda ADSIZ kalmaz", () => {
    ciz(
      createElement(IkonDugmesi, {
        etiket: "Kapat",
        ikon: createElement("svg"),
      }),
    );
    // `getByRole` erisilebilir ADA gore arar; ad yoksa bulamaz.
    expect(screen.getByRole("button", { name: "Kapat" })).toBeInTheDocument();
  });

  it("normal halde tiklanir", async () => {
    const tikla = vi.fn();
    ciz(createElement(Dugme, { onClick: tikla }, "Tamam"));
    await userEvent.click(screen.getByRole("button"));
    expect(tikla).toHaveBeenCalledOnce();
  });
});

/* ======================================================================
   3) KPI — sayan rakam ekran okuyucuya OKUNMAZ
   ====================================================================== */

describe("(P160) Kpi", () => {
  it("gercek deger sr-only metinde, halka aria-hidden", () => {
    const { container } = ciz(
      createElement(Kpi, { deger: 24, etiket: "Aktif alarm", durum: "kritik" }),
    );
    // Ekran okuyucunun okudugu TEK yer: gercek deger.
    expect(screen.getByText("Aktif alarm: 24")).toBeInTheDocument();
    // Halka dekordur.
    const halka = container.querySelector("[aria-hidden='true']");
    expect(halka, "halka aria-hidden degil").not.toBeNull();
  });

  it("hareket azaltmada SAYMAZ, dogrudan hedefi yazar", () => {
    // `matchMedia` jsdom'da yok; reduce=true taklit ediliyor.
    vi.stubGlobal(
      "matchMedia",
      (q: string) => ({
        matches: q.includes("reduce"),
        media: q,
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
      }),
    );
    const { container } = ciz(createElement(Kpi, { deger: 42, etiket: "Gorev" }));
    expect(container.textContent).toContain("42");
    vi.unstubAllGlobals();
  });

  it("birim sayinin yanina yazilir ve sr metnine de girer", () => {
    ciz(createElement(Kpi, { deger: 87, etiket: "Tahsilat", birim: "%" }));
    expect(screen.getByText("Tahsilat: 87%")).toBeInTheDocument();
  });
});

/* ======================================================================
   4) FORM ALANI — etiket bagi ve hata bildirimi
   ====================================================================== */

describe("(P160) AlanSarmal", () => {
  it("etiket alana BAGLI (htmlFor/id) — yer tutucu etiket yerine gecmez", () => {
    ciz(
      createElement(AlanSarmal, {
        etiket: "Ad soyad",
        children: (b: Record<string, unknown>) => createElement(Alan, { ...b }),
      }),
    );
    // Etiketle bulunabiliyorsa bag kurulmus demektir.
    expect(screen.getByLabelText("Ad soyad")).toBeInTheDocument();
  });

  it("hata: aria-invalid + aria-describedby + role=alert", () => {
    ciz(
      createElement(AlanSarmal, {
        etiket: "Telefon",
        hata: "Numara gecersiz",
        children: (b: Record<string, unknown>) => createElement(Alan, { ...b }),
      }),
    );
    const alan = screen.getByLabelText("Telefon");
    expect(alan).toHaveAttribute("aria-invalid", "true");
    const hataId = alan.getAttribute("aria-describedby");
    expect(hataId, "hata alana baglanmamis").toBeTruthy();
    const hata = screen.getByRole("alert");
    expect(hata).toHaveAttribute("id", hataId!);
    expect(hata).toHaveTextContent("Numara gecersiz");
  });

  it("hata VARKEN ipucu okutulmaz (asil mesaj gomulmesin)", () => {
    ciz(
      createElement(AlanSarmal, {
        etiket: "Kod",
        ipucu: "Alti hane",
        hata: "Zorunlu",
        children: (b: Record<string, unknown>) => createElement(Alan, { ...b }),
      }),
    );
    const alan = screen.getByLabelText("Kod");
    const id = alan.getAttribute("aria-describedby")!;
    expect(document.getElementById(id)).toHaveTextContent("Zorunlu");
  });
});

/* ======================================================================
   5) HATA DURUMU
   ====================================================================== */

describe("(P160) HataDurumu", () => {
  it("tekrar dene dugmesi YALNIZ isleyici varsa cizilir", () => {
    const { rerender } = ciz(createElement(HataDurumu, {}));
    expect(screen.queryByRole("button")).toBeNull();

    const tekrar = vi.fn();
    rerender(
      createElement(I18nProvider, {
        baslangicDili: "tr" as const,
        baslangicSozlugu: SOZLUKLER.tr,
        children: createElement(HataDurumu, { onTekrar: tekrar }),
      }),
    );
    expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument();
  });

  it("sunucu metni VARSA o gosterilir, yoksa genel i18n metni", () => {
    ciz(createElement(HataDurumu, { mesaj: "Yetkiniz yok" }));
    expect(screen.getByRole("alert")).toHaveTextContent("Yetkiniz yok");
  });

  it("mesaj yoksa i18n metni cikar", () => {
    ciz(createElement(HataDurumu, {}));
    expect(screen.getByRole("alert")).toHaveTextContent("Veriler yüklenemedi.");
  });
});

/* ======================================================================
   6) ROZET — dolu DEGIL, kenar + metin
   ====================================================================== */

describe("(P160) Rozet", () => {
  it("zemin YUZEY rengidir (renkli dolgu yok)", () => {
    const { container } = ciz(createElement(Rozet, { durum: "kritik", children: "Pasif" }));
    const el = container.querySelector("span");
    // Brief: renk yalniz SINYAL; dolgu blok terk edildi.
    expect(el?.getAttribute("style")).toContain("var(--yz-surface-1)");
  });

  it("metin durumu SOYLER — renk tek basina anlam tasimaz", () => {
    ciz(createElement(Rozet, { durum: "olumlu", children: "Aktif" }));
    expect(screen.getByText("Aktif")).toBeInTheDocument();
  });
});
