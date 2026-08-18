// @vitest-environment jsdom
// (P172 §5) E-POSTA KODU ILE GIRIS — panel yuzeyi.
//
// =========================================================================
// NEDEN BU YOL VAR
// =========================================================================
// SMS gecidi henuz yapilandirilmadi; e-posta (Resend) CALISIYOR. Parolasini
// unutan bir panel kullanicisinin elinde baska bir yol kalmiyordu.
//
// OLCULEN:
//  1. Yol YALNIZ e-posta yuzeyinde (`panel.*`) gorunur. `app.*` telefonla
//     girer ve orada kod yolu mobil uygulamada zaten var; iki yerde iki
//     ayri kod akisi, ikisinin ayrisabilecegi bir kapi olurdu.
//  2. Kod istendikten sonra ekran KOD ADIMINA gecer ve mesaj adres
//     varligini SIZDIRMAZ ("kayitliysa gonderildi").
//  3. Kod alani `autocomplete="one-time-code"` tasir — bu olmadan iOS ve
//     Android gelen koddan okuyup ONERMEZ ve kullanici elle yazar.
//  4. Yanlis kodda SUNUCUNUN metni gosterilir, uydurma bir metin degil.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import React from "react";

import { GirisFormu } from "@/components/GirisFormu";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  usePathname: () => "/login",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.unstubAllGlobals());

const KOD_DUGMESI = /Parola yerine e-postaya kod gönder/i;

function epostaFormu() {
  return () => React.createElement(GirisFormu, { yuzey: "platform" } as never);
}

/** URL'ye gore yanit veren `fetch` taklidi.
 *
 * SIRAYA GORE (`mockResolvedValueOnce`) yazilamaz: form icindeki
 * `SosyalGiris` montajda `/api/auth/oauth/saglayicilar`i cagiriyor ve
 * ilk sirayi O tuketiyor (olculdu). URL'ye bakmak hem dogru hem de
 * bilesen yeni bir cagri eklediginde kirilmiyor.
 */
function fetchTaklidi(yanitlar: Record<string, unknown>) {
  const cagri = vi.fn(async (url: string) => {
    for (const [parca, yanit] of Object.entries(yanitlar)) {
      if (String(url).includes(parca)) return yanit as Response;
    }
    return { ok: true, status: 200, json: async () => ({}) } as unknown as Response;
  });
  vi.stubGlobal("fetch", cagri);
  return cagri;
}

const OK_BOS = {
  ok: true, status: 200, json: async () => ({ durum: "onay_bekliyor" }),
} as unknown as Response;

async function alanlariDoldur() {
  await userEvent.type(screen.getByLabelText(/Tesis \(slug\)/i), "demo");
  await userEvent.type(screen.getByLabelText(/E-posta/i), "a@example.com");
}

describe("kod ile giris — yuzey", () => {
  it("TELEFON yuzeyinde (app.*) YOL GORUNMEZ", () => {
    ciz(() => React.createElement(GirisFormu, { yuzey: "tesis" } as never));
    expect(screen.queryByText(KOD_DUGMESI)).toBeNull();
  });

  it("E-POSTA yuzeyinde (panel.*) yol gorunur", () => {
    ciz(epostaFormu());
    expect(screen.getByText(KOD_DUGMESI)).toBeTruthy();
  });
});

describe("kod akisi", () => {
  it("kod istenince KOD ADIMINA gecer ve adres varligini SIZDIRMAZ", async () => {
    const cagri = fetchTaklidi({ "eposta-kod?adim=iste": OK_BOS });

    ciz(epostaFormu());
    await alanlariDoldur();
    await userEvent.click(screen.getByText(KOD_DUGMESI));

    // Kod alani geldi; parola alani gitti.
    const kodAlani = await screen.findByLabelText(/Doğrulama kodu/i);
    expect(kodAlani.getAttribute("autocomplete")).toBe("one-time-code");
    expect(document.getElementById("yz-parola")).toBeNull();

    // MESAJ KOSULLU: "gonderildi" demek adresin kayitli oldugunu
    // sizdirmak olurdu.
    expect(screen.getByText(/kayıtlıysa kod e-postayla gönderildi/i)).toBeTruthy();

    expect(
      cagri.mock.calls.some((c) =>
        String(c[0]).includes("/api/auth/eposta-kod?adim=iste"),
      ),
    ).toBe(true);
  });

  it("YANLIS KODDA sunucunun metni gosterilir", async () => {
    const cagri = fetchTaklidi({
      "adim=iste": OK_BOS,
      "adim=dogrula": {
        ok: false, status: 422,
        json: async () => ({
          error: { code: "invalid_code", message: "Kod geçersiz." },
        }),
      } as unknown as Response,
    });

    ciz(epostaFormu());
    await alanlariDoldur();
    await userEvent.click(screen.getByText(KOD_DUGMESI));
    await userEvent.type(await screen.findByLabelText(/Doğrulama kodu/i), "000000");
    // TAM AD: "Parolayla giriş yap" baglantisi da /Giriş yap/i ile
    // eslesiyor (olculdu) — gonderim dugmesi tam adiyla hedefleniyor.
    await userEvent.click(screen.getByRole("button", { name: "Giriş yap" }));

    await waitFor(() => expect(screen.getByText("Kod geçersiz.")).toBeTruthy());
    expect(
      cagri.mock.calls.some((c) => String(c[0]).includes("adim=dogrula")),
    ).toBe(true);
  });

  it("PAROLAYA DONULEBILIR — yol tek yonlu degil", async () => {
    fetchTaklidi({ "adim=iste": OK_BOS });

    ciz(epostaFormu());
    await alanlariDoldur();
    await userEvent.click(screen.getByText(KOD_DUGMESI));
    await screen.findByLabelText(/Doğrulama kodu/i);

    await userEvent.click(screen.getByText(/Parolayla giriş yap/i));
    await waitFor(() => expect(document.getElementById("yz-parola")).not.toBeNull());
  });
});
