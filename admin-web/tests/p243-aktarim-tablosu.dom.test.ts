// @vitest-environment jsdom
// (P243 §3) ICE AKTARIM TABLOSU — sutunlari hazir, yapistirilabilir.
//
// ===========================================================================
// EN KRITIK OZELLIK: EXCEL'DEN COKLU HUCRE YAPISTIRMA
// ===========================================================================
// Olculen surtunme: yonetici kendi Excel'ini BIZIM sablonumuza
// uyduruyordu. Bu ekranda sutunlar zaten bizim; kullanici kendi
// tablosundan kopyalayip yapistiriyor ve ESLEME ADIMI YOK.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/ice-aktarim/page";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const TURLER = [
  {
    kod: "daire",
    aciklama: "Daireler ve sakinler",
    alanlar: [
      { kod: "blok", zorunlu: true, ornek: "A" },
      { kod: "daire_no", zorunlu: true, ornek: "A-1" },
      { kod: "sakin_ad", zorunlu: false, ornek: "Ali Veli" },
      { kod: "sakin_eposta", zorunlu: false, ornek: "ali@ornek.com" },
    ],
  },
  {
    kod: "kisi",
    aciklama: "Kişiler",
    alanlar: [
      { kod: "ad", zorunlu: true, ornek: "Ali Veli" },
      { kod: "eposta", zorunlu: true, ornek: "ali@ornek.com" },
      { kod: "plaka", zorunlu: false, ornek: "34ABC123" },
    ],
  },
  { kod: "acilis_bakiye", aciklama: "Açılış", alanlar: [] },
];

function taklit(sonuc?: unknown): Cagri[] {
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
    if (url.includes("ice-aktarim-turler")) govde = TURLER;
    else if (url.includes("/api/panel/ice-aktarim?")) govde = { items: [] };
    else if (metot === "POST" && url.includes("ice-aktarim-")) {
      govde =
        sonuc ?? {
          satir_sayisi: 2,
          olusan: 2,
          atlanan: 0,
          guncellenen: 0,
          hatali: 0,
          hatalar: [],
          aktarim_id: null,
          uygulanmadi: true,
          davet_gonderildi: 0,
          davet_basarisiz: 0,
          davet_hatalari: [],
        };
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

it("TUR SECILINCE SUTUNLARI OLAN BOS TABLO acilir", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("aktarim-tablosu")).toBeTruthy());
  // Sutunlar turun alanlari; zorunlu olanlar BASLIKTA isaretli.
  const basliklar = Array.from(
    kanca("aktarim-tablosu")!.querySelectorAll("th"),
  ).map((x) => x.textContent ?? "");
  expect(basliklar.some((b) => b.includes("blok") && b.includes("zorunlu"))).toBe(
    true,
  );
  expect(basliklar.some((b) => b.includes("sakin_eposta"))).toBe(true);
  // ESLEME ADIMI YOK.
  expect(document.body.textContent).not.toContain("Kolon eşleme");
});

it("EXCEL'DEN COKLU HUCRE YAPISTIRMA sutunlari doldurur", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("aktarim-hucre-0-blok")).toBeTruthy());

  const ilk = kanca("aktarim-hucre-0-blok") as HTMLInputElement;
  await k.click(ilk);
  // Excel blogu: sutun = sekme, satir = yeni satir.
  await k.paste("A\tA-1\tAli Veli\tali@ornek.com\nB\tB-2\tVeli Ak\tveli@ornek.com");

  await waitFor(() =>
    expect((kanca("aktarim-hucre-0-daire_no") as HTMLInputElement).value).toBe(
      "A-1",
    ),
  );
  expect((kanca("aktarim-hucre-0-sakin_eposta") as HTMLInputElement).value).toBe(
    "ali@ornek.com",
  );
  // IKINCI SATIR da doldu.
  expect((kanca("aktarim-hucre-1-blok") as HTMLInputElement).value).toBe("B");
  expect((kanca("aktarim-hucre-1-sakin_ad") as HTMLInputElement).value).toBe(
    "Veli Ak",
  );
});

it("YAPISTIRMA SATIR YETMEZSE TABLOYU BUYUTUR", async () => {
  // "Once 50 satir ekleyin" demek, isi kullaniciya geri vermekti.
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("aktarim-hucre-0-blok")).toBeTruthy());
  expect(kanca("aktarim-satir-7")).toBeNull();

  await k.click(kanca("aktarim-hucre-0-blok")!);
  const blok = Array.from({ length: 8 }, (_, i) => `A\tA-${i}`).join("\n");
  await k.paste(blok);
  await waitFor(() => expect(kanca("aktarim-satir-7")).toBeTruthy());
});

it("ONIZLEME govdeyi ALAN KODLARIYLA gonderir (esleme YOK)", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("aktarim-hucre-0-blok")).toBeTruthy());
  await k.click(kanca("aktarim-hucre-0-blok")!);
  await k.paste("A\tA-1");

  await k.click(
    Array.from(document.querySelectorAll("button")).find((b) =>
      /Önizle/.test(b.textContent ?? ""),
    )!,
  );
  await waitFor(() => {
    const p = cagrilar.find((c) => c.metot === "POST");
    expect(p).toBeTruthy();
    const satirlar = p!.govde.satirlar as {
      satir_no: number;
      degerler: Record<string, string>;
    }[];
    // BOS SATIRLAR ATILDI: tablo bes bos satirla aciliyor.
    expect(satirlar.length).toBe(1);
    expect(satirlar[0].degerler.blok).toBe("A");
    expect(satirlar[0].degerler.daire_no).toBe("A-1");
    expect(p!.govde.yalniz_dogrula).toBe(true);
  });
});

it("HATALI SATIR HUCREDE ve LISTEDE, SATIR NUMARASIYLA", async () => {
  const k = userEvent.setup();
  taklit({
    satir_sayisi: 1,
    olusan: 0,
    atlanan: 0,
    guncellenen: 0,
    hatali: 1,
    hatalar: [
      { satir_no: 2, alan: "daire_no", hata: "Zorunlu alan eksik." },
    ],
    aktarim_id: null,
    uygulanmadi: true,
    davet_gonderildi: 0,
    davet_basarisiz: 0,
    davet_hatalari: [],
  });
  ciz(Sayfa);
  await waitFor(() => expect(kanca("aktarim-hucre-0-blok")).toBeTruthy());
  await k.click(kanca("aktarim-hucre-0-blok")!);
  await k.paste("A\t");
  await k.click(
    Array.from(document.querySelectorAll("button")).find((b) =>
      /Önizle/.test(b.textContent ?? ""),
    )!,
  );

  await waitFor(() => expect(kanca("aktarim-hata-listesi")).toBeTruthy());
  // SATIR NUMARASI VE ALAN ADI YAZILI: "bir yerde sorun var" demek,
  // kullaniciyi 200 satirda aramaya gondermekti.
  expect(kanca("aktarim-hata-listesi")!.textContent).toContain("2");
  expect(kanca("aktarim-hata-listesi")!.textContent).toContain("daire_no");
  // HUCRE DE ISARETLI — ve renk tek basina degil, satir no da kirmizi.
  expect(
    (kanca("aktarim-hucre-0-daire_no") as HTMLInputElement).getAttribute(
      "aria-invalid",
    ),
  ).toBe("true");
});

it("SATIR EKLE / SIL calisir", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("aktarim-satir-4")).toBeTruthy());
  await k.click(kanca("aktarim-satir-ekle")!);
  await waitFor(() => expect(kanca("aktarim-satir-5")).toBeTruthy());
  await k.click(kanca("aktarim-satir-sil-5")!);
  await waitFor(() => expect(kanca("aktarim-satir-5")).toBeNull());
});

it("DOSYA KIPI DURUYOR — kaldirilmadi", async () => {
  // Elinde zaten uygun bir dosya olan kullanicinin yolunu kapatmak,
  // bir sorunu cozerken bir baskasini uretmekti.
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("ice-aktarim-kip-dosya")).toBeTruthy());
  await k.click(kanca("ice-aktarim-kip-dosya")!);
  await waitFor(() => expect(kanca("aktarim-tablosu")).toBeNull());
  expect(document.body.textContent).toContain("Veri");
});
