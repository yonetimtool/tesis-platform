// @vitest-environment jsdom
// (P205 §2) VARDIYA ZAMAN CIZELGESI — ekranin davranisi + giden govde.
//
// ===========================================================================
// BU DOSYA P203'UN IZGARA TESTININ YERINI ALDI
// ===========================================================================
// Eski ekran GUN x VARDIYA izgarasiydi; §2 onu KISI x SAAT cizelgesine
// cevirdi. Eski testin olctugu iki sey KORUNDU cunku davranis duruyor:
// anlik durum karti ve "haftayi kadrodan doldur". Slot bazli atama
// olctugu testler ise ARTIK YOK — o etkilesim (bos slota kisi sec)
// yerini hizli ekleme penceresine birakti.
//
// Kurallarin kendisi sunucuda kilitli (backend `test_p205_vardiya_*`);
// burada olculen, arayuzun dogru ucu dogru govdeyle cagirdigi ve
// CAKISMAYI KULLANICIYA SORDUGU.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/vardiya-plani/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const BUGUN = new Date().toISOString().slice(0, 10);

const CIZELGE = {
  baslangic: BUGUN,
  bitis: BUGUN,
  personel: [
    {
      user_id: "u-1",
      ad: "Ali Guvenlik",
      rol: "security",
      bloklar: [
        {
          plan_id: "p-1",
          tarih: BUGUN,
          baslar: `${BUGUN}T22:00:00`,
          biter: `${BUGUN}T05:00:00`,
          shift_ad: null,
          not_metni: null,
          // GECE ASIRI blok: 22:00-05:00 IKI GUNE yayilir.
          gece_asiyor: true,
        },
      ],
    },
    // VARDIYASI OLMAYAN personel de satirda durur: "kim BOSTA" da bir
    // plan sorusudur ve atanacak kisi ekranda gorunmeli.
    { user_id: "u-2", ad: "Veli Bos", rol: "tesis_gorevlisi", bloklar: [] },
  ],
};

function taklit(opts: { toplu?: unknown } = {}): Cagri[] {
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
      govde = CIZELGE;
    } else if (url.includes("/vardiya-plani/simdi")) {
      govde = {
        gorevdeki_vardiya: {
          shift_ad: "Gece",
          baslangic_saat: "22:00:00",
          bitis_saat: "05:00:00",
        },
        gorevdekiler: [
          { plan_id: "p-1", user_id: "u-1", ad: "Ali Guvenlik", rol: "security" },
        ],
        sonraki_vardiya: null,
        sonrakiler: [],
      };
    } else if (url.startsWith("/api/users")) {
      govde = {
        items: [
          { id: "u-2", ad: "Yeni Personel", role: "security" },
          { id: "u-3", ad: "Sakin Kisi", role: "resident" },
        ],
      };
    } else if (metot === "POST" && url === "/api/vardiya-plani/toplu") {
      govde =
        opts.toplu ??
        { uygulandi: true, eklenen: 3, cakisan: 0, gunler: [], uyarilar: [] };
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

afterEach(() => vi.restoreAllMocks());

// ========================= 2.1 ANA EKRAN ================================= #

it("CIZELGE cizilir: kisi satirlari, bloklar ve SAAT EKSENI", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-satir-u-1")).toBeTruthy());
  // VARDIYASI OLMAYAN kisi de satirda: yonetici atayacagi kisiyi
  // ekranda goremezse once onu aramak zorunda kalirdi.
  expect(kanca("vardiya-satir-u-2")).toBeTruthy();
  expect(kanca("vardiya-blok-p-1")).toBeTruthy();
  expect(kanca("vardiya-blok-p-1")!.textContent).toContain("22:00");
  expect(kanca("vardiya-eksen")).toBeTruthy();
});

it("SIMDI CIZGISI bugun gorunumdeyken cizilir", async () => {
  // Cizginin isi "su an neredeyiz" sorusunu bakislik bir seye
  // cevirmek; olmadigi zaman kullanici saat basliklarini sayardi.
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-simdi-cizgisi")).toBeTruthy());
});

it("GORUNUM SECICI sunucudan FARKLI GUN SAYISI ister", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorunum-gun")).toBeTruthy());
  await k.click(kanca("vardiya-gorunum-gun")!);
  await waitFor(() =>
    expect(cagrilar.some((c) => c.url.includes("gun=1"))).toBe(true),
  );
  await k.click(kanca("vardiya-gorunum-ay")!);
  await waitFor(() =>
    expect(cagrilar.some((c) => c.url.includes("gun=31"))).toBe(true),
  );
});

it("TARIH GEZINME ve BUGUN yeni aralik ister", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-aralik")).toBeTruthy());
  const ilk = kanca("vardiya-aralik")!.textContent;
  await k.click(kanca("vardiya-ileri")!);
  await waitFor(() =>
    expect(kanca("vardiya-aralik")!.textContent).not.toBe(ilk),
  );
  await k.click(kanca("vardiya-bugun")!);
  await waitFor(() => expect(kanca("vardiya-aralik")!.textContent).toBe(ilk));
  // Her aralik icin YENI istek (istemcide dilimlenmedi).
  const araliklar = new Set(
    cagrilar.filter((c) => c.url.startsWith("/api/vardiya-plani/cizelge")).map((c) => c.url),
  );
  expect(araliklar.size).toBeGreaterThan(1);
});

it("FILTRELER sayaci ve KISI SUZGECI satirlari azaltir", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-satir-u-2")).toBeTruthy());
  expect(kanca("vardiya-filtreler")!.textContent).toContain("(0)");
  await k.click(kanca("vardiya-filtreler")!);
  await k.type(kanca("vardiya-suzgec-kisi")!, "Ali");
  await waitFor(() => expect(kanca("vardiya-satir-u-2")).toBeNull());
  expect(kanca("vardiya-satir-u-1")).toBeTruthy();
  expect(kanca("vardiya-filtreler")!.textContent).toContain("(1)");
});

// ==================== 2.2 HIZLI VARDIYA EKLE ============================= #

it("TOPLU EKLEME govdesi: aralik + saatler + atlama BAYRAGI KAPALI", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-ekle-kisi")).toBeTruthy());
  await k.selectOptions(kanca("vardiya-ekle-kisi")!, "u-2");
  await k.click(kanca("vardiya-ekle-gonder")!);

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/vardiya-plani/toplu")).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/vardiya-plani/toplu")!;
  expect(post.govde.user_id).toBe("u-2");
  expect(post.govde.baslangic_saat).toBe("08:00");
  // ILK ISTEKTE ATLAMA KAPALI: cakisan gunler kullaniciya SORULMADAN
  // atlanamaz (istegin acik sarti).
  expect(post.govde.cakisanlari_atla).toBe(false);
});

it("SAKIN listede YOK", async () => {
  // Vardiya personele atanir; sakini listelemek yoneticiye anlamsiz bir
  // secenek sunup yanlislikla secmesine zemin hazirlardi.
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-ekle-kisi")).toBeTruthy());
  const adlar = Array.from(
    (kanca("vardiya-ekle-kisi") as HTMLSelectElement).options,
  ).map((o) => o.textContent);
  expect(adlar).toContain("Yeni Personel");
  expect(adlar).not.toContain("Sakin Kisi");
});

it("ARALIK ve GECE ASIRI davranisi ONCEDEN yazar", async () => {
  // Iki davranisi denedikten sonra ogrenmek, yanlislikla on dort kayit
  // acmak demekti.
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-ekle-bilgi")).toBeTruthy());
  expect(kanca("vardiya-ekle-bilgi")!.textContent).toBe(tr.vardiyaEkleBilgi);
});

it("CAKISMA: gunler GOSTERILIR, karar KULLANICININ", async () => {
  // Istegin en sert sarti: cakisan gunler SESSIZCE ATLANMAZ. Sunucu
  // "uygulandi=false" der; ekran gunleri yazar ve iki secenek sunar.
  const k = userEvent.setup();
  const cagrilar = taklit({
    toplu: {
      uygulandi: false,
      eklenen: 0,
      cakisan: 2,
      gunler: [
        { tarih: "2026-09-03", durum: "cakisma", plan_id: null },
        { tarih: "2026-09-04", durum: "eklenebilir", plan_id: null },
        { tarih: "2026-09-05", durum: "cakisma", plan_id: null },
      ],
      uyarilar: [],
    },
  });
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-ekle-kisi")).toBeTruthy());
  await k.selectOptions(kanca("vardiya-ekle-kisi")!, "u-2");
  await k.click(kanca("vardiya-ekle-gonder")!);

  await waitFor(() => expect(kanca("vardiya-cakisma-uyarisi")).toBeTruthy());
  // HANGI GUNLER oldugu yazilir — "bir yerde cakisma var" demek,
  // kullaniciyi tek tek aramaya gondermek olurdu.
  expect(kanca("vardiya-cakisma-uyarisi")!.textContent).toContain("2026-09-03");
  expect(kanca("vardiya-cakisma-uyarisi")!.textContent).toContain("2026-09-05");

  await k.click(kanca("vardiya-cakisan-haric")!);
  await waitFor(() =>
    expect(
      cagrilar.filter((c) => c.url === "/api/vardiya-plani/toplu").length,
    ).toBe(2),
  );
  // IKINCI istek ATLAMA ACIK gider — ve bu KULLANICININ kararidir.
  expect(
    cagrilar.filter((c) => c.url === "/api/vardiya-plani/toplu").at(-1)!.govde
      .cakisanlari_atla,
  ).toBe(true);
});

// ======================= 2.3 ETKILESIM =================================== #

it("BLOGA TIKLAYINCA ayrinti acilir; SAAT DEGISIKLIGI PATCH ile gider", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-blok-p-1")).toBeTruthy());
  await k.click(kanca("vardiya-blok-p-1")!);
  await waitFor(() => expect(kanca("vardiya-ayrinti")).toBeTruthy());
  // GECE ASIRI oldugu ayrintida SOYLENIR: iki gune yayilan bir blok,
  // "bitis saati baslangictan kucuk" diye yanlis okunabilirdi.
  expect(kanca("vardiya-ayrinti")!.textContent).toContain(tr.vardiyaGeceAsiyor);

  await k.clear(kanca("vardiya-ayrinti-son")!);
  await k.type(kanca("vardiya-ayrinti-son")!, "06:00");
  await k.click(kanca("vardiya-ayrinti-kaydet")!);

  await waitFor(() =>
    expect(cagrilar.some((c) => c.metot === "PATCH")).toBe(true),
  );
  const patch = cagrilar.find((c) => c.metot === "PATCH")!;
  expect(patch.url).toBe("/api/vardiya-plani/p-1");
  expect(patch.govde.bitis_saat).toBe("06:00");
});

it("CIKARMA sebebi SORGUDA tasinir (DELETE govdesi vekillerde dusuyor)", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-blok-p-1")).toBeTruthy());
  await k.click(kanca("vardiya-blok-p-1")!);
  await waitFor(() => expect(kanca("vardiya-cikar-sebep")).toBeTruthy());
  await k.type(kanca("vardiya-cikar-sebep")!, "hastalik");
  await k.click(kanca("vardiya-cikar")!);

  await waitFor(() =>
    expect(cagrilar.some((c) => c.metot === "DELETE")).toBe(true),
  );
  expect(cagrilar.find((c) => c.metot === "DELETE")!.url).toContain(
    "not_metni=hastalik",
  );
});

// ============ (P203'TEN KORUNAN DAVRANISLAR) ============================= #

it("ANLIK DURUM karti duruyor: su an gorevde kim", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-simdi-gorevde")).toBeTruthy());
  expect(kanca("vardiya-simdi-gorevde")!.textContent).toContain("Ali Guvenlik");
});

it("HAFTAYI KADRODAN DOLDUR duruyor ve dogru uca gider", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-haftayi-doldur")).toBeTruthy());
  await k.click(kanca("vardiya-haftayi-doldur")!);
  await waitFor(() =>
    expect(
      cagrilar.some((c) => c.url.startsWith("/api/vardiya-plani/haftayi-doldur")),
    ).toBe(true),
  );
});
