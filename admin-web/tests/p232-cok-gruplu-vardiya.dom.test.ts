// @vitest-environment jsdom
// (P232 · P235 §1) TEK MODALDA COK GRUPLU VARDIYA — web yuzeyi.
//
// (P235 §1) `KalipModali` SILINDI: web'de iki ayri vardiya ekleme
// ekrani vardi ve ikisi ayni isi farkli sirayla soruyordu. Mobilde tek
// akis var (takvim -> kisi/saat -> gruba ekle -> onizleme) ve web ona
// esitlendi. Bu dosya ayni sozlesmeyi YENI modalda olcuyor —
// olculen sey degismedi: gruplar BIRIKIYOR mu ve TEK istekte gidiyor mu.
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

import { VardiyaEkleModali } from "@/components/vardiya/vardiya-ekle-modali";

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

/** (P235 §1) Takvimden gun secer + serbest saatte kisi atar.
 *
 * YENI AKIS: once TAKVIM. Eski modalda gunler disaridan `gunler`
 * prop'uyla geliyordu; simdi kullanici onlari modalin icinde seciyor —
 * mobildeki sira budur. */
async function gunVeKisiSec(gun: string) {
  const g = document.querySelector<HTMLButtonElement>(
    `[data-test="vardiya-ekle-gun-${gun}"]`,
  );
  expect(g, `gun dugmesi cizilmedi: ${gun}`).toBeTruthy();
  await userEvent.click(g!);
  const kisi = document.querySelector<HTMLSelectElement>(
    '[data-test="vardiya-ekle-kisi"]',
  );
  expect(kisi, "kisi listesi cizilmedi").toBeTruthy();
  await userEvent.selectOptions(kisi!, ["u1"]);
}

afterEach(() => vi.restoreAllMocks());

describe("(P232) cok gruplu vardiya modali", () => {
  it("GRUP EKLENINCE takvim secimi TEMIZLENIR", async () => {
    // Yoksa kullanici ayni gunleri ikinci gruba da yazar ve KENDI KENDINE
    // cakisma uretirdi (mobildeki ayni gerekce).
    const cagrilar: Cagri[] = [];
    fetchSahtele(cagrilar);
    ciz(() =>
      createElement(VardiyaEkleModali, {
        acik: true,
        personel: PERSONEL,
        baslangicAyi: "2026-03-01",
        onSecilenGunler: [],
        onKapat: () => {},
        onBitti: () => {},
      }),
    );

    await waitFor(() =>
      expect(
        document.querySelector('[data-test="vardiya-ekle-takvim"]'),
      ).toBeTruthy(),
    );
    await gunVeKisiSec("2026-03-02");
    expect(
      document.querySelector('[data-test="vardiya-ekle-secili-sayi"]')
        ?.textContent,
    ).toContain("1");

    await userEvent.click(
      document.querySelector<HTMLButtonElement>(
        '[data-test="vardiya-ekle-gruba-ekle"]',
      )!,
    );
    expect(
      document.querySelector('[data-test="vardiya-ekle-secili-sayi"]')
        ?.textContent,
    ).toContain("0");
    expect(
      document.querySelector('[data-test="vardiya-ekle-grup-sayisi"]'),
    ).toBeTruthy();
  });

  it("EKLENEN GRUPLAR tek istekte `gruplar` olarak gider", async () => {
    const cagrilar: Cagri[] = [];
    fetchSahtele(cagrilar);
    ciz(() =>
      createElement(VardiyaEkleModali, {
        acik: true,
        personel: PERSONEL,
        baslangicAyi: "2026-03-01",
        onSecilenGunler: [],
        onKapat: () => {},
        onBitti: () => {},
      }),
    );

    await waitFor(() =>
      expect(
        document.querySelector('[data-test="vardiya-ekle-takvim"]'),
      ).toBeTruthy(),
    );
    await gunVeKisiSec("2026-03-02");
    await userEvent.click(
      document.querySelector<HTMLButtonElement>(
        '[data-test="vardiya-ekle-gruba-ekle"]',
      )!,
    );

    // Onizleme: `gruplar` gitmeli, tekil `gunler` DEGIL.
    const onizle = document.querySelector<HTMLButtonElement>(
      '[data-test="vardiya-onizle"]',
    );
    expect(onizle, "onizleme dugmesi bulunamadi").toBeTruthy();
    await userEvent.click(onizle!);

    await waitFor(() => expect(cagrilar.length).toBeGreaterThan(0));
    const govde = cagrilar[0].govde as Record<string, unknown>;
    expect(govde.gruplar, "cok gruplu bicim gonderilmedi").toBeTruthy();
    expect(Array.isArray(govde.gruplar)).toBe(true);
  });
});
