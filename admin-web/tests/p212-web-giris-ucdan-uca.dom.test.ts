// @vitest-environment jsdom
// (P212 §1) WEB GIRISI: FORMDAN BACKEND GOVDESINE KADAR.
//
// ===========================================================================
// OLCULEN KUSUR — VE TESTLERIN NEDEN GORMEDIGI
// ===========================================================================
// `app.yonetiyor.com/login`de telefon + parola ile giris "Tesis kodu,
// e-posta ve parola zorunlu." hatasi veriyordu. Kirilma noktasi ARAYUZ
// DEGIL, BFF VEKILIYDI: form P205'e gore `{kimlik, password}` gonderiyor,
// `app/api/auth/login/route.ts` ise HALA eski sozlesmeyi
// (`{tenant_slug, email, password}`) dogruluyor ve `tenant_slug` bos
// oldugu icin istegi BACKEND'E HIC GONDERMEDEN 400 donuyordu.
//
// MEVCUT TESTLER BUNU GOREMEZDI cunku taklidi `/api/auth/login`
// SINIRINDA kuruyorlardi — yani tam da bozuk olan katmanin YERINE. P200
// dersi burada birebir tekrarladi: taklit, olculecek katmanin ALTINA
// konmali.
//
// BU DOSYA IKI PARCAYI BIRLESTIRIR:
//   1. Form GERCEKTEN ne gonderiyor (jsdom'da surulur),
//   2. O govde GERCEK route handler'a verilince backend'e ne gidiyor
//      (taklit `fetch` BACKEND cagrisinda).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import { API_BASE } from "@/lib/config";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
  usePathname: () => "/login",
  useSearchParams: () => new URLSearchParams(),
}));

type Cagri = { url: string; govde: Record<string, unknown> };

/** Formun `/api/auth/login`e gonderdigi govdeyi yakalar. */
function formTaklidi(durum = 200, yanit: unknown = { ok: true }): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    cagrilar.push({
      url: String(girdi),
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    return new Response(JSON.stringify(yanit), {
      status: String(girdi).endsWith("/api/auth/login") ? durum : 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const parolaGirdisi = () =>
  screen.getByLabelText(/Parola/i, { selector: "input" });

async function girisFormu() {
  const { GirisFormu } = await import("@/components/GirisFormu");
  return ciz(() => createElement(GirisFormu, { yuzey: "tesis" as const }));
}

async function girisDene(kimlik: string) {
  const k = userEvent.setup();
  await girisFormu();
  await k.type(
    screen.getByLabelText(/E-posta veya telefon/i, { selector: "input" }),
    kimlik,
  );
  await k.type(parolaGirdisi(), "CokGizliParola1!");
  await k.click(screen.getByRole("button", { name: /giriş yap/i }));
}

beforeEach(() => {
  replace.mockClear();
});

afterEach(() => {
  vi.restoreAllMocks();
});

// ===================== 1) FORM -> BFF GOVDESI ============================ //

it("TELEFONLA giris: govdede `kimlik` gider, TESIS KODU GITMEZ", async () => {
  const cagrilar = formTaklidi();
  await girisDene("05431992904");

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/auth/login")).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/auth/login")!;
  expect(post.govde.kimlik).toBe("05431992904");
  expect(post.govde.password).toBe("CokGizliParola1!");
  // Kullanicinin bildirdigi hata tam olarak bu alanin BEKLENMESINDEN
  // dogmustu; form onu GONDERMIYOR ve gondermemeli.
  expect(post.govde.tenant_slug).toBeUndefined();
  expect(post.govde.email).toBeUndefined();
});

it("E-POSTAYLA giris: AYNI govde, ayni alan", async () => {
  const cagrilar = formTaklidi();
  await girisDene("kerem@ornek.com");
  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/auth/login")).toBe(true),
  );
  expect(cagrilar.find((c) => c.url === "/api/auth/login")!.govde.kimlik).toBe(
    "kerem@ornek.com",
  );
});

// ===================== 2) BFF -> BACKEND GOVDESI ========================= //

/** Route handler'i GERCEGIYLE calistirir; taklit BACKEND cagrisinda. */
async function vekiliCalistir(govde: Record<string, unknown>) {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    cagrilar.push({
      url: String(girdi),
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    return new Response(
      JSON.stringify({ access_token: "a.b.c", refresh_token: "r" }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }) as typeof fetch;

  const { NextRequest } = await import("next/server");
  const { POST } = await import("@/app/api/auth/login/route");
  const istek = new NextRequest("http://app.test/api/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json", host: "app.test" },
    body: JSON.stringify(govde),
  });
  const yanit = await POST(istek);
  return { yanit, cagrilar };
}

it("VEKIL: `{kimlik,password}` govdesini BACKEND'E ILETIR (400 DEGIL)", async () => {
  const { yanit, cagrilar } = await vekiliCalistir({
    kimlik: "05431992904",
    password: "CokGizliParola1!",
  });

  // Kusur buradaydi: vekil `tenant_slug` bekleyip 400 doner, istek
  // backend'e HIC gitmezdi.
  expect(yanit.status).not.toBe(400);
  const backend = cagrilar.find((c) => c.url === `${API_BASE}/auth/login`);
  expect(backend, "backend'e istek GITMEDI").toBeTruthy();
  expect(backend!.govde).toEqual({
    kimlik: "05431992904",
    password: "CokGizliParola1!",
  });
});

it("VEKIL: TESIS SECIMINDEN sonra `tenant_slug` ILETILIR", async () => {
  // Slug giriste SORULMAZ ama secimin SONUCU olarak ikinci cagrida gelir.
  const { cagrilar } = await vekiliCalistir({
    kimlik: "kerem@ornek.com",
    password: "p",
    tenant_slug: "oltu-sitesi",
  });
  expect(cagrilar.find((c) => c.url === `${API_BASE}/auth/login`)!.govde)
    .toEqual({
      kimlik: "kerem@ornek.com",
      password: "p",
      tenant_slug: "oltu-sitesi",
    });
});

it("VEKIL: ESKI `email` alani da kabul edilir (eski istemci kirilmasin)", async () => {
  const { cagrilar } = await vekiliCalistir({
    email: "kerem@ornek.com",
    password: "p",
  });
  expect(cagrilar.find((c) => c.url === `${API_BASE}/auth/login`)!.govde.kimlik)
    .toBe("kerem@ornek.com");
});

it("VEKIL: kimlik ya da parola BOSSA backend'e GITMEZ (400)", async () => {
  const { yanit, cagrilar } = await vekiliCalistir({ kimlik: "  ", password: "" });
  expect(yanit.status).toBe(400);
  expect(cagrilar.some((c) => c.url.includes("/auth/login"))).toBe(false);
});

// ===================== 3) KOD YOLU: TELEFONDA DURUST ===================== //

it("TELEFONLA 'kod ile giris': ISTEK ATILMAZ, sebep SOYLENIR", async () => {
  // Kod E-POSTAYLA teslim ediliyor (SMS kapali). Eskiden istek `eposta`
  // alaniyla gidiyor ve sunucu bicimsel bir 422 donuyordu.
  const k = userEvent.setup();
  const cagrilar = formTaklidi();
  await girisFormu();
  await k.type(
    screen.getByLabelText(/E-posta veya telefon/i, { selector: "input" }),
    "05431992904",
  );
  await k.click(screen.getByRole("button", { name: new RegExp(tr.girisKodIle, "i") }));

  await screen.findByText(tr.girisKodYalnizEposta);
  expect(cagrilar.some((c) => c.url.includes("eposta-kod"))).toBe(false);
});

it("E-POSTAYLA 'kod ile giris': istek GIDER", async () => {
  const k = userEvent.setup();
  const cagrilar = formTaklidi();
  await girisFormu();
  await k.type(
    screen.getByLabelText(/E-posta veya telefon/i, { selector: "input" }),
    "kerem@ornek.com",
  );
  await k.click(screen.getByRole("button", { name: new RegExp(tr.girisKodIle, "i") }));

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url.includes("eposta-kod?adim=iste"))).toBe(true),
  );
  const post = cagrilar.find((c) => c.url.includes("eposta-kod"))!;
  expect(post.govde.eposta).toBe("kerem@ornek.com");
  // TESIS KODU YOK: sunucu adresin tum uyeliklerine ayni kodu yaziyor.
  expect(post.govde.tenant_slug).toBeUndefined();
});
