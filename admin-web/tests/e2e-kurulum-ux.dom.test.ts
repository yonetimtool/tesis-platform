// @vitest-environment jsdom
// (E2E 2026-09) KURULUM TURU — web kurulum/UX bulgulari.
//
// Uctan uca test turu (bulgular/kurulum.md) su kusurlari olctu:
//   03  kurulum sihirbazinin "Sayaçlar" adimi basligi ham sablon
//       ("{gecilen}/{toplam} adım") — anahtar adi cakisiyordu,
//   05  panelin verdigi gecici kod `window.alert` ile BIR KEZ gorunuyordu,
//   06  ulkesiz telefonda istek yine gidiyor, form altinda ham 422 metni,
//   07  ilk giriste tur ve kurulum hatirlaticisi USTUSTE aciliyordu,
//   08-10  bos durumlar yanlis/eylemsizdi (duyuru "yalniz mobilden",
//       finans "Bu listede kayıt yok." — kasa yokken ne yapilacagi yok),
//   11  on ekranda "?" yardimi yoktu, finans alt sayfalari ve Sakinler
//       baska ekranin metnini gosteriyordu,
//   12  tesis listesi sayfalamasizdi (3788 satir, 805 KB, 11-27 s).
//
// SAHTE HTTP KATMANINDA (P200 dersi): sorguyu kuran katman da olculur.
import { fireEvent, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TenantlarPage from "@/app/(protected)/tenants/page";
import { HareketSayfasi } from "@/components/finans/hareket-sayfasi";
import { KurulumHatirlatici } from "@/components/KurulumHatirlatici";
import { EKRAN_YARDIMI, ekranYardimi } from "@/lib/ekran-yardimi";
import { tr } from "@/lib/i18n/sozluk/tr";
import { KURULUM_HEDEFLERI } from "@/lib/kurulum-adimlari";

import { ciz } from "./yardimci";

let yol = "/dashboard";
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => yol,
  useSearchParams: () => new URLSearchParams(),
}));

const json = (govde: unknown, durum = 200) =>
  new Response(JSON.stringify(govde), {
    status: durum,
    headers: { "Content-Type": "application/json" },
  });

interface Cagri {
  url: string;
  metot: string;
  govde?: unknown;
}

/** En uzun onek kazanir; eslesmeyen url 404. */
function sahtele(harita: Record<string, unknown>, cagrilar: Cagri[] = []) {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k) || url.startsWith(`${metot} ${k}`))
      .sort((a, b) => b.length - a.length)[0];
    const ozel = `${metot} ${url.split("?")[0]}`;
    if (ozel in harita) return json(harita[ozel]);
    if (anahtar === undefined) return json({ error: { message: "yok" } }, 404);
    return json(harita[anahtar]);
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => {
  vi.restoreAllMocks();
  yol = "/dashboard";
});

// ======================================================================
// KURULUM-03
// ======================================================================
describe("(KURULUM-03) sayac adiminin basligi", () => {
  it("adim sayaci anahtarini KULLANMAZ; hicbir adim basligi sablon degil", () => {
    expect(KURULUM_HEDEFLERI.sayac.etiket).not.toBe("kurulumSayac");
    expect(tr[KURULUM_HEDEFLERI.sayac.etiket]).toBe("Sayaçlar");
    for (const [ad, h] of Object.entries(KURULUM_HEDEFLERI)) {
      // Yer tutucu tasiyan bir baslik parametresiz cizilir ve kullanici
      // ham `{...}` gorur — olculen kusurun ta kendisi.
      expect(tr[h.etiket], ad).not.toMatch(/\{/);
    }
  });
});

// ======================================================================
// KURULUM-11
// ======================================================================
describe("(KURULUM-11) baglam ici yardim", () => {
  const EKSIKTI = [
    "/units",
    "/assets",
    "/checkpoints",
    "/patrol-plans",
    "/anketler",
    "/etkinlik-yonetimi",
    "/complaints",
    "/rezervasyon-yonetimi",
    "/arac-gecisleri",
    "/akilli-ev",
    "/sayac-okuma",
    "/transparency",
  ];

  it("olculen on iki ekranin HER BIRI kendi metnini alir", () => {
    const anahtarlar = EKSIKTI.map((y) => ekranYardimi(y));
    for (const [i, a] of anahtarlar.entries()) {
      expect(a, EKSIKTI[i]).not.toBeNull();
    }
    // Ayni metni iki ekrana yapistirmak "?"i gene ise yaramaz kilardi.
    expect(new Set(anahtarlar).size).toBe(EKSIKTI.length);
  });

  it("finans alt sayfalari ve Sakinler BASKA ekranin metnini gostermez", () => {
    for (const y of [
      "/finans/borclular",
      "/finans/butce",
      "/finans/giderler",
      "/finans/tahsilatlar",
    ]) {
      expect(ekranYardimi(y), y).not.toBe("yardimFinans");
    }
    // Alt yol da ayni metni alir (en uzun onek).
    expect(ekranYardimi("/finans/butce/2026")).toBe("yardimButce");
    // Kaydi olmayan finans alt sayfasi ortak metne duser.
    expect(ekranYardimi("/finans/virman")).toBe("yardimFinans");
    // Sakinler ekrani hesap ACMAZ — Kullanicilar metni orada yanlisti.
    expect(ekranYardimi("/residents")).not.toBe("yardimUsers");
  });

  it("kayitli her anahtarin TR metni var", () => {
    for (const a of Object.values(EKRAN_YARDIMI)) {
      expect(tr[a]?.trim(), a).toBeTruthy();
    }
  });
});

// ======================================================================
// KURULUM-07
// ======================================================================
describe("(KURULUM-07) tur acikken kurulum hatirlaticisi", () => {
  const DURUM = { toplam: 19, gecilen: 0 };

  function Sarmal() {
    return KurulumHatirlatici({ rol: "yonetici" });
  }

  it("turu HENUZ GORMEMIS yoneticide hatirlatici ACILMAZ", async () => {
    const cagrilar = sahtele({
      "/api/panel/kurulum": DURUM,
      "/api/me": { role: "yonetici", tur_goruldu_at: null },
    });
    ciz(Sarmal);
    // Iki istek de cevaplandiktan sonra bile pencere yok.
    await waitFor(() => {
      expect(cagrilar.some((c) => c.url === "/api/me")).toBe(true);
      expect(cagrilar.some((c) => c.url === "/api/panel/kurulum")).toBe(true);
    });
    await new Promise((c) => setTimeout(c, 20));
    expect(screen.queryByText("Kurulumu tamamlayın")).toBeNull();
  });

  it("turu GORMUS yoneticide hatirlatici acilir (bastirma fazla genis degil)", async () => {
    sahtele({
      "/api/panel/kurulum": DURUM,
      "/api/me": { role: "yonetici", tur_goruldu_at: "2026-09-01T10:00:00Z" },
    });
    ciz(Sarmal);
    expect(await screen.findByText("Kurulumu tamamlayın")).toBeTruthy();
  });

  it("profil ucu DUSERSE hatirlatici yine acilir", async () => {
    sahtele({ "/api/panel/kurulum": DURUM });
    ciz(Sarmal);
    expect(await screen.findByText("Kurulumu tamamlayın")).toBeTruthy();
  });
});

// ======================================================================
// KURULUM-10
// ======================================================================
describe("(KURULUM-10) finans bos durumu", () => {
  function Sayfa() {
    return HareketSayfasi({
      baslikAnahtari: "kabukGelirler",
      tip: "gelir",
      raporKodu: "finansal_hareketler",
      araclar: null,
      yenile: 0,
    });
  }

  it("KASA YOKKEN once kasa tanimlamaya yonlendirir", async () => {
    sahtele({
      "/api/panel/finans-hareketler": { meta: { total: 0 }, items: [] },
      "/api/panel/kasalar": { meta: { total: 0 }, items: [] },
    });
    ciz(Sayfa);
    expect(await screen.findByText(/Henüz kasa yok/)).toBeTruthy();
    const bag = screen.getByRole("link", { name: "Kasa tanımla" });
    expect(bag.getAttribute("href")).toBe("/tanimlar?defter=kasalar");
  });

  it("KASA VARKEN ilk kayda yonlendirir, kasa bagi cizilmez", async () => {
    sahtele({
      "/api/panel/finans-hareketler": { meta: { total: 0 }, items: [] },
      "/api/panel/kasalar": { meta: { total: 1 }, items: [{ id: "k1", ad: "Ana", kod: "A" }] },
    });
    ciz(Sayfa);
    expect(await screen.findByText(/ile ilk kaydı girin/)).toBeTruthy();
    expect(screen.queryByRole("link", { name: "Kasa tanımla" })).toBeNull();
  });
});

// ======================================================================
// KURULUM-05 / 06 / 12 — tesisler ekrani
// ======================================================================
function tesis(n: number) {
  return {
    id: `t-${n}`,
    ad: `Tesis ${n}`,
    kayit_kodu: `KOD-${n}`,
    kurulum_tamamlandi: false,
    created_at: "2026-01-01T00:00:00Z",
    platform_admini_var: false,
  };
}

describe("(KURULUM-12) tesis listesi SUNUCUDA sayfalanir", () => {
  it("ilk istek `limit`/`offset` tasir; sonraki sayfa ofseti ve numarayi surdurur", async () => {
    yol = "/tenants";
    const cagrilar: Cagri[] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      cagrilar.push({ url, metot: "GET" });
      const ofset = Number(new URL(url, "http://x").searchParams.get("offset") ?? 0);
      // Sunucu 60 tesis soyler, istenen sayfanin satirlarini dondurur.
      const items = Array.from({ length: 25 }, (_, i) => tesis(ofset + i + 1)).filter(
        (x) => Number(x.id.slice(2)) <= 60,
      );
      return json({ items, toplam: 60 });
    }) as typeof fetch;

    ciz(TenantlarPage);
    await screen.findByText("Tesis 1");
    expect(cagrilar[0].url).toContain("limit=25");
    expect(cagrilar[0].url).toContain("offset=0");
    // Toplam SUNUCUDAN: sayfadaki 25 degil.
    expect(await screen.findByText(/60/)).toBeTruthy();

    await userEvent.click(screen.getByRole("button", { name: "Sonraki sayfa" }));
    await screen.findByText("Tesis 26");
    expect(cagrilar.some((c) => c.url.includes("offset=25"))).toBe(true);
    const sira = [...document.querySelectorAll('[data-test="tablo-sira"]')].map(
      (x) => x.textContent,
    );
    // Numara LISTENIN TAMAMINA gore: ikinci sayfa 26'dan baslar.
    expect(sira[0]).toBe("26");
  });

  it("arama degisince ILK SAYFAYA donulur", async () => {
    yol = "/tenants";
    const cagrilar: Cagri[] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      cagrilar.push({ url, metot: "GET" });
      return json({ items: [tesis(1)], toplam: 60 });
    }) as typeof fetch;
    ciz(TenantlarPage);
    await screen.findByText("Tesis 1");
    await userEvent.click(screen.getByRole("button", { name: "Sonraki sayfa" }));
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url.includes("offset=25"))).toBe(true),
    );
    await userEvent.type(
      document.querySelector('[data-test="tesis-ara"]') as HTMLElement,
      "oltu",
    );
    await waitFor(
      () => {
        const son = cagrilar.at(-1)!.url;
        expect(son).toContain("q=oltu");
        expect(son).toContain("offset=0");
      },
      { timeout: 2000 },
    );
  });
});

/** Ulke seciciyi gercek akisla surer (bkz. `profil.dom.test.ts`). */
async function ulkeSec(kod: string) {
  await userEvent.click(
    document.querySelector('[data-test="telefon-ulke"]') as HTMLButtonElement,
  );
  await userEvent.click(
    document.querySelector(`[data-test="telefon-ulke-${kod}"]`) as HTMLButtonElement,
  );
}

async function formuDoldur(telefon: string, ulke?: string) {
  await userEvent.click((await screen.findByRole("button", { name: /Yeni tesis/ })));
  const ad = await screen.findByLabelText(/^Ad/);
  await userEvent.type(ad, "Ayse Yilmaz");
  const eposta = document.querySelectorAll<HTMLInputElement>('[data-test="eposta-alani"]');
  // Ilk e-posta yonetim maili (opsiyonel), ikincisi yoneticinin.
  await userEvent.type(eposta[eposta.length - 1], "ayse@ornek.com");
  if (ulke) await ulkeSec(ulke);
  const numara = document.querySelector('[data-test="telefon-numara"]') as HTMLElement;
  await userEvent.type(numara, telefon);
}

describe("(KURULUM-06) ulkesiz telefon", () => {
  it("istek GITMEZ ve alanin kurali form hatasi olarak yazilir", async () => {
    yol = "/tenants";
    const cagrilar = sahtele({ "/api/tenants": { items: [], toplam: 0 } });
    ciz(TenantlarPage);
    await formuDoldur("5355668068");
    fireEvent.submit(document.getElementById("tesis-form") as HTMLFormElement);
    expect((await screen.findAllByText("Önce ülke kodunu seçin.")).length).toBeGreaterThan(0);
    expect(cagrilar.filter((c) => c.metot === "POST")).toHaveLength(0);
    expect(screen.queryByText(/İstek gövdesi geçersiz/)).toBeNull();
  });
});

describe("(KURULUM-05) gecici kod penceresi", () => {
  it("kod `window.alert` ile DEGIL, kopyalanabilir pencerede gosterilir", async () => {
    yol = "/tenants";
    const alarm = vi.spyOn(window, "alert").mockImplementation(() => undefined);
    const cagrilar: Cagri[] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      const metot = (init?.method ?? "GET").toUpperCase();
      cagrilar.push({ url, metot });
      if (metot === "POST") {
        return json({
          tenant_id: "t-9",
          yoneticiler: [
            { user_id: "u-1", ad: "Ayse Yilmaz", birincil: true, temp_code: "V9NS-N9CG" },
          ],
        }, 201);
      }
      return json({ items: [], toplam: 0 });
    }) as typeof fetch;

    ciz(TenantlarPage);
    await formuDoldur("5355668068", "TR");
    fireEvent.submit(document.getElementById("tesis-form") as HTMLFormElement);

    expect(await screen.findByText("Tesis ve yöneticiler oluşturuldu")).toBeTruthy();
    const kutu = document.querySelector('[data-test="tesis-gecici-kodlar"]') as HTMLElement;
    expect(kutu.textContent).toContain("V9NS-N9CG");
    expect(kutu.textContent).toContain("Ayse Yilmaz");
    // Kopyala dugmesi var (KopyaKod).
    expect(kutu.querySelector("button")).not.toBeNull();
    expect(alarm).not.toHaveBeenCalled();
    expect(cagrilar.some((c) => c.metot === "POST")).toBe(true);
  });
});
