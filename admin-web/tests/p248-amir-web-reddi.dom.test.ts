// @vitest-environment jsdom
// (P248 §1) GUVENLIK AMIRI WEB'E GIREMEZ — anlasilir mesajla.
//
// P213 §6'da amir `app.*`a alinmisti (gecmis kamera kaydi). Kullanici
// karari: amir YALNIZ mobilden girer. Uc katman olculur:
//   1. GIRIS KAPISI (`oturumAc`): TUM giris yollari (parola, kod, SSO,
//      davet/set-password, rol gecisi) bu tek kapidan gecer; amir 403 +
//      `mobil_uygulama` alir ve CEREZ YAZILMAZ — iki yuzeyde de.
//   2. MESAJ: rolunun adiyla (`girisAmirMobil`), giris formunda.
//   3. ARTAKALAN OTURUM: middleware `/login?neden=mobil_uygulama&rol=...`
//      ile yollar; giris ekrani o mesaji ILK KAREDE cizer.
import { screen } from "@testing-library/react";
import { createElement } from "react";
import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

import { GirisFormu } from "@/components/GirisFormu";
import { tr } from "@/lib/i18n/sozluk/tr";
import { oturumAc } from "@/lib/oturum-kapisi";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  usePathname: () => "/login",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

vi.mock("next/headers", () => ({
  headers: () => new Headers({ host: "app.yonetiyor.com" }),
}));

function jeton(rol: string): string {
  const govde = Buffer.from(JSON.stringify({ role: rol })).toString("base64url");
  return `x.${govde}.y`;
}

function istek(konak: string): NextRequest {
  return new NextRequest("http://ic:3000/api/auth/login", {
    method: "POST",
    headers: { host: konak, "accept-language": "tr" },
  });
}

afterEach(() => vi.restoreAllMocks());

describe("(P248 §1) giris kapisi amiri REDDEDER", () => {
  for (const konak of ["app.yonetiyor.com", "panel.yonetiyor.com"]) {
    it(`${konak}: 403 + mobil_uygulama + amir metni, CEREZ YOK`, async () => {
      const y = oturumAc(istek(konak), jeton("guvenlik_amiri"), "r1");
      expect(y.status).toBe(403);
      const govde = (await y.json()) as { error: { code: string; message: string } };
      expect(govde.error.code).toBe("mobil_uygulama");
      expect(govde.error.message).toBe(tr.girisAmirMobil);
      expect(y.headers.getSetCookie()).toEqual([]);
    });
  }

  it("yonetici ayni kapidan GECER (iki yon)", () => {
    expect(oturumAc(istek("app.yonetiyor.com"), jeton("yonetici"), "r1").status).toBe(200);
  });
});

describe("(P248 §1) giris ekrani artakalan oturumun NEDENINI soyler", () => {
  it("`ilkRed` verilince mesaj ilk karede gorunur", () => {
    globalThis.fetch = (async () =>
      new Response("{}", { headers: { "Content-Type": "application/json" } })) as typeof fetch;
    ciz(() => createElement(GirisFormu, { yuzey: "tesis", ilkRed: "girisAmirMobil" }));
    expect(screen.getByText(tr.girisAmirMobil)).toBeTruthy();
  });

  it("login sayfasi adresten amir mesajini secer; uydurma rolde SUSAR", async () => {
    globalThis.fetch = (async () =>
      new Response("{}", { headers: { "Content-Type": "application/json" } })) as typeof fetch;
    const { default: LoginPage } = await import("@/app/login/page");
    const el = await LoginPage({
      searchParams: { neden: "mobil_uygulama", rol: "guvenlik_amiri" },
    });
    expect((el.props as { ilkRed?: string }).ilkRed).toBe("girisAmirMobil");
    const bos = await LoginPage({ searchParams: { neden: "mobil_uygulama", rol: "yonetici" } });
    expect((bos.props as { ilkRed?: string }).ilkRed).toBeUndefined();
    const hic = await LoginPage({});
    expect((hic.props as { ilkRed?: string }).ilkRed).toBeUndefined();
  });
});
