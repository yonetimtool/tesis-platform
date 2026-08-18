// @vitest-environment jsdom
// (P169 §2.1) CEKMECE — ESC · ODAK TUZAGI · KAYDIRMA KILIDI.
//
// =========================================================================
// UCU DE EKSIKTI VE UCU DE GERCEK SORUN
// =========================================================================
//   ESC YOK         — klavye kullanicisi cekmeceyi kapatmak icin FAREYLE
//                     ortuye tiklamak zorundaydi.
//   ODAK TUZAGI YOK — cekmece aciken Tab ARKADAKI sayfaya kaciyordu:
//                     ekran okuyucu kullanicisi GORMEDIGI bir sayfada
//                     geziniyordu.
//   KILIT YOK       — cekmece aciken parmakla kaydirinca ARKADAKI sayfa
//                     kayiyor, kullanici kapatinca kendini baska yerde
//                     buluyordu.
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import React from "react";

import { AppShell } from "@/components/AppShell";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/dashboard",
  useSearchParams: () => new URLSearchParams(),
}));

beforeEach(() => {
  vi.stubGlobal("matchMedia", (sorgu: string) => ({
    media: sorgu,
    matches: false,
    addEventListener: () => {},
    removeEventListener: () => {},
  }));
  vi.stubGlobal("scrollTo", () => {});
});
afterEach(() => {
  vi.unstubAllGlobals();
  document.body.style.cssText = "";
});

function kabuk() {
  return () =>
    React.createElement(AppShell, {
      yuzey: "tesis" as const,
      rol: "admin",
      children: React.createElement("p", null, "icerik"),
    } as React.ComponentProps<typeof AppShell>);
}

async function cekmeceyiAc() {
  ciz(kabuk());
  // TAM AD ile secilir: `/menü/i` hem hamburgeri hem masaustu "Menüyü
  // daralt" dugmesini yakaliyor ve sirasi degisince test sessizce yanlis
  // dugmeye basardi.
  await userEvent.click(screen.getByRole("button", { name: "Menüyü aç" }));
}

describe("(P169 §2.1) cekmece", () => {
  it("KAYDIRMA KILITLENIR — arkadaki sayfa kaymaz", async () => {
    expect(document.body.style.overflow).toBe("");
    await cekmeceyiAc();
    // `overflow:hidden` TEK BASINA YETMEZ (iOS Safari yine kaydirir);
    // `position:fixed` de gerekiyor.
    expect(document.body.style.overflow).toBe("hidden");
    expect(document.body.style.position).toBe("fixed");
  });

  it("ESC ile KAPANIR ve kilit COZULUR", async () => {
    await cekmeceyiAc();
    await userEvent.keyboard("{Escape}");
    // Kilit cozulmezse sayfa cekmece kapandiktan SONRA da kayamaz hale
    // gelirdi — sessiz ve tesbihi zor bir kusur.
    expect(document.body.style.overflow).toBe("");
    expect(document.body.style.position).toBe("");
  });

  it("ODAK cekmecenin ICINE tasinir", async () => {
    await cekmeceyiAc();
    // Kabukta IKI `aside` var ve IKISI DE `fixed inset-y-0` tasir:
    // masaustu kenar cubugu (`transition-[width]`, `lg:block`) ve mobil
    // cekmece (`transition-transform`, `lg:hidden`). Ayirt edici olan
    // gecis ozelligi; `inset-y-0` ile secmek masaustu cubugunu yakalar.
    const cekmece = Array.from(document.querySelectorAll("aside")).find((a) =>
      a.className.includes("transition-transform"),
    );
    expect(cekmece, "cekmece bulunamadi").toBeTruthy();
    expect(cekmece!.contains(document.activeElement)).toBe(true);
  });
});
