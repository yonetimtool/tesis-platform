// @vitest-environment jsdom
// (P243 §1) VARDIYA EKLEME MODALI — SADELESTIRME.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
//  * Kaldirilan alanlar GERCEKTEN yok (rol, lokasyon, tarihler),
//  * saatler DURUYOR,
//  * rol SUZGECI listeyi daraltiyor ve vardiyaya KAYDEDILMIYOR,
//  * onizleme CALISIYOR (kac vardiya olusacagini gosteriyor),
//  * coklu kalip P232'nin GRUP yapisindan geliyor (yeni kavram yok).
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/vardiya-plani/page";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const BUGUN = new Date().toISOString().slice(0, 10);

function taklit(): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    let govde: unknown = { ok: true };
    if (url.startsWith("/api/vardiya-plani/cizelge")) {
      govde = { baslangic: BUGUN, bitis: BUGUN, personel: [] };
    } else if (url.includes("/vardiya-plani/simdi")) {
      govde = {
        gorevdeki_vardiya: null,
        gorevdekiler: [],
        sonraki_vardiya: null,
        sonrakiler: [],
      };
    } else if (url.includes("/vardiya-plani/kaliplar")) {
      govde = {
        items: [
          {
            id: "k-1",
            ad: "2 vardiya",
            aktif: true,
            dilimler: [
              { ad: "Gunduz", baslangic: "08:00", bitis: "20:00" },
              { ad: "Gece", baslangic: "20:00", bitis: "08:00" },
            ],
          },
          {
            id: "k-2",
            ad: "Hafta sonu",
            aktif: true,
            dilimler: [{ ad: "Tam gun", baslangic: "09:00", bitis: "21:00" }],
          },
        ],
      };
    } else if (url.startsWith("/api/users")) {
      govde = {
        items: [
          { id: "u-1", ad: "Ali Guvenlik", role: "security" },
          { id: "u-2", ad: "Veli Temizlik", role: "tesis_gorevlisi" },
          { id: "u-3", ad: "Sakin Kisi", role: "resident" },
        ],
      };
    } else if (url.includes("/vardiya-plani/kalip-uygula")) {
      const body = init?.body ? JSON.parse(String(init.body)) : {};
      // ONIZLEME GERCEKCI: kac satir olusacagini gruplardan hesapla.
      const gruplar = (body.gruplar ?? []) as {
        gunler: string[];
        dilimler: unknown[];
        atamalar: Record<string, string[]>;
      }[];
      const adet = gruplar.reduce(
        (t, g) =>
          t +
          g.gunler.length *
            Object.values(g.atamalar ?? {}).reduce((a, k) => a + k.length, 0),
        0,
      );
      govde = {
        uygulandi: !body.kuru,
        parti_id: body.kuru ? null : "pt-1",
        eklenecek: adet,
        eklenen: body.kuru ? 0 : adet,
        cakisan: 0,
        satirlar: [],
      };
    } else if (url.includes("/vardiya-plani/yayin-ozeti")) {
      govde = { bekleyen: 0, taslak: 0, degisen: 0 };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

async function modaliAc(k: ReturnType<typeof userEvent.setup>) {
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-ekle-kisi")).toBeTruthy());
}

afterEach(() => vi.restoreAllMocks());

it("(§1a/§1b) ROL ve LOKASYON alanlari YOK", async () => {
  // Rol kisi eklenirken zaten belirleniyor; lokasyon referanstaki
  // "sube"nin karsiligiydi ve bizde karsiligi yok.
  const k = userEvent.setup();
  taklit();
  await modaliAc(k);
  expect(kanca("vardiya-ekle-rol")).toBeNull();
  expect(kanca("vardiya-ekle-lokasyon")).toBeNull();
});

it("(§1c) TARIH alanlari YOK, SAATLER DURUYOR", async () => {
  const k = userEvent.setup();
  taklit();
  await modaliAc(k);
  expect(kanca("vardiya-ekle-bas-tarih")).toBeNull();
  expect(kanca("vardiya-ekle-son-tarih")).toBeNull();
  // Saatler takvimden TURETILEMEZ — kaldi.
  expect(kanca("vardiya-ekle-bas-saat")).toBeTruthy();
  expect(kanca("vardiya-ekle-son-saat")).toBeTruthy();
});

it("(§1d) ROL SUZGECI listeyi daraltir; SAKIN hicbir durumda YOK", async () => {
  const k = userEvent.setup();
  taklit();
  await modaliAc(k);
  const kisiler = () =>
    Array.from((kanca("vardiya-ekle-kisi") as HTMLSelectElement).options).map(
      (o) => o.textContent,
    );
  expect(kisiler()).toContain("Ali Guvenlik");
  expect(kisiler()).toContain("Veli Temizlik");
  expect(kisiler()).not.toContain("Sakin Kisi");

  await k.selectOptions(kanca("vardiya-ekle-rol-suzgeci")!, "security");
  expect(kisiler()).toContain("Ali Guvenlik");
  expect(kisiler()).not.toContain("Veli Temizlik");
});

it("(§1d) ROL SUZGECI GOVDEDE GITMEZ — kaydedilen bir alan degil", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await modaliAc(k);
  await k.selectOptions(kanca("vardiya-ekle-rol-suzgeci")!, "security");
  await k.selectOptions(kanca("vardiya-ekle-kisi")!, "u-1");
  await k.click(
    document.querySelector(`[data-test^="vardiya-ekle-gun-"]`) as HTMLElement,
  );
  await k.click(kanca("vardiya-ekle-gonder")!);
  await waitFor(() =>
    expect(
      cagrilar.some((c) => c.url.includes("/vardiya-plani/kalip-uygula")),
    ).toBe(true),
  );
  const govde = cagrilar.find((c) =>
    c.url.includes("/vardiya-plani/kalip-uygula"),
  )!.govde;
  expect(JSON.stringify(govde)).not.toContain("rol_suzgeci");
  expect(govde.vardiya_rolu).toBeUndefined();
});

it("(§1e) ROTASYONDA AYLIK secenegi var", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await modaliAc(k);
  const secim = kanca("vardiya-ekle-rotasyon") as HTMLSelectElement;
  expect(Array.from(secim.options).map((o) => o.value)).toContain("aylik");

  await k.selectOptions(secim, "aylik");
  await k.selectOptions(kanca("vardiya-ekle-kisi")!, "u-1");
  await k.click(
    document.querySelector(`[data-test^="vardiya-ekle-gun-"]`) as HTMLElement,
  );
  await k.click(kanca("vardiya-ekle-gonder")!);
  await waitFor(() =>
    expect(
      cagrilar.find((c) => c.url.includes("/vardiya-plani/kalip-uygula"))!.govde
        .rotasyon,
    ).toBe("aylik"),
  );
});

it("(§1g) ONIZLEME CALISIYOR: kac vardiya olusacagini gosterir", async () => {
  // KOK NEDEN (olculdu): onizleme grup uzerinden gidiyor, grup ise
  // SECILI GUNLERDEN kuruluyordu. Tarih alanlarini doldurup takvimden
  // gun secmeyen kullanicinin "Onizle" dugmesi SESSIZCE hicbir sey
  // yapmiyordu. Tarih alanlari kalkinca tek yol kaldi.
  const k = userEvent.setup();
  const cagrilar = taklit();
  await modaliAc(k);
  await k.selectOptions(kanca("vardiya-ekle-kisi")!, "u-1");
  const gunler = Array.from(
    document.querySelectorAll(`[data-test^="vardiya-ekle-gun-"]`),
  ).slice(0, 3) as HTMLElement[];
  for (const g of gunler) await k.click(g);

  await k.click(kanca("vardiya-onizle")!);
  await waitFor(() => expect(kanca("vardiya-ekle-onizleme")).toBeTruthy());
  // UC GUN x BIR KISI = UC VARDIYA.
  expect(kanca("vardiya-ekle-onizleme")!.textContent).toContain("3");
  // ONIZLEME HICBIR SEY YAZMAZ.
  const kuru = cagrilar.find((c) =>
    c.url.includes("/vardiya-plani/kalip-uygula"),
  )!;
  expect(kuru.govde.kuru).toBe(true);
});

it("(§1f) COKLU KALIP: her GRUP kendi kalibini tasir (P232 yapisi)", async () => {
  // Yeni bir kavram URETILMEDI: `VardiyaGunGrubu` zaten `kalip_id`
  // tasiyordu; eksik olan modalin kalibi GRUBA baglamasiydi.
  const k = userEvent.setup();
  const cagrilar = taklit();
  await modaliAc(k);

  // 1. grup: "2 vardiya" kalibi.
  await k.selectOptions(kanca("vardiya-ekle-kalip")!, "k-1");
  await waitFor(() => expect(kanca("vardiya-ekle-dilimler")).toBeTruthy());
  const dilimSecimleri = Array.from(
    document.querySelectorAll('[data-test^="vardiya-ekle-dilim-"]'),
  ) as HTMLSelectElement[];
  await k.selectOptions(dilimSecimleri[0], "u-1");
  await k.click(
    document.querySelector(`[data-test^="vardiya-ekle-gun-"]`) as HTMLElement,
  );
  await k.click(kanca("vardiya-ekle-gruba-ekle")!);

  // 2. grup: BASKA kalip.
  await k.selectOptions(kanca("vardiya-ekle-kalip")!, "k-2");
  await waitFor(() => expect(kanca("vardiya-ekle-dilimler")).toBeTruthy());
  const ikinci = Array.from(
    document.querySelectorAll('[data-test^="vardiya-ekle-dilim-"]'),
  ) as HTMLSelectElement[];
  await k.selectOptions(ikinci[0], "u-2");
  const hucreler = Array.from(
    document.querySelectorAll(`[data-test^="vardiya-ekle-gun-"]`),
  ) as HTMLElement[];
  await k.click(hucreler[5]);
  await k.click(kanca("vardiya-ekle-gonder")!);

  await waitFor(() =>
    expect(
      cagrilar.some((c) => c.url.includes("/vardiya-plani/kalip-uygula")),
    ).toBe(true),
  );
  const gruplar = cagrilar
    .filter((c) => c.url.includes("/vardiya-plani/kalip-uygula"))
    .at(-1)!.govde.gruplar as { kalip_id: string | null }[];
  expect(gruplar.length).toBe(2);
  expect(gruplar[0].kalip_id).toBe("k-1");
  expect(gruplar[1].kalip_id).toBe("k-2");
});
