// @vitest-environment jsdom
// (P241 §2) VARDIYA IZGARASI YENIDEN — gruplama, saat toplami, taslak,
// toplu secim, takvim, araclar.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// Kurallarin kendisi SUNUCUDA kilitli (`test_p241_vardiya.py`). Burada
// olculen sey arayuzun o gercekleri DOGRU GOSTERDIGI: rol gruplari ve
// sayilari, atanmamis bolumu, mola dusulmus saat toplami, taslak
// isareti ve yayin sayaci.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/vardiya-plani/page";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const BUGUN = new Date().toISOString().slice(0, 10);

function blok(id: string, ek: Record<string, unknown> = {}) {
  return {
    plan_id: id,
    tarih: BUGUN,
    baslar: `${BUGUN}T08:00:00`,
    biter: `${BUGUN}T20:00:00`,
    shift_ad: "Gunduz",
    not_metni: null,
    gece_asiyor: false,
    vardiya_rolu: null,
    blok_ad: null,
    alan: null,
    calisma_saat: 11,
    mola_dakika: 60,
    yayinlandi_at: `${BUGUN}T07:00:00Z`,
    yayin_bekliyor: false,
    ...ek,
  };
}

const CIZELGE = {
  baslangic: BUGUN,
  bitis: BUGUN,
  personel: [
    {
      user_id: "u-1",
      ad: "Ali Guvenlik",
      rol: "security",
      bloklar: [blok("p-1", { vardiya_rolu: "temizlik", alan: "Otopark" })],
      izinler: [],
      toplam_saat: 11,
      hedef_saat: 45,
    },
    {
      user_id: "u-2",
      ad: "Ayse Guvenlik",
      rol: "security",
      // TASLAK: `yayinlandi_at` NULL.
      bloklar: [blok("p-2", { yayinlandi_at: null })],
      izinler: [],
      toplam_saat: 50,
      hedef_saat: 45,
    },
    {
      user_id: "u-3",
      ad: "Veli Bos",
      rol: "tesis_gorevlisi",
      bloklar: [],
      // (P243 §2) Duzende olan ama BU DONEMDE atanmamis kisi.
      vardiya_duzeninde: true,
      izinler: [
        {
          izin_id: "i-1",
          tur: "yillik",
          baslangic: BUGUN,
          bitis: BUGUN,
          tum_gun: true,
        },
      ],
      toplam_saat: 0,
      hedef_saat: 45,
    },
  ],
};

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
    if (url.startsWith("/api/vardiya-plani/cizelge")) govde = CIZELGE;
    else if (url.includes("/vardiya-plani/yayin-ozeti"))
      govde = { bekleyen: 2, taslak: 1, degisen: 1 };
    else if (url.includes("/vardiya-plani/simdi"))
      govde = {
        gorevdeki_vardiya: null,
        gorevdekiler: [],
        sonraki_vardiya: null,
        sonrakiler: [],
      };
    else if (url.startsWith("/api/users")) govde = { items: [] };
    else if (url.includes("/vardiya-plani/yayinla"))
      govde = { yayinlanan: 2, bildirilen_kisi: 2 };
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

it("ROL GRUPLARI ve KISI SAYISI ROZETI cizilir", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-grup-security")).toBeTruthy());
  // Iki guvenlik personeli bir grupta.
  expect(kanca("vardiya-grup-security")!.textContent).toContain("2");
});

it("VARDIYASI OLMAYAN personel ATANMAMIS grubunda — rolunun icinde degil", async () => {
  // Yoneticinin aradigi tam olarak budur: "kimi atayabilirim".
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-grup-__atanmamis__")).toBeTruthy());
  expect(kanca("vardiya-grup-__atanmamis__")!.textContent).toContain("1");
  // `tesis_gorevlisi` grubu ACILMAZ: tek kisisi atanmamis bolumunde.
  expect(kanca("vardiya-grup-tesis_gorevlisi")).toBeNull();
});

it("SAAT TOPLAMI SUNUCUDAN — mola dusulmus, hedefle birlikte", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-saat-u-1")).toBeTruthy());
  // 12 saatlik vardiya, 1 saat mola -> 11 saat. Istemci toplamiyor.
  expect(kanca("vardiya-saat-u-1")!.textContent).toContain("11");
  expect(kanca("vardiya-saat-u-1")!.textContent).toContain("45");
});

it("TASLAK vardiya ISARETLI — renk TEK BASINA anlam tasimaz", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-blok-p-2")).toBeTruthy());
  // Hucrede YAZIYLA "Taslak"; kenarlik kesikli ama ona guvenilmiyor.
  expect(kanca("vardiya-blok-p-2")!.textContent).toContain("Taslak");
  expect(kanca("vardiya-blok-p-1")!.textContent).not.toContain("Taslak");
});

it("ROL ETIKETI hucrede gorunur (hesabin rolu DEGIL)", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-blok-p-1")).toBeTruthy());
  expect(kanca("vardiya-blok-p-1")!.textContent).toContain("temizlik");
});

it("IZIN KATMANI cizilir (blok DEGIL)", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-izin-i-1")).toBeTruthy());
  // Izin bir DUGME degil: tiklanabilir olsaydi "izni duzenle" sanilirdi.
  expect(kanca("vardiya-izin-i-1")!.tagName).toBe("DIV");
});

it("YAYINLA dugmesinde SAYI var ve ucu cagirir", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yayinla")).toBeTruthy());
  expect(kanca("vardiya-yayinla")!.textContent).toContain("2");
  await k.click(kanca("vardiya-yayinla")!);
  await waitFor(() =>
    expect(
      cagrilar.some(
        (c) => c.metot === "POST" && c.url.includes("/vardiya-plani/yayinla"),
      ),
    ).toBe(true),
  );
});

it("TOPLU SECIM: CTRL ile secilir, cubuk acilir, SILME ucu cagrilir", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-blok-p-1")).toBeTruthy());
  // SADE TIKLAMA ayrinti acar; toplu secim CTRL ister. Tersi olsaydi
  // tek vardiyayi duzenlemek isteyen once secim moduna girerdi.
  await k.keyboard("{Control>}");
  await k.click(kanca("vardiya-blok-p-1")!);
  await k.keyboard("{/Control}");
  await waitFor(() => expect(kanca("vardiya-toplu-cubuk")).toBeTruthy());
  await k.click(kanca("vardiya-toplu-sil")!);
  await waitFor(() =>
    expect(
      cagrilar.some(
        (c) => c.metot === "DELETE" && c.url.includes("/vardiya-plani/p-1"),
      ),
    ).toBe(true),
  );
});

it("TAKVIM GORUNUMU ay izgarasi cizer", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-gorunum-takvim")).toBeTruthy());
  await k.click(kanca("vardiya-gorunum-takvim")!);
  await waitFor(() => expect(kanca("vardiya-takvim")).toBeTruthy());
  expect(kanca(`vardiya-takvim-gun-${BUGUN}`)).toBeTruthy();
  // CIZELGE AYNI ANDA CIZILMEZ: iki farkli gorunumu ust uste koymak
  // "hangisine bakiyorum" sorusunu dogururdu.
  expect(kanca("vardiya-eksen")).toBeNull();
});

it("SORUNLU SUZGECI: hedefi asan ya da yayin bekleyen kalir", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-filtreler")).toBeTruthy());
  await k.click(kanca("vardiya-filtreler")!);
  await k.click(kanca("vardiya-suzgec-sorunlu")!);
  await waitFor(() => expect(kanca("vardiya-satir-u-1")).toBeNull());
  // u-2: hem taslak hem 50 > 45 saat.
  expect(kanca("vardiya-satir-u-2")).toBeTruthy();
});

it("ARACLAR menusu HAFTADAN KOPYALA acar ve govdeyi DOGRU gonderir", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-araclar-ac")).toBeTruthy());
  await k.click(kanca("vardiya-araclar-ac")!);
  await k.click(kanca("vardiya-arac-kopyala")!);
  await waitFor(() => expect(kanca("vardiya-kopya-uygula")).toBeTruthy());
  await k.click(kanca("vardiya-kopya-uygula")!);
  await waitFor(() => {
    const c = cagrilar.find((x) =>
      x.url.includes("/vardiya-plani/haftadan-kopyala"),
    );
    expect(c).toBeTruthy();
    // YIKICI SECENEK VARSAYILAN OLARAK KAPALI.
    expect(c!.govde.hedefi_temizle).toBe(false);
  });
});

it("EXCEL menusu: disa aktarim ve ornek sablon baglantilari var", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-excel-ac")).toBeTruthy());
  await k.click(kanca("vardiya-excel-ac")!);
  await waitFor(() => expect(kanca("vardiya-excel-disa")).toBeTruthy());
  expect(kanca("vardiya-excel-sablon")).toBeTruthy();
  expect(kanca("vardiya-excel-ice")).toBeTruthy();
});

it("IZIN SEKMESI: modal acilir ve IZIN ucuna gider", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await k.click(kanca("vardiya-yeni")!);
  await waitFor(() => expect(kanca("vardiya-sekme-izin")).toBeTruthy());
  await k.click(kanca("vardiya-sekme-izin")!);
  await waitFor(() => expect(kanca("vardiya-izin-formu")).toBeTruthy());
  // Kisi secilmeden kaydet KAPALI: bos `user_id` ile istek atmak,
  // sunucudan 422 almak icin ag turu yapmak olurdu.
  expect((kanca("vardiya-izin-kaydet") as HTMLButtonElement).disabled).toBe(true);
  expect(screen.queryByText(/İzin türü/)).toBeTruthy();
  expect(cagrilar.some((c) => c.url.includes("/api/vardiya-izin"))).toBe(false);
});
