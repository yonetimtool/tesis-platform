// @vitest-environment jsdom
// (P232) TEK MODALDA COK GRUPLU VARDIYA — web yuzeyi.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// Arka uc `gruplar` alanini kabul ediyor (test_p232_cok_gruplu_vardiya.py).
// Bu dosya ORTA HALKAYI olcer: modal gruplari BIRIKTIRIYOR mu ve TEK
// istekte gonderiyor mu? P226/P229 dersi — iki uc ayri ayri dogru olabilir
// ve arada kalan halka olculmemis olabilir.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { KalipModali } from "@/components/vardiya/kalip-modali";

import { ciz } from "./yardimci";

type Cagri = { url: string; govde: unknown };

function fetchSahtele(cagrilar: Cagri[]) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      if (url.startsWith("/api/vardiya-plani/kaliplar")) {
        return new Response(JSON.stringify({ items: [] }), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      if (url.startsWith("/api/vardiya-plani/kalip-uygula")) {
        cagrilar.push({ url, govde: JSON.parse(String(init?.body ?? "{}")) });
        return new Response(
          JSON.stringify({
            uygulandi: false, parti_id: null, eklenecek: 3, eklenen: 0,
            cakisan: 0, zaten_var: 0, satirlar: [], uyarilar: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } },
        );
      }
      return new Response("{}", {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }),
  );
}

const PERSONEL = [
  { id: "u1", ad: "Ahmet", role: "security" },
  { id: "u2", ad: "Mehmet", role: "security" },
];

/** Ilk dilime ilk kisiyi atar (coklu secim listesi). */
async function atamaYap() {
  const liste = document.querySelector<HTMLSelectElement>(
    '[data-test="kalip-atama-0"]',
  );
  expect(liste, "atama listesi cizilmedi").toBeTruthy();
  await userEvent.selectOptions(liste!, ["u1"]);
}

afterEach(() => vi.restoreAllMocks());

describe("(P232) cok gruplu vardiya modali", () => {
  it("GRUP EKLENINCE sayfa gun secimini temizlesin diye geri cagrilir", async () => {
    const cagrilar: Cagri[] = [];
    fetchSahtele(cagrilar);
    const temizlendi = vi.fn();
    ciz(() =>
      createElement(KalipModali, {
        acik: true,
        gunler: ["2026-03-02"],
        personel: PERSONEL,
        onKapat: () => {},
        onUygulandi: () => {},
        onGrupEklendi: temizlendi,
      }),
    );

    // Dilime kisi ata (yoksa "gruba ekle" kapali).
    // NOT: depo `data-test` kullaniyor, `data-testid` DEGIL — ve atama
    // denetimi bir COKLU SECIM listesi, onay kutusu degil (olculdu).
    await waitFor(() =>
      expect(document.querySelector('[data-test="kalip-atama-0"]')).toBeTruthy(),
    );
    await atamaYap();

    const ekle = document.querySelector<HTMLButtonElement>(
      '[data-test="kalip-gruba-ekle"]',
    );
    expect(ekle, "gruba ekle dugmesi yok").toBeTruthy();
    await userEvent.click(ekle!);
    expect(temizlendi).toHaveBeenCalled();
  });

  it("EKLENEN GRUPLAR tek istekte `gruplar` olarak gider", async () => {
    const cagrilar: Cagri[] = [];
    fetchSahtele(cagrilar);
    ciz(() =>
      createElement(KalipModali, {
        acik: true,
        gunler: ["2026-03-02", "2026-03-03"],
        personel: PERSONEL,
        onKapat: () => {},
        onUygulandi: () => {},
        onGrupEklendi: () => {},
      }),
    );

    await waitFor(() =>
      expect(document.querySelector('[data-test="kalip-atama-0"]')).toBeTruthy(),
    );
    await atamaYap();
    await userEvent.click(
      document.querySelector<HTMLButtonElement>('[data-test="kalip-gruba-ekle"]')!,
    );

    // Onizleme: `gruplar` gitmeli, tekil `gunler` DEGIL.
    const onizle = document.querySelector<HTMLButtonElement>(
      '[data-test="kalip-onizle"]',
    );
    expect(onizle, "onizleme dugmesi bulunamadi").toBeTruthy();
    await userEvent.click(onizle!);

    await waitFor(() => expect(cagrilar.length).toBeGreaterThan(0));
    const govde = cagrilar[0].govde as Record<string, unknown>;
    expect(govde.gruplar, "cok gruplu bicim gonderilmedi").toBeTruthy();
    expect(Array.isArray(govde.gruplar)).toBe(true);
  });
});
