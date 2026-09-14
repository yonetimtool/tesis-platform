// @vitest-environment jsdom
// (P233 §1) TESIS KONUMU — web yuzeyi.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// `konum_lat/lon` goc 0005'ten beri VAR ve `/weather` onlari kullaniyor,
// ama HIC AYARLANMIYORDU: dev'deki TUM tesisler sunucu varsayilani olan
// Istanbul koordinatini tasiyor (41.0082, 28.9784). Erzurum'daki tesis
// Istanbul havasini gosteriyordu — ve bu, fark edilmesi en zor kusur
// sinifindan: ekran CALISIYOR gorunur.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { KonumSecici } from "@/components/KonumSecici";

import { ciz } from "./yardimci";

const ADAYLAR = {
  q: "Oltu",
  items: [
    { ad: "Oltu", aciklama: "Erzurum, Türkiye", lat: 40.53945, lon: 41.98722 },
    { ad: "Oltuca", aciklama: "Artvin, Türkiye", lat: 41.2118, lon: 42.25735 },
  ],
};

function fetchSahtele(yanit: unknown, durum = 200) {
  const cagrilar: string[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (girdi: RequestInfo | URL) => {
      cagrilar.push(String(girdi));
      return new Response(JSON.stringify(yanit), {
        status: durum,
        headers: { "content-type": "application/json" },
      });
    }),
  );
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

describe("(P233 §1) konum secici", () => {
  it("ADAY LISTESI cizilir — ilki OTOMATIK SECILMEZ", async () => {
    // Sunucunun ilkini secip "buldum" demesi, yoneticinin HIC GORMEDIGI
    // bir konumu tesise yazmak olurdu.
    const secilen: unknown[] = [];
    fetchSahtele(ADAYLAR);
    ciz(() =>
      createElement(KonumSecici, {
        mevcutAd: "İstanbul",
        onSec: (a) => secilen.push(a),
      }),
    );
    await userEvent.type(
      document.querySelector<HTMLInputElement>('[data-test="konum-ara"]')!,
      "Oltu",
    );
    await userEvent.click(
      document.querySelector<HTMLButtonElement>('[data-test="konum-ara-dugme"]')!,
    );
    await waitFor(() =>
      expect(document.querySelector('[data-test="konum-adaylar"]')).toBeTruthy(),
    );
    expect(secilen, "aday otomatik secildi").toHaveLength(0);
    expect(
      document.querySelectorAll('[data-test="konum-adaylar"] li').length,
    ).toBe(2);
  });

  it("ADAY SECILINCE ad VE koordinat birlikte gider", async () => {
    // Yalniz adi yazip koordinati bosta birakmak, hava durumunu eski
    // konumda birakirdi — kullanici "kaydettim" der, hava degismez.
    const secilen: { ad: string; lat: number; lon: number }[] = [];
    fetchSahtele(ADAYLAR);
    ciz(() =>
      createElement(KonumSecici, { mevcutAd: "", onSec: (a) => secilen.push(a) }),
    );
    await userEvent.type(
      document.querySelector<HTMLInputElement>('[data-test="konum-ara"]')!,
      "Oltu",
    );
    await userEvent.click(
      document.querySelector<HTMLButtonElement>('[data-test="konum-ara-dugme"]')!,
    );
    await waitFor(() =>
      expect(document.querySelector('[data-test="konum-aday-40.53945"]')).toBeTruthy(),
    );
    await userEvent.click(
      document.querySelector<HTMLButtonElement>('[data-test="konum-aday-40.53945"]')!,
    );
    expect(secilen).toHaveLength(1);
    expect(secilen[0].ad).toBe("Oltu");
    expect(secilen[0].lat).toBeCloseTo(40.53945, 4);
    expect(secilen[0].lon).toBeCloseTo(41.98722, 4);
  });

  it("UC DUSERSE hata gosterir — BOS LISTE GOSTERMEZ", async () => {
    // Bos liste "boyle bir yer yok" demektir ve servis coktugunde bu
    // YANLIS bir cumledir; kullaniciyi adresini yanlis yazdigini
    // sanmaya iter.
    fetchSahtele({ detail: "yok" }, 503);
    ciz(() =>
      createElement(KonumSecici, { mevcutAd: "", onSec: () => {} }),
    );
    await userEvent.type(
      document.querySelector<HTMLInputElement>('[data-test="konum-ara"]')!,
      "Oltu",
    );
    await userEvent.click(
      document.querySelector<HTMLButtonElement>('[data-test="konum-ara-dugme"]')!,
    );
    await waitFor(() =>
      expect(document.body.textContent).toMatch(/yanıt vermiyor|responding/i),
    );
    expect(document.querySelector('[data-test="konum-adaylar"]')).toBeNull();
  });

  it("BFF rotasi GET export eder (yoksa 405)", async () => {
    const rota = await import("@/app/api/konum/ara/route");
    expect(typeof rota.GET).toBe("function");
  });
});
