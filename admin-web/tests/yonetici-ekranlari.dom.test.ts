// @vitest-environment jsdom
// (P126.5) YONETICININ UC EKSIK EKRANI — Kameralar, Dis hizmetler,
// Yonetim iletisim.
//
// Kilitlenen davranislar, her biri BIR HATA SINIFINI kapatir:
//  1. kamera karosu SEKME GORUNURKEN tazelenir, arka planda DURUR — bu
//     olmadan acik unutulmus bir sekme bosuna istek atardi;
//  2. kare cekilemeyen kamera listesinde zamanlayici HIC kurulmaz;
//  3. dis hizmet telefonu P123 maskesinden gecer ve sunucuya E.164 gider;
//  4. soyad ZORUNLUDUR (sunucu min_length=1) — istek gonderilmeden kesilir;
//  5. yonetim iletisim karti sunucunun DONDURDUGU numarayi gosterir
//     (C1a riza kapisi bu ucta bilerek delik — istemci ikinci bir suzgec
//     koymaz).
//
// MUTASYON DENETIMI: yukaridakilerin hepsi kodu bilerek bozarak dogrulandi.
// TEK KACAN mutasyon `value={telefonGiris(telefon)}` bagini `value={telefon}`
// yapmak — ve bu DOGRU: `onChange` degeri zaten bicimlendirerek sakliyor,
// dolayisiyla ikisi ekranda AYNI seyi uretiyor. Bag yine de duruyor cunku
// `telefon-kapsam` kapisi her telefon alanindan bunu istiyor ve durum baska
// bir yerden (on-doldurma) gelirse maskeyi tek koruyan sey odur.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import DisHizmetlerPage from "@/app/(protected)/dis-hizmetler/page";
import KameralarPage from "@/app/(protected)/kameralar/page";
import YonetimIletisimPage from "@/app/(protected)/yonetim-iletisim/page";

import { ciz } from "./yardimci";

type Cagri = { url: string; method: string; body: unknown };

function taklit(harita: Record<string, unknown>): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    if (anahtar === undefined) {
      return new Response(JSON.stringify({ error: { message: "yok" } }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify(harita[anahtar]), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

/** jsdom'da `visibilityState` salt-okunurdur; testte degistirilebilir kilinir. */
function gorunurluk(deger: DocumentVisibilityState) {
  Object.defineProperty(document, "visibilityState", {
    configurable: true,
    get: () => deger,
  });
  document.dispatchEvent(new Event("visibilitychange"));
}

const KAMERA = {
  id: "k1",
  ad: "Giriş kapısı",
  konum: "A blok",
  snapshot_url: "https://ornek.test/kare.jpg",
  oynatilabilir: true,
  aktif: true,
};

function karoAdresi(): string {
  const img = screen.getByRole("img", { name: "Giriş kapısı" });
  return img.getAttribute("src") ?? "";
}

afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
  gorunurluk("visible");
});

describe("Kameralar (canlı karo)", () => {
  beforeEach(() => gorunurluk("visible"));

  it("aktif kamera karosu snapshot adresinden çizilir", async () => {
    taklit({ "/api/cameras": { items: [KAMERA] } });
    ciz(KameralarPage);
    await screen.findByText("Giriş kapısı");
    expect(karoAdresi()).toContain("https://ornek.test/kare.jpg");
    // Onbellek kirici nesil parametresi ADRESTE olmali.
    expect(karoAdresi()).toContain("_k=");
  });

  it("PASİF kamera ızgarada gösterilmez", async () => {
    taklit({
      "/api/cameras": { items: [{ ...KAMERA, id: "k2", aktif: false }] },
    });
    ciz(KameralarPage);
    // Bos durum ciziliyorsa pasif kamera suzulmus demektir.
    expect(await screen.findByText(/Tanımlı kamera yok/i)).toBeInTheDocument();
  });

  it("sekme GÖRÜNÜRKEN kare tazelenir", async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    taklit({ "/api/cameras": { items: [KAMERA] } });
    ciz(KameralarPage);
    await vi.waitFor(() => screen.getByRole("img", { name: "Giriş kapısı" }));
    const ilk = karoAdresi();
    await vi.advanceTimersByTimeAsync(8000);
    await vi.waitFor(() => expect(karoAdresi()).not.toBe(ilk));
  });

  it("sekme GİZLİYKEN tazeleme DURUR, görünür olunca sürer", async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    taklit({ "/api/cameras": { items: [KAMERA] } });
    ciz(KameralarPage);
    await vi.waitFor(() => screen.getByRole("img", { name: "Giriş kapısı" }));

    gorunurluk("hidden");
    const gizliyken = karoAdresi();
    await vi.advanceTimersByTimeAsync(8000 * 3);
    expect(karoAdresi()).toBe(gizliyken); // uc periyot gecti, adres AYNI

    gorunurluk("visible");
    // Gorunur olur olmaz bir kez tazelenir (bayat kare gostermemek icin).
    await vi.waitFor(() => expect(karoAdresi()).not.toBe(gizliyken));
  });

  it("snapshot adresi olmayan kamerada zamanlayıcı KURULMAZ", async () => {
    const kur = vi.spyOn(globalThis, "setInterval");
    taklit({
      "/api/cameras": { items: [{ ...KAMERA, snapshot_url: null }] },
    });
    ciz(KameralarPage);
    await screen.findByText("Giriş kapısı");
    // ARALIGA gore bakilir, cagri sayisina degil: `waitFor` kendi 50 ms'lik
    // zamanlayicisini kuruyor ve "hic cagrilmadi" iddiasi onu yakalayip
    // sahte bir basarisizlik uretiyordu.
    expect(
      kur.mock.calls.some(([, ms]) => ms === 8000),
    ).toBe(false);
    expect(screen.getByText(/Görüntü adresi tanımlı değil/i)).toBeInTheDocument();
  });
});

describe("Dış hizmetler", () => {
  const HIZMET = {
    id: "d1",
    tur: "Çilingir",
    ad: "Ali",
    soyad: "Veli",
    telefon: "+905431992904",
    aciklama: null,
  };

  it("kayıtlı numara MASKELİ gösterilir ve tel: bağlantısı taşır", async () => {
    taklit({ "/api/external-services": { note: null, items: [HIZMET] } });
    ciz(DisHizmetlerPage);
    const bag = await screen.findByRole("link", { name: "0543 199 29 04" });
    expect(bag).toHaveAttribute("href", "tel:+905431992904");
  });

  it("bölüm notu gösterilir", async () => {
    taklit({
      "/api/external-services": { note: "Acil çilingir 7/24", items: [] },
    });
    ciz(DisHizmetlerPage);
    expect(await screen.findByText("Acil çilingir 7/24")).toBeInTheDocument();
  });

  it("telefon yazılırken GRUPLANIR ve sunucuya E.164 gider", async () => {
    const c = taklit({
      "/api/external-services": { note: null, items: [] },
    });
    ciz(DisHizmetlerPage);
    await screen.findByText(/Kayıtlı hizmet yok/i);

    await userEvent.type(screen.getByLabelText(/Hizmet türü/i), "Çilingir");
    await userEvent.type(screen.getByLabelText(/^Ad$/i), "Ali");
    await userEvent.type(screen.getByLabelText(/Soyad/i), "Veli");
    const tel = screen.getByLabelText(/Telefon/i);
    await userEvent.type(tel, "5431992904");
    expect(tel).toHaveValue("0543 199 29 04"); // maske EKRANDA

    await userEvent.click(screen.getByRole("button", { name: /Ekle/i }));
    await waitFor(() => {
      const g = c.find((x) => x.method === "POST");
      expect(g).toBeDefined();
      // Sunucuya NORMALLESTIRILMIS gider, ekrandaki bosluklu bicim DEGIL.
      expect((g!.body as { telefon: string }).telefon).toBe("+905431992904");
    });
  });

  it("SOYAD boşken istek GÖNDERİLMEZ", async () => {
    const c = taklit({ "/api/external-services": { note: null, items: [] } });
    ciz(DisHizmetlerPage);
    await screen.findByText(/Kayıtlı hizmet yok/i);

    await userEvent.type(screen.getByLabelText(/Hizmet türü/i), "Çilingir");
    await userEvent.type(screen.getByLabelText(/^Ad$/i), "Ali");
    await userEvent.type(screen.getByLabelText(/Telefon/i), "5431992904");
    await userEvent.click(screen.getByRole("button", { name: /Ekle/i }));

    expect(await screen.findByText(/soyad zorunludur/i)).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });

  it("EKSİK telefonla istek GÖNDERİLMEZ", async () => {
    const c = taklit({ "/api/external-services": { note: null, items: [] } });
    ciz(DisHizmetlerPage);
    await screen.findByText(/Kayıtlı hizmet yok/i);

    await userEvent.type(screen.getByLabelText(/Hizmet türü/i), "Çilingir");
    await userEvent.type(screen.getByLabelText(/^Ad$/i), "Ali");
    await userEvent.type(screen.getByLabelText(/Soyad/i), "Veli");
    await userEvent.type(screen.getByLabelText(/Telefon/i), "543199");
    await userEvent.click(screen.getByRole("button", { name: /Ekle/i }));

    await screen.findByText(/eksik/i);
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });
});

describe("Yönetim iletişim", () => {
  it("yönetici adı ve sunucunun döndürdüğü numara gösterilir", async () => {
    taklit({
      "/api/yonetici-iletisim": {
        yoneticiler: [
          {
            user_id: "u1",
            ad_soyad: "Ayşe Yılmaz",
            telefon: "+905431992904",
            avatar_url: null,
          },
        ],
        yonetim_email: "yonetim@ornek.test",
      },
    });
    ciz(YonetimIletisimPage);
    expect(await screen.findByText("Ayşe Yılmaz")).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: "0543 199 29 04" }),
    ).toHaveAttribute("href", "tel:+905431992904");
    expect(
      screen.getByRole("link", { name: "yonetim@ornek.test" }),
    ).toHaveAttribute("href", "mailto:yonetim@ornek.test");
  });

  it("numarası OLMAYAN yönetici için açık bir satır yazılır", async () => {
    taklit({
      "/api/yonetici-iletisim": {
        yoneticiler: [
          { user_id: "u2", ad_soyad: "Can Demir", telefon: null, avatar_url: null },
        ],
        yonetim_email: null,
      },
    });
    ciz(YonetimIletisimPage);
    await screen.findByText("Can Demir");
    expect(screen.getByText(/Telefon paylaşılmamış/i)).toBeInTheDocument();
    expect(screen.queryByRole("link")).toBeNull();
  });
});
