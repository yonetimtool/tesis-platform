// @vitest-environment jsdom
// (P167 §5) RAPOR MOTORU — KART IZGARASI, ORTAK MODAL, KUYRUK.
//
// =========================================================================
// OLCULEN UC SEY (ucu de sessizce yanlis calisabilirdi)
// =========================================================================
//  1. MODAL ALANLARI RAPORA GORE DEGISIR. Eski sayfada sabit dort alan
//     vardi; kasa ekstresi "kasa" secmeden calisiyordu, yani rapor
//     uretiliyor ama SORULAN SORU sorulmuyordu. Alanlarin katalogdan
//     gelmesi bu kusurun kapanmasidir ve testi de odur.
//  2. AGIR RAPOR KUYRUGA GIDER. Yanlis yola gitse ekran calisir gorunur:
//     kullanici tarayicisi kilitlenene kadar bir sey fark etmez.
//  3. "GOSTER" AGIR RAPORDA DA SENKRONDUR. Kuyruga alsaydik, kullanici
//     ekranda gormek istedigi seyi indirilecek bir dosya olarak bulurdu.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import RaporlarPage from "@/app/(protected)/raporlar/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/raporlar",
  useSearchParams: () => new URLSearchParams(),
}));

const KATALOG = {
  items: [
    {
      kod: "borc_alacak", baslik: "Borç/Alacak", aciklama: "Tüm defter",
      kategori: "listeler",
      alanlar: ["baslangic", "bitis", "blok", "ismi_goster"],
      agir: true,
    },
    {
      kod: "kasa_ekstresi", baslik: "Kasa Ekstresi", aciklama: "Kasa hareketi",
      kategori: "ekstreler",
      alanlar: ["kasa_id", "baslangic", "bitis"],
      agir: false,
    },
    {
      kod: "ihtar_yazisi", baslik: "İhtar Yazısı", aciklama: "KMK m.20",
      kategori: "dokumler",
      alanlar: ["unit_id", "imza"],
      agir: false,
    },
  ],
  kategoriler: ["listeler", "ekstreler", "dokumler"],
};

const KASALAR = { meta: { limit: 200, offset: 0, total: 1 }, items: [{ id: "k1", ad: "Ana Kasa", kod: "K1" }] };
const BOS_LISTE = { meta: { limit: 200, offset: 0, total: 0 }, items: [] };

interface Cagri {
  url: string;
  govde: Record<string, unknown> | null;
}

/** Tum `fetch`i sahteler ve rapor cagrilarini kaydeder. */
function sahtele(
  cagrilar: Cagri[],
  isler: unknown[] = [],
  raporYanit: unknown = { kod: "x", baslik: "x", sutunlar: [], satirlar: [], toplamlar: {}, metin: null },
) {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const cevap = (govde: unknown, durum = 200) =>
      new Response(JSON.stringify(govde), {
        status: durum,
        headers: { "Content-Type": "application/json" },
      });

    if (url.includes("/rapor-katalog")) return cevap(KATALOG);
    if (url.includes("/rapor/isler")) return cevap(isler);
    if (url.includes("/kasalar")) return cevap(KASALAR);
    if (url.includes("/rapor/")) {
      cagrilar.push({
        url,
        govde: init?.body ? JSON.parse(String(init.body)) : null,
      });
      return url.includes("/kuyruk")
        ? cevap({ id: "is-1", kod: "borc_alacak", bicim: "excel", durum: "bekliyor", created_at: "2026-08-17T10:00:00Z" }, 202)
        : cevap(raporYanit);
    }
    return cevap(BOS_LISTE);
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

async function modaliAc(ad: string | RegExp) {
  ciz(RaporlarPage);
  await userEvent.click(await screen.findByRole("button", { name: ad }));
  return screen.findByRole("dialog");
}

/* ==================================================================== */
describe("kart izgarasi", () => {
  it("KATEGORI BASLIKLARI cizilir ve SIRA SUNUCUDAN gelir", () => {
    sahtele([]);
    ciz(RaporlarPage);
    return waitFor(() => {
      const basliklar = screen
        .getAllByRole("heading", { level: 2 })
        .map((h) => h.textContent);
      // Alfabetik siralamak "Listeler"i "Dökümler"in ALTINA duserirdi;
      // sunucunun sirasi korunuyor.
      expect(basliklar).toEqual(["Listeler", "Ekstreler", "Dökümler"]);
    });
  });

  it("RAPOR ADLARI katalogdan gelir — sayfa hicbir ad TASIMAZ", async () => {
    sahtele([]);
    ciz(RaporlarPage);
    await screen.findByText("Borç/Alacak");
    expect(screen.getByText("Kasa Ekstresi")).toBeInTheDocument();
    expect(screen.getByText("İhtar Yazısı")).toBeInTheDocument();
  });
});

/* ==================================================================== */
describe("ortak modal", () => {
  it("ALANLAR RAPORA GORE degisir — kasa ekstresi KASA sorar", async () => {
    // Eski sabit-alanli sayfada kasa ekstresi KASA SECMEDEN calisiyordu.
    sahtele([]);
    await modaliAc(/Kasa Ekstresi/);
    expect(screen.getByLabelText("Kasa")).toBeInTheDocument();
    // Ve o raporun ANLAMLANDIRMADIGI alan CIZILMEZ: cizilseydi kullanici
    // doldurur, sunucu yok sayardi.
    expect(screen.queryByLabelText("Blok")).not.toBeInTheDocument();
  });

  it("SECIM LISTESI kaynagindan dolar ve 'Tümü' ILK sirada durur", async () => {
    sahtele([]);
    await modaliAc(/Kasa Ekstresi/);
    const secim = screen.getByLabelText("Kasa") as HTMLSelectElement;
    await waitFor(() => expect(secim.options.length).toBe(2));
    // Zorunlu olmayan bir suzgeci BOSALTAMAMAK, kullaniciyi modali kapatip
    // yeniden acmaya zorlardi.
    expect(secim.options[0].textContent).toBe("Tümü");
    expect(secim.options[1].textContent).toBe("Ana Kasa");
  });

  it("DORT DUGME cizilir", async () => {
    sahtele([]);
    const d = await modaliAc(/İhtar Yazısı/);
    for (const ad of ["İptal", "PDF", "Excel", "Göster"]) {
      expect(screen.getByRole("button", { name: ad }), ad).toBeInTheDocument();
    }
    expect(d).toBeInTheDocument();
  });

  it("RAPOR DEGISINCE form SIFIRLANIR", async () => {
    // Onceki raporun tarihini yeni raporda tasimak, kullanicinin GORMEDIGI
    // bir suzgecle rapor uretmesi demekti.
    sahtele([]);
    ciz(RaporlarPage);
    await userEvent.click(await screen.findByRole("button", { name: /Kasa Ekstresi/ }));
    await userEvent.type(screen.getByLabelText("Başlangıç"), "2026-03-01");
    await userEvent.click(screen.getByRole("button", { name: "İptal" }));
    await userEvent.click(screen.getByRole("button", { name: /Borç\/Alacak/ }));
    // (P168 §3) VARSAYILANA doner, BOSA degil: ilk tarih yilbasidir.
    const yil = new Date().getUTCFullYear();
    expect((screen.getByLabelText("Başlangıç") as HTMLInputElement).value).toBe(
      `${yil}-01-01`,
    );
  });
});

/* ==================================================================== */
describe("kuyruk yonlendirmesi", () => {
  it("AGIR raporun EXCEL istegi KUYRUGA gider", async () => {
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    await modaliAc(/Borç\/Alacak/);
    await userEvent.click(screen.getByRole("button", { name: "Excel" }));
    await waitFor(() => expect(cagrilar.length).toBe(1));
    expect(cagrilar[0].url).toContain("/kuyruk?bicim=excel");
  });

  it("HAFIF raporun EXCEL istegi DOGRUDAN gider", async () => {
    // Hepsini kuyruga almak, her rapor icin bekleme demekti.
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    await modaliAc(/Kasa Ekstresi/);
    await userEvent.click(screen.getByRole("button", { name: "Excel" }));
    await waitFor(() => expect(cagrilar.length).toBe(1));
    expect(cagrilar[0].url).toContain("bicim=excel");
    expect(cagrilar[0].url).not.toContain("/kuyruk");
  });

  it("'GOSTER' AGIR raporda da SENKRONDUR", async () => {
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    await modaliAc(/Borç\/Alacak/);
    await userEvent.click(screen.getByRole("button", { name: "Göster" }));
    await waitFor(() => expect(cagrilar.length).toBe(1));
    expect(cagrilar[0].url).toContain("bicim=tablo");
    expect(cagrilar[0].url).not.toContain("/kuyruk");
  });

  it("AGIR rapor UYARISI ONCEDEN gosterilir", async () => {
    // Dosyanin neden hemen inmedigini SONRADAN aciklamak, kullanicinin
    // "bir sey olmadi" diye ikinci kez tiklamasini engellemezdi.
    sahtele([]);
    await modaliAc(/Borç\/Alacak/);
    expect(screen.getByText(/kuyruğa alınır/i)).toBeInTheDocument();
  });

  it("BOS alanlar govdeye GIRMEZ, `false` GIRER", async () => {
    const cagrilar: Cagri[] = [];
    sahtele(cagrilar);
    await modaliAc(/Borç\/Alacak/);
    await userEvent.click(screen.getByLabelText("Ad sütunu"));
    await userEvent.click(screen.getByRole("button", { name: "Göster" }));
    await waitFor(() => expect(cagrilar.length).toBe(1));
    // `ismi_goster: false` KVKK'nin ta kendisi: "bos" sayilip dusurulseydi
    // kapiya asilacak listede adlar BASILI cikardi.
    // (P168 §3) Tarihler artik VARSAYILAN DOLU gelir (yilbasi -> bugun).
    const yil = new Date().getUTCFullYear();
    expect(cagrilar[0].govde).toEqual({
      ismi_goster: false,
      baslangic: `${yil}-01-01`,
      bitis: new Date().toISOString().slice(0, 10),
    });
  });
});

/* ==================================================================== */
describe("is listesi", () => {
  it("HAZIR iste 'Indir' cizilir, BEKLEYENDE cizilmez", async () => {
    // Hazir olmayan isin dugmesi, tiklandiginda hicbir sey olmayan bir
    // dugme olurdu.
    sahtele([], [
      { id: "a", kod: "borc_alacak", bicim: "excel", durum: "hazir", dosya_adi: "x.xlsx", hata: null, created_at: "2026-08-17T10:00:00Z", biten_at: null },
      { id: "b", kod: "borc_alacak", bicim: "pdf", durum: "bekliyor", dosya_adi: null, hata: null, created_at: "2026-08-17T10:01:00Z", biten_at: null },
    ]);
    ciz(RaporlarPage);
    await screen.findByText("Rapor İşlerim");
    expect(screen.getAllByRole("button", { name: "İndir" })).toHaveLength(1);
    expect(screen.getByText("Sırada")).toBeInTheDocument();
    expect(screen.getByText("Hazır")).toBeInTheDocument();
  });

  it("IS YOKSA bolum HIC cizilmez", async () => {
    // Bos bir "Rapor Islerim" tablosu, hic kullanilmamis bir ozelligi her
    // ziyarette gostermek olurdu.
    sahtele([], []);
    ciz(RaporlarPage);
    await screen.findByText("Borç/Alacak");
    expect(screen.queryByText("Rapor İşlerim")).not.toBeInTheDocument();
  });
});
