// @vitest-environment jsdom
// (P126 sonrasi) GIRIS EKRANI YUZEYE GORE.
//
// `app.*` mobil uygulamanin web ikizidir: TELEFON + PAROLA (mobil ile ayni
// uc, `POST /auth/login-phone`), tenant kodu YOK — telefon global benzersiz.
// `panel.*` platform sahibinindir: tesis kodu + e-posta KALIR.
//
// Bu ayrimin sessizce bozulmasi mumkun ve pahalidir: `app.*`ta e-posta alani
// gostermek, e-postasi OLMAYAN sakinleri (sema'da opsiyonel) disarida
// birakirdi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { GirisFormu } from "@/components/GirisFormu";

import { ciz } from "./yardimci";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  usePathname: () => "/login",
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
  // (P154 / Asama 7.1) Menu artik ayni rotanin ALT GORUNUMLERINI tasiyor
  // (`/finans?tip=gelir`); kabuk aktif satiri bulmak icin sorguyu da
  // okuyor. Sahte olmadan `useSearchParams` tanimsiz doner ve kabuk cizim
  // aninda patlar.
  useSearchParams: () => new URLSearchParams(),
}));

type Cagri = { url: string; body: unknown };

function taklit(durum = 200, govde: unknown = { ok: true }): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    // (P154 / Asama 4) SAGLAYICI LISTESI SAYILMAZ. `SosyalGiris` cizim
    // aninda "hangi sosyal dugmeler acik" diye sorar; bu, olculen seyle
    // (GIRIS istegi nereye gitti, govdesi ne) ilgisiz bir cagridir.
    // Toplam cagri sayisi zaten bir VEKIL olcumdu — asil iddia "giris
    // istegi TAM OLARAK BIR KEZ ve dogru uca gitti"dir; listeyi disarida
    // birakmak o iddiayi korur, gevsetmez.
    if (!String(girdi).includes("/oauth/saglayicilar")) {
      cagrilar.push({
        url: String(girdi),
        body: init?.body ? JSON.parse(String(init.body)) : undefined,
      });
    }
    return new Response(JSON.stringify(govde), {
      status: durum,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => {
  vi.restoreAllMocks();
  replace.mockClear();
  localStorage.clear();
});

/// (P154 / Asama 7.2) Parola alaninda artik bir GOSTER/GIZLE dugmesi de
/// var ve onun erisilebilir adi da "Parola" ile basliyor. `getByLabelText`
/// ikisini birden buluyor — bu bir URUN KUSURU DEGIL, sorgunun fazla
/// genis olmasi: biri metin kutusu, oteki dugme.
const parolaGirdisi = () =>
  screen.getByLabelText(/Parola/i, { selector: "input" });

describe("app.* (tesis yuzeyi) — TELEFONLA giris", () => {
  const Form = () => createElement(GirisFormu, { yuzey: "tesis" as const });

  it("telefon alani var; tesis kodu ve e-posta YOK", () => {
    ciz(Form);
    expect(screen.getByLabelText(/Cep telefonu/i)).toBeInTheDocument();
    expect(screen.queryByLabelText(/Tesis \(slug\)/i)).toBeNull();
    expect(screen.queryByLabelText(/E-posta/i)).toBeNull();
  });

  it("numara MASKELENIR, sunucuya E.164 gider ve uc login-phone'dur", async () => {
    const c = taklit();
    ciz(Form);
    const tel = screen.getByLabelText(/Cep telefonu/i);
    await userEvent.type(tel, "5321112201");
    expect(tel).toHaveValue("0532 111 22 01");
    await userEvent.type(parolaGirdisi(), "Yonetici123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));

    await waitFor(() => expect(c.length).toBe(1));
    expect(c[0].url).toBe("/api/auth/login-phone");
    expect(c[0].body).toEqual({ phone: "+905321112201", password: "Yonetici123!" });
  });

  it("EKSIK numarayla istek GONDERILMEZ (sunucudan anlamsiz 401 alinmaz)", async () => {
    const c = taklit();
    ciz(Form);
    await userEvent.type(screen.getByLabelText(/Cep telefonu/i), "532111");
    await userEvent.type(parolaGirdisi(), "Yonetici123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));

    expect(await screen.findByRole("alert")).toHaveTextContent(/eksik/i);
    expect(c.length).toBe(0);
  });

  it("basarili giriste KOKE gidilir — rol yonlendirmesi middleware'de", async () => {
    taklit();
    ciz(Form);
    await userEvent.type(screen.getByLabelText(/Cep telefonu/i), "5321112203");
    await userEvent.type(parolaGirdisi(), "Resident123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));
    // `/dashboard` YAZILMAZ: panoyu yalniz yonetim gorur.
    await waitFor(() => expect(replace).toHaveBeenCalledWith("/"));
  });

  it("ILK GIRIS (parola belirleme) mesaji AYNEN gosterilir", async () => {
    taklit(409, {
      error: {
        code: "password_setup_required",
        message: "İlk girişte parolanızı mobil uygulamadan belirlemeniz gerekir.",
      },
    });
    ciz(Form);
    await userEvent.type(screen.getByLabelText(/Cep telefonu/i), "5321112206");
    await userEvent.type(parolaGirdisi(), "123456");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/mobil uygulamadan/i);
  });

  it("`beni hatirla` NUMARAYI saklar, parolayi ASLA", async () => {
    taklit();
    ciz(Form);
    await userEvent.type(screen.getByLabelText(/Cep telefonu/i), "5321112201");
    await userEvent.type(parolaGirdisi(), "Yonetici123!");
    await userEvent.click(screen.getByRole("checkbox"));
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));
    await waitFor(() =>
      expect(localStorage.getItem("yonetio.rememberMe.telefon")).toBe("+905321112201"),
    );
    expect(JSON.stringify(localStorage)).not.toContain("Yonetici123!");
  });
});

describe("panel.* (platform yuzeyi) — E-POSTA + TESIS KODU", () => {
  const Form = () => createElement(GirisFormu, { yuzey: "platform" as const });

  it("tesis kodu + e-posta var; telefon YOK", () => {
    ciz(Form);
    expect(screen.getByLabelText(/Tesis \(slug\)/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/E-posta/i)).toBeInTheDocument();
    expect(screen.queryByLabelText(/Cep telefonu/i)).toBeNull();
  });

  it("istek e-posta ucuna gider (govde degismedi)", async () => {
    const c = taklit();
    ciz(Form);
    await userEvent.type(screen.getByLabelText(/Tesis \(slug\)/i), "demo");
    await userEvent.type(screen.getByLabelText(/E-posta/i), "a@b.test");
    await userEvent.type(parolaGirdisi(), "Admin123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));

    await waitFor(() => expect(c.length).toBe(1));
    expect(c[0].url).toBe("/api/auth/login");
    expect(c[0].body).toEqual({
      tenant_slug: "demo",
      email: "a@b.test",
      password: "Admin123!",
    });
  });
});
