// @vitest-environment jsdom
// (P176) TAKVIM VARSAYILAN GORUNUMU VE KALICILIGI.
//
// =========================================================================
// P169'UN GEREKCESI NEDEN ARTIK GECERLI DEGIL
// =========================================================================
// P169 dar ekranda ajandaya geciyordu; gerekce "ay izgarasi okunmuyor"du
// ve O GUN DOGRUYDU: hucreler 80 px yuksekligindeydi ve icine olay ADI
// yazilmaya calisiliyordu — ad 45 px'lik kutuda iki harfe dusuyordu.
//
// P170 §4.2 bunu ZATEN duzeltti: dar ekranda hucre 56 px'e iner ve olay
// adi yerine NOKTA cizilir. Okunmazligin sebebi kalmadi; kalan tek sey
// varsayilandi ve P176 onu degistiriyor.
//
// =========================================================================
// 360 PX — EN DAR EKRAN
// =========================================================================
//   360 − 32 (sayfa `px-4`) − 32 (kart `p-kart`) − 24 (alti `gap-1`)
//   = 272 / 7 = ~38,9 px hucre, ~30,9 px ic genislik.
// Dort nokta 4x6 + 3x2 = 30 px — sigar; sigmazsa `flex-wrap` sarar.
// Izgara `minmax(0, 1fr)` kullandigi icin YATAY KAYDIRMA YAPISAL OLARAK
// IMKANSIZ (sabit genislikli sutun yok). Bu test o yapisal garantileri
// olcer — jsdom'da piksel yerlesimi YOKTUR, yani "goze nasil goruyor"
// buradan olculemez ve olculdugu iddia EDILMEZ.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { readFileSync } from "node:fs";
import React from "react";

import { PanoTakvim } from "@/components/pano/takvim";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  usePathname: () => "/dashboard",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

const ANAHTAR = "yonetio.takvim.gorunum";

/** Bant taklidi: `sm` (dar) ya da genis. */
function bantKur(dar: boolean) {
  vi.stubGlobal("matchMedia", (sorgu: string) => ({
    media: sorgu,
    get matches() {
      // `sm` bandi = 640 ALTI; genis bantlarin sorgusu eslesmez.
      if (dar) return /min-width:\s*0px/.test(sorgu) || sorgu.includes("(min-width: 0");
      return true;
    },
    addEventListener: () => {},
    removeEventListener: () => {},
  }));
}

beforeEach(() => {
  localStorage.clear();
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ items: [] }),
    } as unknown as Response),
  );
});
afterEach(() => vi.unstubAllGlobals());

const takvim = () => React.createElement(PanoTakvim);

describe("varsayilan gorunum", () => {
  it("DAR EKRANDA da AY ile acilir (ajanda DEGIL)", async () => {
    bantKur(true);
    ciz(takvim);
    const ay = await screen.findByRole("button", { name: "Ay" });
    await waitFor(() => expect(ay.getAttribute("aria-pressed")).toBe("true"));
    expect(
      screen.getByRole("button", { name: "Ajanda" }).getAttribute("aria-pressed"),
    ).toBe("false");
  });

  it("GENIS EKRANDA da AY — bant ayrimi kalmadi", async () => {
    bantKur(false);
    ciz(takvim);
    const ay = await screen.findByRole("button", { name: "Ay" });
    await waitFor(() => expect(ay.getAttribute("aria-pressed")).toBe("true"));
  });

  it("AJANDA SEKMESI DURUYOR — kaldirilmadi", async () => {
    bantKur(true);
    ciz(takvim);
    expect(await screen.findByRole("button", { name: "Ajanda" })).toBeTruthy();
  });
});

describe("secim kalici", () => {
  it("kullanici AJANDA'ya gecince kaydedilir", async () => {
    bantKur(true);
    ciz(takvim);
    await userEvent.click(await screen.findByRole("button", { name: "Ajanda" }));
    expect(localStorage.getItem(ANAHTAR)).toBe("ajanda");
  });

  it("KAYITLI tercih acilista uygulanir — her seferinde ay'a DONMEZ", async () => {
    localStorage.setItem(ANAHTAR, "ajanda");
    bantKur(true);
    ciz(takvim);
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Ajanda" }).getAttribute("aria-pressed"),
      ).toBe("true"),
    );
  });

  it("BOZUK kayit varsayilana duser, takvimi KIRMAZ", async () => {
    localStorage.setItem(ANAHTAR, "uydurma-gorunum");
    bantKur(true);
    ciz(takvim);
    const ay = await screen.findByRole("button", { name: "Ay" });
    await waitFor(() => expect(ay.getAttribute("aria-pressed")).toBe("true"));
  });
});

describe("ay izgarasi 360 px'te okunur", () => {
  const kaynak = readFileSync("components/pano/takvim.tsx", "utf8");

  it("YATAY KAYDIRMA YAPISAL OLARAK IMKANSIZ", () => {
    // `minmax(0, 1fr)`: sutunlar icerige gore GENISLEMEZ. Sabit genislik
    // ya da `auto` olsaydi uzun bir olay adi izgarayi tasirdi.
    expect(kaynak).toContain("repeat(7, minmax(0, 1fr))");
  });

  it("DAR EKRANDA olay ADI degil NOKTA cizilir", () => {
    // 30 px'lik bir hucrede ad iki harfe duser; okunmayan metin bilgi
    // tasimaz, nokta ise "bu gunde bir sey var"i TAM tasir.
    expect(kaynak).toContain("flex flex-wrap gap-0.5 sm:hidden");
    expect(kaynak).toContain("hidden space-y-0.5 sm:block");
  });

  it("HUCRE DAR EKRANDA ALCAK, genis ekranda eskisi gibi", () => {
    expect(kaynak).toContain("min-h-14");
    expect(kaynak).toContain("sm:min-h-20");
  });

  it("NOKTALAR SARAR — tasma yerine alt satir", () => {
    // Dort nokta 30 px; ic genislik ~30,9 px. Sinirda; `flex-wrap`
    // olmasaydi bir piksellik fark tasma uretirdi.
    const blok = kaynak.slice(kaynak.indexOf("sm:hidden"));
    expect(blok.slice(0, 400)).toContain("gunun.slice(0, 4)");
    expect(kaynak).toContain("flex-wrap");
  });
});
