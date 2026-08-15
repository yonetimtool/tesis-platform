// @vitest-environment jsdom
// (P161 §4) TEMA — davranis testi.
//
// Brief'in olculebilir maddeleri:
//   * tercih KALICI (localStorage),
//   * ilk yuklemede SISTEM tercihi okunur,
//   * degisim 200 ms YUMUSAK gecer ve gecis GECICIDIR,
//   * depolama engelliyken uygulama CIZILEBILIR kalir.
//
// Sonuncusu teorik degil: P160'ta korumasiz `localStorage` okumasi gizli
// sekmede TUM KABUGU cizilemez hale getirmisti. Kural `lib/tema.ts`e
// tasindi; burada bir daha kaybolmamasi kilitleniyor.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  TEMA_ANAHTARI,
  kayitliMod,
  koyuMu,
  moduKaydet,
  sistemKoyuMu,
  temayiUygula,
} from "@/lib/tema";

/** `matchMedia`yi verilen cevapla taklit eder. */
function medyaKur(koyu: boolean) {
  vi.stubGlobal("matchMedia", (sorgu: string) => ({
    matches: sorgu.includes("prefers-color-scheme: dark") ? koyu : false,
    media: sorgu,
    addEventListener: () => {},
    removeEventListener: () => {},
  }));
}

beforeEach(() => {
  document.documentElement.className = "";
  localStorage.clear();
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe("mod cozumleme", () => {
  it("SISTEM modu isletim sistemi tercihini IZLER", () => {
    medyaKur(true);
    expect(sistemKoyuMu()).toBe(true);
    expect(koyuMu("system")).toBe(true);
    medyaKur(false);
    expect(koyuMu("system")).toBe(false);
  });

  it("ACIK/KOYU modlari sistemi EZER", () => {
    medyaKur(true);
    expect(koyuMu("light")).toBe(false);
    medyaKur(false);
    expect(koyuMu("dark")).toBe(true);
  });
});

describe("uygulama", () => {
  it("koyu modda kok ogeye `dark` sinifi gelir, acikta kalkar", () => {
    medyaKur(false);
    temayiUygula("dark");
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    temayiUygula("light");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  it("YUMUSAK gecis sinifi eklenir ve KENDILIGINDEN kalkar", () => {
    medyaKur(false);
    temayiUygula("dark", true);
    // Gecis suresince sinif DURMALI: kalkarsa renk aniden ziplardi.
    expect(document.documentElement.classList.contains("yz-tema-gecisi")).toBe(true);
    vi.advanceTimersByTime(400);
    // KALICI OLMAMALI: kalsaydi her hover ve her odak da 200 ms surunurdu.
    expect(document.documentElement.classList.contains("yz-tema-gecisi")).toBe(false);
  });

  it("ILK YUKLEMEDE gecis ACILMAZ (acilis renk animasyonuyla baslamaz)", () => {
    medyaKur(true);
    temayiUygula("system");
    expect(document.documentElement.classList.contains("yz-tema-gecisi")).toBe(false);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("HIZLI ARDISIK degisimde sinif erken kalkmaz", () => {
    medyaKur(false);
    temayiUygula("dark", true);
    vi.advanceTimersByTime(150);
    temayiUygula("light", true);
    // Ilk degisimin zamanlayicisi ikincisini kesmemeli.
    vi.advanceTimersByTime(150);
    expect(document.documentElement.classList.contains("yz-tema-gecisi")).toBe(true);
    vi.advanceTimersByTime(150);
    expect(document.documentElement.classList.contains("yz-tema-gecisi")).toBe(false);
  });
});

describe("gecis KURALI — sicrama olamaz", () => {
  // jsdom CSS'i uygulamaz; olculen sey KURALIN KENDISI.
  const globals = readFileSync(join(process.cwd(), "app", "globals.css"), "utf8");
  const kural = globals.slice(
    globals.indexOf(".yz-tema-gecisi,"),
    globals.indexOf("/* HAREKET-AZALTMA"),
  );

  it("gecis 200 ms", () => {
    expect(kural).toContain("transition-duration: 200ms");
  });

  it("YALNIZ RENK ozellikleri gecer — duzen ozelligi listede YOK", () => {
    // Brief: "sicrama olmasin". `width`, `height`, `transform`, `margin`
    // gibi bir ozellik listeye girerse tema degisimi sayfayi oynatir.
    const duzen = ["width", "height", "margin", "padding", "transform", "top", "left", "inset"];
    const liste = kural.slice(
      kural.indexOf("transition-property"),
      kural.indexOf("transition-duration"),
    );
    for (const ad of duzen) {
      expect(liste, `duzen ozelligi gecis listesinde: ${ad}`).not.toContain(ad);
    }
    // Renk ozellikleri ise GERCEKTEN listede olmali.
    for (const ad of ["background-color", "color", "border-color", "box-shadow"]) {
      expect(liste).toContain(ad);
    }
  });
});

describe("kalicilik", () => {
  it("tercih yazilir ve geri okunur", () => {
    moduKaydet("dark");
    expect(localStorage.getItem(TEMA_ANAHTARI)).toBe("dark");
    expect(kayitliMod()).toBe("dark");
  });

  it("TANINMAYAN deger yok sayilir (bozuk depolama modu bozmasin)", () => {
    localStorage.setItem(TEMA_ANAHTARI, "neon");
    expect(kayitliMod()).toBeNull();
  });

  it("DEPOLAMA ENGELLIYKEN firlatmaz — kabuk cizilebilir kalir", () => {
    const patlat = () => {
      throw new Error("engelli");
    };
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(patlat);
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(patlat);
    expect(() => kayitliMod()).not.toThrow();
    expect(kayitliMod()).toBeNull();
    expect(() => moduKaydet("light")).not.toThrow();
  });
});
