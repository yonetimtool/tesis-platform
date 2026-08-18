// @vitest-environment jsdom
// (P160 / Asama 6) RAPOR MOTORU · RAPORLAR · ICRA — tasima gerilemesi.
//
// Bu dosyanin agirlik merkezi RAPOR MOTORUDUR: "Goster" ciktisi UC AYRI
// kusurla bozuktu ve ucu birbirini maskeliyordu.
//   1. Sutun anahtarlari yanlisti  -> baslik bos, her hucre "—".
//   2. Kurus sutunlari ham sayiydi -> ekran 125050, Excel 1.250,50.
//   3. Toplamlar hic cizilmiyordu  -> toplami gormek icin dosya indirmek
//      gerekiyordu.
// (1) duzeltilmeden (2) ve (3) GORUNMEZDI; o yuzden ucu birlikte test
// ediliyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import IcraPage from "@/app/(protected)/icra/page";
import RaporlarPage from "@/app/(protected)/raporlar/page";
import PatrolReportPage from "@/app/(protected)/reports/patrols/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/raporlar",
  useSearchParams: () => new URLSearchParams(),
}));

// (P167 §5) Katalog KATEGORI + ALANLAR + AGIR tasiyor; `agir: false`
// dogrudan uretim yolunu secer (kuyruk yolunun kendi testi var).
const KATALOG = {
  items: [
    {
      kod: "borc_alacak", baslik: "Borç/Alacak", aciklama: "Daire bazinda",
      kategori: "listeler", alanlar: ["baslangic", "ismi_goster"], agir: false,
    },
  ],
  kategoriler: ["listeler", "ekstreler", "dokumler"],
};

/** Sunucunun GERCEK sozlesmesi: `anahtar`/`baslik` (RaporSutun). */
const TABLO = {
  kod: "borc_alacak",
  baslik: "Borç-Alacak Listesi",
  sutunlar: [
    { anahtar: "unit_no", baslik: "Bağımsız Bölüm", tip: "metin" },
    { anahtar: "bakiye", baslik: "Bakiye", tip: "kurus" },
  ],
  satirlar: [
    { unit_no: "A-12", bakiye: 125050 },
    { unit_no: "A-13", bakiye: 40000 },
  ],
  toplamlar: { bakiye: 165050 },
  metin: null,
};

function raporSahtele(tablo: unknown = TABLO) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    if (url.includes("/api/panel/rapor/")) {
      return { ok: true, status: 200, json: async () => tablo } as Response;
    }
    return { ok: true, status: 200, json: async () => KATALOG } as Response;
  }) as typeof fetch;
}

async function raporGoster() {
  ciz(RaporlarPage);
  await userEvent.click(await screen.findByText("Borç/Alacak"));
  await userEvent.click(screen.getByRole("button", { name: "Göster" }));
}

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) Rapor Motoru — KUSUR 1: sutun anahtarlari", () => {
  it("baslik satiri SUNUCUNUN `baslik` alanindan gelir", async () => {
    raporSahtele();
    await raporGoster();
    await waitFor(() =>
      expect(screen.getByRole("columnheader", { name: /Bağımsız Bölüm/ })).toBeInTheDocument(),
    );
    expect(screen.getByRole("columnheader", { name: /Bakiye/ })).toBeInTheDocument();
  });

  it("hucreler SUNUCUNUN `anahtar` alanindan okunur — hepsi '—' DEGIL", async () => {
    raporSahtele();
    await raporGoster();
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    expect(screen.getByText("A-13")).toBeInTheDocument();
  });
});

describe("(P160) Rapor Motoru — KUSUR 2: kurus bicimi", () => {
  it("kurus sutunu TL olarak cizilir; HAM sayi ekrana CIKMAZ", async () => {
    raporSahtele();
    await raporGoster();
    await waitFor(() => expect(screen.getByText("1.250,50")).toBeInTheDocument());
    // Excel `1250,50` yazar; ekranda `125050` gormek ikisinin ayrismasiydi.
    expect(screen.queryByText("125050")).toBeNull();
  });
});

describe("(P160) Rapor Motoru — KUSUR 3: toplam satiri", () => {
  it("TOPLAM satiri cizilir ve dogru sutunun altindadir", async () => {
    raporSahtele();
    await raporGoster();
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());

    const tablo = screen.getByRole("table");
    const altbilgi = tablo.querySelector("tfoot");
    expect(altbilgi, "tfoot yok").toBeTruthy();
    const hucreler = within(altbilgi as HTMLElement).getAllByRole("cell");
    expect(hucreler[0].textContent).toBe("Toplam");
    expect(hucreler[1].textContent).toBe("1.650,50");
  });

  it("toplam YOKSA altbilgi CIZILMEZ (uydurma sifir yok)", async () => {
    raporSahtele({ ...TABLO, toplamlar: {} });
    await raporGoster();
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    expect(screen.getByRole("table").querySelector("tfoot")).toBeNull();
  });
});

describe("(P160) Rapor Motoru — korunan davranislar", () => {
  it("SATIR YOKSA bos durum — sutunsuz raporda da", async () => {
    raporSahtele({ ...TABLO, sutunlar: [], satirlar: [], toplamlar: {} });
    await raporGoster();
    await waitFor(() => expect(screen.getByText("Satır yok")).toBeInTheDocument());
  });

  it("SECILI RAPOR ekran okuyucuya bildirilir (diyalog basligi)", async () => {
    // (P167 §5) ESKI OLCUM `aria-pressed`di, cunku secim SAYFA ICINDE
    // kaliyordu. Artik kart bir MODAL aciyor ve `aria-pressed` ekran
    // okuyucuya "acik/kapali anahtar" diye YANLIS bilgi verirdi.
    //
    // Yeni olcum daha guclu: diyalogun ERISILEBILIR ADI raporun adidir,
    // yani ekran okuyucu hangi raporu yapilandirdigini kartin
    // durumundan degil, ACILAN PENCERENIN KENDISINDEN duyar.
    raporSahtele();
    ciz(RaporlarPage);
    const kart = await screen.findByRole("button", { name: /Borç\/Alacak/ });
    expect(kart).toHaveAttribute("aria-haspopup", "dialog");
    await userEvent.click(kart);
    const diyalog = await screen.findByRole("dialog");
    expect(diyalog).toHaveAccessibleName(/Borç\/Alacak/);
  });
});

/* ==================================================================== */

describe("(P160) Devriye raporu — yuzde DILE gore bicimlenir", () => {
  const PENCERELER = {
    meta: { limit: 25, offset: 0, total: 1 },
    ozet: { toplam: 4, tamamlandi: 3, kacirildi: 1, bekliyor: 0 },
    items: [
      {
        id: "w1",
        plan_adi: "Gece devriyesi",
        pencere_baslangic: "2026-08-01T23:00:00Z",
        pencere_bitis: "2026-08-02T00:00:00Z",
        durum: "tamamlandi",
        okutulan_checkpoint_sayisi: 3,
        beklenen_checkpoint_sayisi: 3,
      },
    ],
  };

  it("oran `% 75` degil, `Intl`in Turkce ciktisi", async () => {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      if (url.includes("/api/patrol-windows")) {
        return { ok: true, status: 200, json: async () => PENCERELER } as Response;
      }
      return {
        ok: true,
        status: 200,
        json: async () => ({ meta: { limit: 200, offset: 0, total: 0 }, items: [] }),
      } as Response;
    }) as typeof fetch;

    ciz(PatrolReportPage);
    await userEvent.click(await screen.findByRole("button", { name: "Raporu getir" }));
    // `Intl` tr-TR icin "%75" uretir (bosluksuz, onde). Elle kurulan
    // "% 75" yedi dilin altisinda yanlisti.
    await waitFor(() => expect(screen.getByText("%75")).toBeInTheDocument());
  });
});

/* ==================================================================== */

describe("(P160) Icra — borclu artik SECILIR, UUID yazilmaz", () => {
  const DOSYALAR = {
    meta: { limit: 25, offset: 0, total: 1 },
    items: [
      {
        id: "d1",
        dosya_no: "2026/123",
        user_id: "u1",
        user_ad: "Ayse Yilmaz",
        veris_tarihi: null,
        avukat: null,
        durum: "acik",
        aciklama: null,
        acik_borc_kurus: 125050,
        created_at: "2026-08-01T00:00:00Z",
      },
    ],
  };
  const KISILER = {
    meta: { limit: 200, offset: 0, total: 1 },
    items: [{ id: "u1", ad: "Ayse Yilmaz", role: "resident", is_active: true }],
  };

  function icraSahtele(rol = "admin", kisiHatasi = false) {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      if (url.includes("/api/me")) {
        return { ok: true, status: 200, json: async () => ({ role: rol }) } as Response;
      }
      if (url.includes("/api/users")) {
        if (kisiHatasi) {
          return {
            ok: false,
            status: 500,
            json: async () => ({ error: { message: "kisi listesi yok" } }),
          } as Response;
        }
        return { ok: true, status: 200, json: async () => KISILER } as Response;
      }
      return { ok: true, status: 200, json: async () => DOSYALAR } as Response;
    }) as typeof fetch;
  }

  it("BORCLU alani bir SECIMDIR ve kisileri listeler", async () => {
    icraSahtele();
    ciz(IcraPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni icra dosyası" }));
    const modal = await screen.findByRole("dialog");
    const secim = await within(modal).findByRole("combobox", { name: /Borçlu/ });
    expect(within(secim).getByRole("option", { name: "Ayse Yilmaz" })).toBeInTheDocument();
  });

  it("kisi listesi CEKILEMEZSE alan serbest metne DUSER — dosya acilabilir kalir", async () => {
    icraSahtele("admin", true);
    ciz(IcraPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni icra dosyası" }));
    const modal = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(within(modal).getByRole("textbox", { name: /Borçlu/ })).toBeInTheDocument(),
    );
  });

  it("(P168 §2) YONETICI ARTIK YAZAR: 'Yeni dosya' CIZILIR", async () => {
    // ESKI OLCUM TERSINEYDI ve o gun DOGRUYDU: uc `require_role("admin")`
    // idi, basilacak ama 403 alacak bir dugme cizmemek dogru karardi.
    //
    // P168'de olculdu ki bu, brief'in "icra olusturma yapilmamis"
    // bildiriminin KOK NEDENIYDI: yonetici icin sayfa SALT
    // GORUNTULEMEYDI. Uc admin+yonetici'ye acildi (icra dosyasi acmak
    // TESIS YONETIMI isidir) ve dugme artik cizilmeli.
    icraSahtele("yonetici");
    ciz(IcraPage);
    await waitFor(() => expect(screen.getByText("2026/123")).toBeInTheDocument());
    expect(
      screen.getByRole("button", { name: "Yeni icra dosyası" }),
    ).toBeInTheDocument();
  });

  it("(P168 §2) SAHA ROLU hala YAZAMAZ — genisleme SINIRLI", async () => {
    // Karsilik olcumu: yetki YONETICIYE acildi, HERKESE degil. Bu satir
    // olmasaydi "dugmeyi herkese cizelim" diyen bir regresyon testten
    // gecerdi.
    icraSahtele("security");
    ciz(IcraPage);
    await waitFor(() => expect(screen.getByText("2026/123")).toBeInTheDocument());
    expect(screen.queryByRole("button", { name: "Yeni icra dosyası" })).toBeNull();
  });

  it("UC DUSTUGUNDE hata + 'kayit yok' YAZMAZ", async () => {
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      if (String(girdi).includes("/api/me")) {
        return { ok: true, status: 200, json: async () => ({ role: "admin" }) } as Response;
      }
      return {
        ok: false,
        status: 500,
        json: async () => ({ error: { message: "sunucu" } }),
      } as Response;
    }) as typeof fetch;
    ciz(IcraPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
    expect(screen.queryByText(/İcra kaydı yok|Kayıt yok/i)).toBeNull();
  });
});
