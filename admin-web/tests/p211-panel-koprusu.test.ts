// (P211 §2) PANELE DUSEN YONETICI: MESAJ DEGIL, KOPRU.
//
// =========================================================================
// OLCULEN CIKMAZ (prod)
// =========================================================================
// `panel.yonetiyor.com`da giris yapan bir yonetici 403 + "panel platform
// icindir" mesaji aliyor ve ORADA KALIYORDU: dogru adresi (app.*) kimse
// soylemiyordu. Kapi dogruydu, EKSIK OLAN cikis yoluydu.
//
// Yeni davranis: rol `app.*`a girebiliyorsa oturum ACILIR (cerez ust alan
// adina yazilir) ve yanit gidilecek MUTLAK adresi tasir. Tarayici oraya
// gider; kullanici ikinci kez giris yapmaz.
//
// PORT SIZMAZ (P201 dersi): adres `NEXT_PUBLIC_APP_ADRESI`ten ya da
// iletilmis basliklardan kurulur, Next'in ic dinleme portundan DEGIL.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

import { oturumAc } from "@/lib/oturum-kapisi";

function jeton(rol: string): string {
  const govde = Buffer.from(JSON.stringify({ role: rol })).toString("base64url");
  return `x.${govde}.y`;
}

function istek(konak: string): NextRequest {
  return new NextRequest("http://ic-dinleme:3000/api/auth/login", {
    method: "POST",
    headers: { host: konak, "x-forwarded-host": konak, "x-forwarded-proto": "https" },
  });
}

const ESKI = { ...process.env };

beforeEach(() => {
  process.env.COOKIE_DOMAIN = ".yonetiyor.com";
  delete process.env.NEXT_PUBLIC_APP_ADRESI;
});

afterEach(() => {
  process.env = { ...ESKI };
  vi.restoreAllMocks();
});

describe("(P211 §2) panel -> app koprusu", () => {
  it("yonetici panelde giris yapinca ADRES verilir ve OTURUM ACILIR", async () => {
    const y = oturumAc(istek("panel.yonetiyor.com"), jeton("yonetici"), "r1");
    expect(y.status).toBe(200);
    const govde = (await y.json()) as { yonlendir?: string };
    expect(govde.yonlendir).toBe("https://app.yonetiyor.com/");
    // Oturum GERCEKTEN acildi: app.* tarafinda tekrar giris istenmez.
    const cerez = y.headers.getSetCookie().join(";");
    expect(cerez).toContain("Domain=.yonetiyor.com");
  });

  it("ADRESTE PORT YOK — ic dinleme portu (`:3000`) sizmaz", async () => {
    const y = oturumAc(istek("panel.yonetiyor.com:8443"), jeton("yonetici"), "r1");
    const govde = (await y.json()) as { yonlendir?: string };
    // Konak basligindaki port KORUNUR (vekilin gercek portu), ama Next'in
    // ic portu asla gorunmez.
    expect(govde.yonlendir).not.toContain(":3000");
  });

  it("`NEXT_PUBLIC_APP_ADRESI` varsa O kullanilir", async () => {
    process.env.NEXT_PUBLIC_APP_ADRESI = "https://app.yonetiyor.com";
    const y = oturumAc(istek("panel.yonetiyor.com"), jeton("denetci"), "r1");
    const govde = (await y.json()) as { yonlendir?: string };
    expect(govde.yonlendir).toBe("https://app.yonetiyor.com/");
  });

  it("CEREZ UST ALAN ADINA YAZILMIYORSA kopru KURULMAZ (403 kalir)", async () => {
    // Kopru kurulup cerez konak-ozel kalsaydi kullanici app.*'a varir ve
    // ORADA `/login`e duserdi — mesajda kalmaktan daha kotu.
    delete process.env.COOKIE_DOMAIN;
    const y = oturumAc(istek("panel.yonetiyor.com"), jeton("yonetici"), "r1");
    expect(y.status).toBe(403);
  });

  it("PLATFORM ADMINI panelde normal girer (kopru YOK)", async () => {
    const y = oturumAc(istek("panel.yonetiyor.com"), jeton("admin"), "r1");
    expect(y.status).toBe(200);
    expect((await y.json()) as { yonlendir?: string }).not.toHaveProperty("yonlendir");
  });

  it("MOBIL-YALNIZ ROL app.*ta hâlâ 403 (gerileme yok)", async () => {
    const y = oturumAc(istek("app.yonetiyor.com"), jeton("resident"), "r1");
    expect(y.status).toBe(403);
    const g = (await y.json()) as { error?: { code?: string } };
    expect(g.error?.code).toBe("mobil_uygulama");
  });

  it("yonetici app.*ta normal girer (kopru YOK)", async () => {
    const y = oturumAc(istek("app.yonetiyor.com"), jeton("yonetici"), "r1");
    expect(y.status).toBe(200);
    expect((await y.json()) as { yonlendir?: string }).not.toHaveProperty("yonlendir");
  });
});
