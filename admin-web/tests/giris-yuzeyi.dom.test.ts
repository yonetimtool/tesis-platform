// @vitest-environment jsdom
// (P205 §1) GIRIS EKRANI ARTIK TEK ALAN — HER IKI YUZEYDE.
//
// =========================================================================
// ESKI TASARIM VE NEDEN DEGISTI
// =========================================================================
// P126'dan beri `app.*` TELEFON+parola, `panel.*` ise TESIS KODU+e-posta
// istiyordu. Ayrim tutarliydi ama OLCULEN bir kusuru vardi:
//
//   P197'den beri E-POSTA ZORUNLU, TELEFON OPSIYONEL. Web'den
//   e-posta+parolayla kaydolmus, telefon girmemis bir yonetici
//   `app.*`ta HIC GIRIS YAPAMIYORDU — alan yalnizca telefon
//   istiyordu.
//
// Yeni tasarim: TEK alan, "E-posta veya telefon numarasi". Ayrimi
// (`@` var mi) SUNUCU yapar. Eski `login-phone` ucu backend'de DURUYOR
// (magazadaki eski mobil surumler kullaniyor) ama web ARTIK CAGIRMIYOR.
//
// Bu dosya yeni sozlesmeyi kilitler; eski iki-alan iddialari BILINCLI
// olarak kaldirildi.
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

const kimlikGirdisi = () =>
  screen.getByLabelText(/E-posta veya telefon/i, { selector: "input" });

describe.each([
  ["app.* (tesis yuzeyi)", "tesis" as const],
  ["panel.* (platform yuzeyi)", "platform" as const],
])("%s — TEK ALAN", (_ad, yuzey) => {
  const Form = () => createElement(GirisFormu, { yuzey });

  it("tek kimlik alani var; AYRI telefon/e-posta/tesis alani YOK", () => {
    ciz(Form);
    expect(kimlikGirdisi()).toBeInTheDocument();
    // Ucu de KALKTI: kullaniciya "hangisiyle giriyorsun" sorulmuyor.
    expect(screen.queryByLabelText(/Cep telefonu/i)).toBeNull();
    expect(screen.queryByLabelText(/^E-posta$/i)).toBeNull();
    expect(screen.queryByLabelText(/Tesis \(slug\)/i)).toBeNull();
  });

  it("ekranda 'e-posta VEYA telefon ile giris yapin' yazar", () => {
    // Istegin acik sarti (kabul kriteri 2).
    ciz(Form);
    expect(
      screen.getByText(/E-posta veya telefon numaranız ile giriş yapın/i),
    ).toBeInTheDocument();
  });

  it("E-POSTA yazilinca istek /auth/login'e `kimlik` ile gider", async () => {
    const c = taklit();
    ciz(Form);
    await userEvent.type(kimlikGirdisi(), "a@b.test");
    await userEvent.type(parolaGirdisi(), "Admin123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));

    await waitFor(() => expect(c.length).toBe(1));
    expect(c[0].url).toBe("/api/auth/login");
    expect(c[0].body).toEqual({ kimlik: "a@b.test", password: "Admin123!" });
  });

  it("TELEFON yazilinca AYNI uca AYNI alanla gider", async () => {
    // `login-phone` ARTIK CAGRILMIYOR: ikinci bir uc cagirmak, ayni
    // karari (kimlik turu) iki yerde vermek olurdu.
    const c = taklit();
    ciz(Form);
    await userEvent.type(kimlikGirdisi(), "0532 111 22 03");
    await userEvent.type(parolaGirdisi(), "Admin123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));

    await waitFor(() => expect(c.length).toBe(1));
    expect(c[0].url).toBe("/api/auth/login");
    expect(c.some((x) => x.url.includes("login-phone"))).toBe(false);
    // TESIS KODU GONDERILMEZ: kullanicidan istenmiyor.
    expect((c[0].body as Record<string, unknown>).tenant_slug).toBeUndefined();
  });

  it("basarili giriste KOKE gidilir — rol yonlendirmesi middleware'de", async () => {
    taklit();
    ciz(Form);
    await userEvent.type(kimlikGirdisi(), "a@b.test");
    await userEvent.type(parolaGirdisi(), "Admin123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));
    await waitFor(() => expect(replace).toHaveBeenCalledWith("/"), {
      timeout: 3000,
    });
  });

  it("sunucunun hata metni AYNEN gosterilir (istemci metin uydurmaz)", async () => {
    taklit(401, { error: { code: "invalid_credentials", message: "Giriş bilgileri hatalı." } });
    ciz(Form);
    await userEvent.type(kimlikGirdisi(), "a@b.test");
    await userEvent.type(parolaGirdisi(), "Admin123!");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));
    expect(await screen.findByText("Giriş bilgileri hatalı.")).toBeInTheDocument();
  });

  it("`beni hatirla` KIMLIGI saklar, parolayi ASLA", async () => {
    taklit();
    ciz(Form);
    await userEvent.type(kimlikGirdisi(), "a@b.test");
    await userEvent.type(parolaGirdisi(), "Admin123!");
    await userEvent.click(screen.getByLabelText(/Beni hatırla/i));
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));
    await waitFor(() => expect(replace).toHaveBeenCalled(), { timeout: 3000 });

    const ham = JSON.stringify(localStorage);
    expect(ham).toContain("a@b.test");
    expect(ham).not.toContain("Admin123!");
  });
});
