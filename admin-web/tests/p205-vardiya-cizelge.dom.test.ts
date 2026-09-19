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
    // (P243 §2) `vardiya_duzeninde` SART: "Atanmamis" bolumu artik
    // yalniz vardiya duzenine dahil kisileri cizer (kadro uyesi ya da
    // herhangi bir tarihte vardiyasi olan). Bayraksiz bir kisi
    // izgarada HIC gorunmez — ve bu bilincli: onceden bolum TUM
    // personeli listeleyip bir rehbere donusuyordu.
    {
      user_id: "u-2",
      ad: "Veli Bos",
      rol: "tesis_gorevlisi",
      bloklar: [],
      vardiya_duzeninde: true,
    },
  ],
};

function taklit(opts: { toplu?: unknown; kalip?: unknown } = {}): Cagri[] {
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
    } else if (metot === "POST" && url === "/api/vardiya-plani/kalip-uygula") {
      govde =
        opts.kalip ?? {
          uygulandi: true, parti_id: "pt-1", eklenecek: 1, eklenen: 1,
          cakisan: 0, satirlar: [],
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

it("(P243 §1) VARDIYA EKLEME TEK UCTAN gider ve GUN SECIMI ISTER", async () => {
  // ======================================================================
  // BU TEST ESKIDEN KIRIK BIR YOLU KILITLIYORDU
  // ======================================================================
  // Onceki hali "serbest saat + tek kisi" durumunda `/vardiya-plani/toplu`
  // cagrildigini olcuyordu. Sahte `fetch` her govdeye 200 donduruyordu, bu
  // yuzden test YESILDI — oysa GERCEK sunucu o govdeye 422 veriyordu:
  // modal `baslangic`/`bitis` gonderiyor, sema `baslangic_tarih`/
  // `bitis_tarih` istiyor. P243'te sunucuya birebir o govde gonderilerek
  // OLCULDU.
  //
  // Ders: taklit yanit, SOZLESMEYI dogrulamaz. Bu yuzden yeni kilit
  // "hangi uc, hangi govde" yerine "TEK UC" kuralini olcuyor ve
  // sozlesme uyumu backend testinde (`test_p243_vardiya_modali`)
  // duruyor.
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-ekle-kisi")).toBeTruthy());
  await k.selectOptions(kanca("vardiya-ekle-kisi")!, "u-2");

  // GUN SECILMEDEN GONDERILEMEZ: takvim tek gercek kaynak (§1c).
  expect(
    (kanca("vardiya-ekle-gonder") as HTMLButtonElement).disabled,
  ).toBe(true);

  const bugunHucresi = document.querySelector(
    `[data-test^="vardiya-ekle-gun-"]`,
  ) as HTMLElement;
  await k.click(bugunHucresi);
  await k.click(kanca("vardiya-ekle-gonder")!);

  await waitFor(() =>
    expect(
      cagrilar.some((c) => c.url === "/api/vardiya-plani/kalip-uygula"),
    ).toBe(true),
  );
  // ESKI UC ARTIK HIC CAGRILMIYOR.
  expect(cagrilar.some((c) => c.url === "/api/vardiya-plani/toplu")).toBe(false);
  const post = cagrilar.find(
    (c) => c.url === "/api/vardiya-plani/kalip-uygula",
  )!;
  const gruplar = post.govde.gruplar as { gunler: string[] }[];
  expect(gruplar.length).toBe(1);
  expect(gruplar[0].gunler.length).toBe(1);
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
  //
  // (P243 §1) Yol degisti (`/kalip-uygula`), KURAL degismedi: gunler
  // artik sonuc satirlarindan turetiliyor.
  const k = userEvent.setup();
  const cagrilar = taklit({
    kalip: {
      uygulandi: false,
      parti_id: null,
      eklenecek: 1,
      eklenen: 0,
      cakisan: 2,
      satirlar: [
        { tarih: "2026-09-03", dilim: "08:00-16:00", durum: "cakisma" },
        { tarih: "2026-09-04", dilim: "08:00-16:00", durum: "eklenecek" },
        { tarih: "2026-09-05", dilim: "08:00-16:00", durum: "cakisma" },
      ],
    },
  });
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-ekle-kisi")).toBeTruthy());
  await k.selectOptions(kanca("vardiya-ekle-kisi")!, "u-2");
  await k.click(
    document.querySelector(`[data-test^="vardiya-ekle-gun-"]`) as HTMLElement,
  );
  await k.click(kanca("vardiya-ekle-gonder")!);

  await waitFor(() => expect(kanca("vardiya-cakisma-uyarisi")).toBeTruthy());
  // HANGI GUNLER oldugu yazilir — "bir yerde cakisma var" demek,
  // kullaniciyi tek tek aramaya gondermek olurdu.
  expect(kanca("vardiya-cakisma-uyarisi")!.textContent).toContain("2026-09-03");
  expect(kanca("vardiya-cakisma-uyarisi")!.textContent).toContain("2026-09-05");

  await k.click(kanca("vardiya-cakisan-haric")!);
  await waitFor(() =>
    expect(
      cagrilar.filter((c) => c.url === "/api/vardiya-plani/kalip-uygula")
        .length,
    ).toBe(2),
  );
  // IKINCI istek ATLAMA ACIK gider — ve bu KULLANICININ kararidir.
  expect(
    cagrilar
      .filter((c) => c.url === "/api/vardiya-plani/kalip-uygula")
      .at(-1)!.govde.cakisanlari_atla,
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
