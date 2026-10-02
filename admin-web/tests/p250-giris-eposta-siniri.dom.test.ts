// @vitest-environment jsdom
// (P250 §5) GIRIS EKRANLARINDA E-POSTA SINIRI: 254.
//
// Olculen: giris formunun kimlik alani e-posta kipinde 254, telefon
// kipinde telefon siniri; sifremi unuttum ekraninin e-posta alani 254
// (eskiden 256) ve tesis kodu alani SUNUCUNUN 100'u (eskiden yanlislikla
// e-posta siniri 254). Kod ile giris ayni kimlik alanini kullanir.
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { describe, expect, it, vi } from "vitest";

import { EPOSTA_SINIR } from "@/lib/eposta";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  usePathname: () => "/login",
  useSearchParams: () => new URLSearchParams(),
}));

describe("P250 §5 giris e-posta siniri", () => {
  it("sabit 254", () => {
    expect(EPOSTA_SINIR).toBe(254);
  });

  it("giris kimlik alani: e-posta kipinde 254, telefon kipinde daha kisa", async () => {
    const { GirisFormu } = await import("@/components/GirisFormu");
    await ciz(() => createElement(GirisFormu, { yuzey: "tesis" as const }));
    const kimlik = screen.getByLabelText(/E-posta veya telefon/i, {
      selector: "input",
    }) as HTMLInputElement;
    const k = userEvent.setup();
    await k.type(kimlik, "a@b");
    expect(kimlik.maxLength).toBe(254);
    await k.clear(kimlik);
    await k.type(kimlik, "0543");
    expect(kimlik.maxLength).toBeGreaterThan(0);
    expect(kimlik.maxLength).toBeLessThan(254);
  });

  it("sifremi unuttum: e-posta 254, tesis kodu 100", async () => {
    const mod = await import("@/app/giris/sifremi-unuttum/page");
    await ciz(mod.default);
    expect((screen.getByLabelText("E-posta") as HTMLInputElement).maxLength).toBe(254);
    expect((screen.getByLabelText("Tesis (slug)") as HTMLInputElement).maxLength).toBe(100);
  });
});
