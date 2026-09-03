// @vitest-environment jsdom
// (P207 §1) AY GORUNUMUNDE GUN SECIMI + KALIP UYGULAMA + GERI ALMA.
//
// Olculen sey EKRANIN DAVRANISI + GIDEN GOVDE. Kurallar sunucuda kilitli
// (`test_p207_kalip.py`); burada olculen, arayuzun SECIMI dogru tasidigi,
// ONIZLEMEYI kaydetmeden yaptigi, cakismayi GOSTERDIGI ve GERI ALMAYI
// sundugu.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/vardiya-plani/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

// (Ay gorunumu BASLANGIC gununden itibaren 31 gun cizer; testte bugun
// hangi gun olursa olsun ilk sutun `bugun`dur.)
const BUGUN = new Date().toISOString().slice(0, 10);
function gunEkle(iso: string, n: number): string {
  const d = new Date(`${iso}T00:00:00`);
  d.setDate(d.getDate() + n);
  return d.toISOString().slice(0, 10);
}

function taklit(opts: { uygula?: unknown } = {}): Cagri[] {
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
      govde = {
        baslangic: BUGUN,
        bitis: BUGUN,
        personel: [
          { user_id: "u-1", ad: "Ali Guvenlik", rol: "security", bloklar: [] },
        ],
      };
    } else if (url.includes("/vardiya-plani/kaliplar")) {
      govde = {
        items: [
          {
            id: "k-1",
            ad: "Iki Vardiya",
            aktif: true,
            dilimler: [
              { ad: "Gunduz", baslangic: "08:00", bitis: "20:00" },
              { ad: "Gece", baslangic: "20:00", bitis: "08:00" },
            ],
          },
        ],
      };
    } else if (url === "/api/vardiya-plani/kalip-uygula") {
      govde =
        opts.uygula ??
        {
          uygulandi: true,
          parti_id: "parti-1",
          eklenecek: 0,
          eklenen: 4,
          cakisan: 0,
          zaten_var: 0,
          satirlar: [],
          uyarilar: [],
        };
    } else if (url.includes("/vardiya-plani/simdi")) {
      govde = { gorevdeki_vardiya: null, gorevdekiler: [], sonraki_vardiya: null, sonrakiler: [] };
    } else if (url.startsWith("/api/users")) {
      govde = { items: [{ id: "u-1", ad: "Ali Guvenlik", role: "security" }] };
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

async function ayGorunumu(k: ReturnType<typeof userEvent.setup>) {
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorunum-ay")).toBeTruthy());
  await k.click(kanca("vardiya-gorunum-ay")!);
  await waitFor(() => expect(kanca("vardiya-secim-araclari")).toBeTruthy());
}

afterEach(() => vi.restoreAllMocks());

// ========================== GUN SECIMI ================================== #

it("SECIM ARACLARI yalniz AY gorunumunde cizilir", async () => {
  // Gun/hafta gorunumunde bir avuc gun vardir; cubugu her gorunumde
  // cizmek, ekrani kullanilmayan bir araca ayirmak olurdu.
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorunum-gun")).toBeTruthy());
  await k.click(kanca("vardiya-gorunum-gun")!);
  expect(kanca("vardiya-secim-araclari")).toBeNull();
  await k.click(kanca("vardiya-gorunum-ay")!);
  await waitFor(() => expect(kanca("vardiya-secim-araclari")).toBeTruthy());
});

it("GUNE TIKLAMAK secer, TEKRAR tiklamak KALDIRIR", async () => {
  const k = userEvent.setup();
  taklit();
  await ayGorunumu(k);
  const gun = kanca(`vardiya-gun-sec-${BUGUN}`)!;
  await k.click(gun);
  await waitFor(() =>
    expect(kanca("vardiya-secim-sayisi")!.textContent).toContain("1"),
  );
  expect(gun.getAttribute("aria-pressed")).toBe("true");
  await k.click(gun);
  await waitFor(() =>
    expect(kanca("vardiya-secim-sayisi")!.textContent).toContain("0"),
  );
});

it("HAFTA GUNU KALIBI: 'tum pazartesiler' toplu secer", async () => {
  // Otuz gunluk seritte pazartesileri tek tek tiklamak, dort-bes
  // tiklama ve her birinde yanlis sutuna basma ihtimali demekti.
  const k = userEvent.setup();
  taklit();
  await ayGorunumu(k);
  await k.click(kanca("vardiya-hafta-gunu-1")!);
  await waitFor(() => {
    const metin = kanca("vardiya-secim-sayisi")!.textContent ?? "";
    // 31 gunluk pencerede en az dort pazartesi vardir.
    expect(/[4-5] gün/.test(metin)).toBe(true);
  });
});

it("SECIMI TEMIZLE sifirlar", async () => {
  const k = userEvent.setup();
  taklit();
  await ayGorunumu(k);
  await k.click(kanca("vardiya-hafta-gunu-3")!);
  await k.click(kanca("vardiya-secimi-temizle")!);
  await waitFor(() =>
    expect(kanca("vardiya-secim-sayisi")!.textContent).toContain("0"),
  );
});

// ========================== KALIP UYGULA ================================ #

async function pencereyiAc(k: ReturnType<typeof userEvent.setup>) {
  await ayGorunumu(k);
  await k.click(kanca(`vardiya-gun-sec-${BUGUN}`)!);
  await k.click(kanca(`vardiya-gun-sec-${gunEkle(BUGUN, 1)}`)!);
  await k.click(kanca("vardiya-kalip-ac")!);
  await waitFor(() => expect(kanca("kalip-sec")).toBeTruthy());
}

it("SECIM YOKKEN kalip dugmesi PASIF", async () => {
  const k = userEvent.setup();
  taklit();
  await ayGorunumu(k);
  expect((kanca("vardiya-kalip-ac") as HTMLButtonElement).disabled).toBe(true);
});

it("ONIZLEME kaydetmeden KAC VARDIYA olusacagini sorar", async () => {
  // Kabul kriteri 4. `kuru=true` gider ve YAZMA yapilmaz.
  const k = userEvent.setup();
  const cagrilar = taklit({
    uygula: {
      uygulandi: false, parti_id: null, eklenecek: 4, eklenen: 0,
      cakisan: 0, zaten_var: 0, satirlar: [], uyarilar: [],
    },
  });
  await pencereyiAc(k);
  await k.selectOptions(kanca("kalip-sec")!, "k-1");
  await waitFor(() => expect(kanca("kalip-atama-0")).toBeTruthy());
  await k.selectOptions(kanca("kalip-atama-0")!, "u-1");
  await k.click(kanca("kalip-onizle")!);

  await waitFor(() => expect(kanca("kalip-sonuc")).toBeTruthy());
  const post = cagrilar.find((c) => c.url === "/api/vardiya-plani/kalip-uygula")!;
  expect(post.govde.kuru).toBe(true);
  expect((post.govde.gunler as string[]).length).toBe(2);
  expect(kanca("kalip-sonuc")!.textContent).toContain("4");
});

it("UYGULA govdesi: SECILI GUNLER + dilim atamalari + rotasyon", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("kalip-sec")!, "k-1");
  await waitFor(() => expect(kanca("kalip-atama-1")).toBeTruthy());
  await k.selectOptions(kanca("kalip-atama-1")!, "u-1");
  await k.selectOptions(kanca("kalip-rotasyon")!, "haftalik");
  await k.click(kanca("kalip-uygula")!);

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/vardiya-plani/kalip-uygula")).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/vardiya-plani/kalip-uygula")!;
  expect(post.govde.kalip_id).toBe("k-1");
  expect(post.govde.rotasyon).toBe("haftalik");
  expect((post.govde.atamalar as Record<string, string[]>)["1"]).toEqual(["u-1"]);
  expect(post.govde.kuru).toBeUndefined();
});

it("CAKISMA: hangi gun/dilim/kisi oldugu YAZILIR, karar KULLANICININ", async () => {
  // P205 kurali korundu (kabul kriteri 5).
  const k = userEvent.setup();
  const cagrilar = taklit({
    uygula: {
      uygulandi: false, parti_id: null, eklenecek: 1, eklenen: 0,
      cakisan: 1, zaten_var: 0,
      satirlar: [
        {
          tarih: BUGUN, dilim: "Gunduz", baslangic: "08:00", bitis: "20:00",
          user_id: "u-1", ad: "Ali Guvenlik", durum: "cakisma",
        },
      ],
      uyarilar: [],
    },
  });
  await pencereyiAc(k);
  await k.selectOptions(kanca("kalip-sec")!, "k-1");
  await waitFor(() => expect(kanca("kalip-atama-0")).toBeTruthy());
  await k.selectOptions(kanca("kalip-atama-0")!, "u-1");
  await k.click(kanca("kalip-uygula")!);

  await waitFor(() => expect(kanca("kalip-cakisma")).toBeTruthy());
  expect(kanca("kalip-cakisma")!.textContent).toContain("Gunduz");
  expect(kanca("kalip-cakisma")!.textContent).toContain("Ali Guvenlik");

  await k.click(kanca("kalip-cakisan-haric")!);
  await waitFor(() =>
    expect(
      cagrilar.filter((c) => c.url === "/api/vardiya-plani/kalip-uygula").length,
    ).toBe(2),
  );
  expect(
    cagrilar.filter((c) => c.url === "/api/vardiya-plani/kalip-uygula").at(-1)!
      .govde.cakisanlari_atla,
  ).toBe(true);
});

// =========================== GERI ALMA ================================== #

it("UYGULAMADAN SONRA 'geri al' cikar ve PARTIYI geri alir", async () => {
  // Istegin KRITIK sarti: 30 gunluk yanlis plani tek tek silmek yok.
  const k = userEvent.setup();
  const cagrilar = taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("kalip-sec")!, "k-1");
  await waitFor(() => expect(kanca("kalip-atama-0")).toBeTruthy());
  await k.selectOptions(kanca("kalip-atama-0")!, "u-1");
  await k.click(kanca("kalip-uygula")!);

  await waitFor(() => expect(kanca("vardiya-parti-geri-al")).toBeTruthy());
  await k.click(kanca("vardiya-parti-geri-al")!);
  await waitFor(() =>
    expect(
      cagrilar.some((c) =>
        c.url === "/api/vardiya-plani/parti/parti-1/geri-al",
      ),
    ).toBe(true),
  );
  // Geri alindiktan sonra dugme KAYBOLUR: ikinci kez basmak 404 alirdi.
  await waitFor(() => expect(kanca("vardiya-parti-geri-al")).toBeNull());
});

it("KAYDEDILMEMIS kalipla da uygulanabilir (tek seferlik plan)", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await pencereyiAc(k);
  // Kalip secilmedi: dilimler pencerede tanimli (varsayilan iki vardiya).
  await waitFor(() => expect(kanca("kalip-dilimler")).toBeTruthy());
  await k.selectOptions(kanca("kalip-atama-0")!, "u-1");
  await k.click(kanca("kalip-uygula")!);

  const post = cagrilar.find((c) => c.url === "/api/vardiya-plani/kalip-uygula")!;
  expect(post.govde.kalip_id).toBeUndefined();
  expect((post.govde.dilimler as unknown[]).length).toBe(2);
});
