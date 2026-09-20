// @vitest-environment jsdom
// (P244 §3) YENI PAYLASILAN BILESENLER.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// Asama 3 uc boslugu kapatti (olculdu, plan §1.3):
//   * detay paneli 79 sayfanin **1'inde** vardi,
//   * KPI **3'unde**,
//   * paylasilan bir filtre cubugu **HIC YOKTU**.
//
// Yeni bilesenlerin kendileri degil, DAVRANISLARI kilitleniyor —
// ozellikle erisilebilirlik parcalari, cunku onlar sessizce kaybolur.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement as h } from "react";
import { describe, expect, it, vi } from "vitest";

import { DetayCekmecesi, FiltreCubugu, OzetKarti, VeriTablosu } from "@/components/ui";

import { ciz } from "./yardimci";

// KANCA SECICISI `data-test` — deponun konvansiyonu (358 kullanim).
const kanca = (ad: string): HTMLElement | null =>
  document.querySelector<HTMLElement>(`[data-test="${ad}"]`);

describe("(P244 §3) detay cekmecesi", () => {
  function Cekmece(props: Record<string, unknown> = {}) {
    return () =>
      h(
        DetayCekmecesi,
        {
          acik: true,
          onKapat: vi.fn(),
          baslik: "A-12",
          altBaslik: "A Blok · 3. kat",
          children: h("button", { type: "button" }, "iç düğme"),
          ...props,
        } as never,
      );
  }

  it("DIYALOG olarak duyurulur ve BASLIKLA adlandirilir", () => {
    ciz(Cekmece());
    const d = screen.getByRole("dialog");
    expect(d).toHaveAttribute("aria-modal", "true");
    // Ad BASLIKTAN gelir: `aria-modal` tek basina "hangi pencere"
    // sorusunu yanitlamaz.
    expect(d).toHaveAccessibleName("A-12");
  });

  it("ESC KAPATIR", async () => {
    const kapat = vi.fn();
    ciz(Cekmece({ onKapat: kapat }));
    await userEvent.keyboard("{Escape}");
    expect(kapat).toHaveBeenCalled();
  });

  it("ORTUYE tiklayinca kapanir", async () => {
    const kapat = vi.fn();
    const { container } = ciz(Cekmece({ onKapat: kapat }));
    const ortu = container.querySelector('[aria-hidden="true"].fixed');
    expect(ortu).not.toBeNull();
    await userEvent.click(ortu as Element);
    expect(kapat).toHaveBeenCalled();
  });

  it("ODAK ICERI GIRER — acilista disarida kalmaz", async () => {
    ciz(Cekmece());
    await waitFor(() =>
      expect(screen.getByRole("dialog").contains(document.activeElement)).toBe(true),
    );
  });

  it("EYLEM CUBUGU verilmezse CIZILMEZ (bos serit birakmaz)", () => {
    const { container } = ciz(Cekmece());
    expect(container.querySelectorAll("footer, .border-t").length).toBe(0);
  });
});

describe("(P244 §3) filtre cubugu", () => {
  it("AKTIF FILTRE SAYISI metinle soylenir, yalniz renkle DEGIL", async () => {
    const temizle = vi.fn();
    ciz(() => h(FiltreCubugu, { aktifSayi: 3, onTemizle: temizle }));
    // Sayinin kendisi metinde: renk korlugu olan kullanici da okur.
    const dugme = kanca("filtre-temizle") as HTMLElement;
    expect(dugme.textContent).toMatch(/3/);
    await userEvent.click(dugme);
    expect(temizle).toHaveBeenCalled();
  });

  it("FILTRE YOKKEN temizle dugmesi CIZILMEZ", () => {
    ciz(() => h(FiltreCubugu, { aktifSayi: 0, onTemizle: vi.fn() }));
    expect(kanca("filtre-temizle")).toBeNull();
  });
});

describe("(P244 §3) ozet karti", () => {
  it("TREND RENGI YONE DEGIL ANLAMA bagli", () => {
    // Referansta "Açık Talepler ↓%20" KIRMIZI cizilmis — oysa acik
    // talebin azalmasi iyi haberdir. Bizde yonu cagiran ANLAM olarak
    // verir; ayni ok iki farkli renk alabilmeli.
    const { container: iyi } = ciz(() =>
      h(OzetKarti, { etiket: "Açık talepler", deger: "7", trend: "↓ %20", trendYonu: "iyi" }),
    );
    const { container: kotu } = ciz(() =>
      h(OzetKarti, { etiket: "Tahsilat", deger: "7", trend: "↓ %20", trendYonu: "kotu" }),
    );
    const renk = (c: HTMLElement) =>
      (c.querySelector("span.shrink-0") as HTMLElement | null)?.style.color;
    expect(renk(iyi)).toBeTruthy();
    expect(renk(iyi)).not.toBe(renk(kotu));
  });

  it("TIKLANABILIRSE BAGLANTI, degilse kutu", () => {
    const { container: a } = ciz(() =>
      h(OzetKarti, { etiket: "Daire", deger: "128", href: "/units" }),
    );
    expect(a.querySelector("a")).not.toBeNull();
    const { container: b } = ciz(() => h(OzetKarti, { etiket: "Daire", deger: "128" }));
    expect(b.querySelector("a")).toBeNull();
  });
});

describe("(P244 §3) tablo — yogunluk ve satir tiklama", () => {
  const SATIRLAR = [{ id: "1", ad: "A-12" }];
  const KOLONLAR = [{ id: "ad", baslik: "Daire", hucre: (s: { ad: string }) => s.ad }];

  function Tablo(ek: Record<string, unknown> = {}) {
    return () =>
      h(VeriTablosu, {
        kolonlar: KOLONLAR,
        satirlar: SATIRLAR,
        satirId: (s: { id: string }) => s.id,
        ...ek,
      } as never);
  }

  it("YOGUNLUK hucre dolgusunu degistirir", () => {
    const { container: sik } = ciz(Tablo({ yogunluk: "sik" }));
    const { container: rahat } = ciz(Tablo({ yogunluk: "rahat" }));
    const sinif = (c: HTMLElement) => c.querySelector("tbody td")?.className ?? "";
    expect(sinif(sik)).toContain("py-2");
    expect(sinif(rahat)).toContain("py-4");
  });

  it("onSatirTikla YOKSA satir tiklanabilir GORUNMEZ", () => {
    // Tiklanabilir gorunen ama tiklanmayan satir, kullaniciyi bir kez
    // aldatir ve ikinci kez denemez.
    const { container } = ciz(Tablo());
    const tr = container.querySelector("tbody tr") as HTMLElement;
    expect(tr.getAttribute("role")).toBeNull();
    expect(tr.className).not.toContain("yz-satir-tiklanir");
  });

  it("onSatirTikla VARSA fare VE klavye birlikte calisir", async () => {
    const tikla = vi.fn();
    const { container } = ciz(
      Tablo({ onSatirTikla: tikla, satirAdi: (s: { ad: string }) => s.ad }),
    );
    const tr = container.querySelector("tbody tr") as HTMLElement;
    expect(tr).toHaveAttribute("role", "button");
    expect(tr).toHaveAttribute("tabindex", "0");
    // Erisilebilir ad: ekran okuyucu "satir" degil KAYDI duymali.
    expect(tr.getAttribute("aria-label")).toMatch(/A-12/);
    await userEvent.click(tr);
    tr.focus();
    await userEvent.keyboard("{Enter}");
    await userEvent.keyboard(" ");
    expect(tikla).toHaveBeenCalledTimes(3);
  });

  it("YAPISKAN BASLIK varsayilan KAPALI (kendi kaydirma kabi olan duzeni bozmasin)", () => {
    const { container: kapali } = ciz(Tablo());
    expect(kapali.querySelector("thead")?.className ?? "").not.toContain("sticky");
    const { container: acik } = ciz(Tablo({ yapiskanBaslik: true }));
    expect(acik.querySelector("thead")?.className ?? "").toContain("sticky");
  });
});
