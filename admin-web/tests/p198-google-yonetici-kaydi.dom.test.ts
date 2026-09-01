// @vitest-environment jsdom
// (P198) GOOGLE ILE YONETICI KAYDI — AKISIN TAMAMI.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Yeni yonetici kaydinda "Google ile devam" secilince kullaniciya TESIS ID
// soruluyordu ve kayit tamamlanamiyordu. P185'in kabul kriteri ise sunu
// diyor: Google dogrulamasi bitince "Yeni tesis olustur / Mevcut tesise
// katil" AYRIMI cikmali; "yeni tesis" secilirse TESIS ADI sorulmali ve
// Tesis ID SISTEM tarafindan uretilip gosterilmeli.
//
// KOK NEDEN: kayit sayfasi OAuth'u `niyet="giris"` ile baslatiyordu.
// Sunucuda o niyet "bu kimlik hangi hesaba BAGLI?" sorusudur; yeni bir
// yonetici hicbir hesaba bagli olmadigi icin yanit `baglama_gerekli`
// oluyor ve `/giris/oauth` kullaniciyi Tesis ID formuna dusuruyordu.
//
// SUNUCUDA OLCULDU (ayni bagli-olmayan kimlik, dev API):
//     niyet=kayit -> durum='kayit'            (baglama jetonu VAR)
//     niyet=giris -> durum='baglama_gerekli'  (Tesis ID formu)
// Yani sunucu DOGRUYDU; istemci yanlis niyeti gonderiyordu.
//
// ===========================================================================
// NEDEN BU TEST VAR (ve neden mevcut testler yakalamadi)
// ===========================================================================
// `kayit-rolleri.test.ts` bu sayfayi KAYNAK TARAMASIYLA olcuyor: dosyayi
// metin olarak okuyup "adim sirasi dogru mu", "rol listesi dogru mu" diye
// bakiyor. Boyle bir tarama, adimlarin SIRASINI gorur ama adimlar arasinda
// GERCEKTEN gecilip gecilmedigini goremez — ve kirilan tam olarak oydu.
//
// Bu dosya akisi UCTAN UCA surer: dugmeye basar, giden istegin govdesini
// okur, saglayici donusunu taklit eder ve tesis kodu ekranina kadar her
// adimi gezer.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import KayitSayfasi from "@/app/kayit/page";
import { OAUTH_KAYIT_SONUC } from "@/components/SosyalGiris";

import { ciz } from "./yardimci";

/**
 * `data-test` ILE SECIM — `data-testid` DEGIL.
 *
 * Depo `data-test` kullaniyor; Testing Library'nin varsayilani
 * `data-testid`. `findByTestId` bu yuzden HICBIR SEY bulmuyor (olculdu:
 * bes testin besi "Unable to find element" ile dustu). Ozniteligi global
 * olarak degistirmek 150+ dosyayi etkilerdi; secici burada yazilir.
 */
function kanca(ad: string): HTMLElement {
  const el = document.querySelector<HTMLElement>(`[data-test="${ad}"]`);
  if (!el) throw new Error(`data-test="${ad}" bulunamadi`);
  return el;
}

function kancaVarMi(ad: string): boolean {
  return document.querySelector(`[data-test="${ad}"]`) !== null;
}

async function kancaBekle(ad: string): Promise<HTMLElement> {
  await waitFor(() => expect(kancaVarMi(ad)).toBe(true));
  return kanca(ad);
}

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/kayit",
  useSearchParams: () => new URLSearchParams(),
}));

const JETON = "baglama-jetonu-p198";

/** Giden istekleri kaydeden sahte `fetch`. */
function agiSahtele() {
  const cagrilar: { yol: string; govde: Record<string, unknown> | null }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const yol = String(girdi);
    const govde = init?.body
      ? (JSON.parse(String(init.body)) as Record<string, unknown>)
      : null;
    if (init?.method) cagrilar.push({ yol, govde });

    const yanit = (v: unknown) =>
      new Response(JSON.stringify(v), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });

    if (yol.includes("/oauth/saglayicilar")) {
      return yanit({ saglayicilar: ["google"] });
    }
    if (yol.includes("/oauth/baslat/")) {
      return yanit({ adres: "https://accounts.google.test/o/oauth2/v2/auth?x=1" });
    }
    if (yol.includes("/kayit/tesis-olustur")) {
      // Sunucu TESIS KODUNU URETIP doner — kullanici bir kod GIRMEZ.
      return yanit({ tesis_ad: "Yesil Vadi Sitesi", tesis_kodu: "YESI-260901" });
    }
    return yanit({});
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => {
  vi.restoreAllMocks();
  sessionStorage.clear();
});

describe("(P198) Google ile yonetici kaydi — uctan uca", () => {
  it("1) YONETICI + Google -> istek `niyet=kayit` TASIR", async () => {
    const cagrilar = agiSahtele();
    ciz(KayitSayfasi);

    await userEvent.click(await kancaBekle("kayit-rol-yonetici"));

    // Onaylar SAGLAYICIYA GITMEDEN once alinir: backend `niyet=kayit`i
    // onaysiz 422 ile reddeder.
    await userEvent.click(await kancaBekle("kayit-onay-sozlesme"));
    await userEvent.click(kanca("kayit-onay-kvkk"));

    const dugme = await screen.findByRole("button", { name: /Google/ });
    await userEvent.click(dugme);

    await waitFor(() =>
      expect(cagrilar.some((c) => c.yol.includes("/oauth/baslat/"))).toBe(true),
    );
    const baslat = cagrilar.find((c) => c.yol.includes("/oauth/baslat/"))!;
    // ASIL OLCUM: `niyet` "kayit" olmali. "giris" oldugunda kullanici
    // Tesis ID formuna dusuyordu (kusurun ta kendisi).
    expect(baslat.govde?.niyet, "niyet 'kayit' degil — Tesis ID formuna duser")
      .toBe("kayit");
    expect(baslat.govde?.onay_sozlesme).toBe(true);
    expect(baslat.govde?.onay_kvkk).toBe(true);
  });

  it("2) ONAYLAR ALINMADAN saglayiciya GIDILMEZ", async () => {
    const cagrilar = agiSahtele();
    ciz(KayitSayfasi);
    await userEvent.click(await kancaBekle("kayit-rol-yonetici"));

    // Onaysiz: sosyal dugmeler HIC cizilmez — backend 422 verecegi icin
    // kullaniciyi sebebi gorunmeyen bir donguye sokmak yerine engelliyoruz.
    expect(screen.queryByRole("button", { name: /Google/ })).toBeNull();
    expect(kancaVarMi("kayit-sosyal-onay-uyari")).toBe(true);
    expect(cagrilar.some((c) => c.yol.includes("/oauth/baslat/"))).toBe(false);
  });

  it("3) DONUSTE 'yeni tesis / katil' AYRIMI cikar", async () => {
    agiSahtele();
    // `/giris/oauth` sayfasinin durum='kayit' dalinda yaptigi sey:
    sessionStorage.setItem(
      OAUTH_KAYIT_SONUC,
      JSON.stringify({
        rol: "yonetici", baglamaJetonu: JETON, saglayici: "google",
        ad: "Ayse Yonetici",
      }),
    );
    ciz(KayitSayfasi);

    // Bilgiler adimindan devam eder ve ad ON-DOLUDUR.
    const adAlani = await kancaBekle("kayit-ad");
    expect(adAlani).toHaveValue("Ayse Yonetici");

    await userEvent.type(kanca("kayit-soyad"), "Yilmaz");
    await userEvent.type(
      kanca("kayit-eposta"), "ayse@ornek.com");
    await userEvent.type(kanca("kayit-telefon"), "5321112233");
    await userEvent.click(kanca("kayit-onay-sozlesme"));
    await userEvent.click(kanca("kayit-onay-kvkk"));
    await userEvent.click(kanca("kayit-bilgi-gonder"));

    // KABUL KRITERI: ayrim EKRANI. Kusurlu surumde bu ekran HIC gorunmuyordu.
    expect(await kancaBekle("kayit-secim-yeni")).toBeInTheDocument();
    expect(kanca("kayit-secim-katil")).toBeInTheDocument();
  });

  it("4) 'Yeni tesis' -> TESIS ADI sorulur, TESIS ID SORULMAZ", async () => {
    agiSahtele();
    sessionStorage.setItem(
      OAUTH_KAYIT_SONUC,
      JSON.stringify({ rol: "yonetici", baglamaJetonu: JETON,
                      saglayici: "google", ad: "Ayse Yonetici" }),
    );
    ciz(KayitSayfasi);

    await kancaBekle("kayit-ad");
    await userEvent.type(kanca("kayit-soyad"), "Yilmaz");
    await userEvent.type(kanca("kayit-eposta"), "ayse@ornek.com");
    await userEvent.type(kanca("kayit-telefon"), "5321112233");
    await userEvent.click(kanca("kayit-onay-sozlesme"));
    await userEvent.click(kanca("kayit-onay-kvkk"));
    await userEvent.click(kanca("kayit-bilgi-gonder"));

    await userEvent.click(await kancaBekle("kayit-secim-yeni"));

    // TESIS ADI sorulur...
    expect(await kancaBekle("kayit-tesis-ad")).toBeInTheDocument();
    // ...TESIS ID SORULMAZ. Kusurun gorunur imzasi tam olarak buydu.
    expect(
      kancaVarMi("kayit-tesis-kodu"),
      "yeni tesis acan yoneticiden Tesis ID ISTENMEZ",
    ).toBe(false);
  });

  it("5) TESIS KODU sistemce URETILIP kullaniciya GOSTERILIR", async () => {
    const cagrilar = agiSahtele();
    sessionStorage.setItem(
      OAUTH_KAYIT_SONUC,
      JSON.stringify({ rol: "yonetici", baglamaJetonu: JETON,
                      saglayici: "google", ad: "Ayse Yonetici" }),
    );
    ciz(KayitSayfasi);

    await kancaBekle("kayit-ad");
    await userEvent.type(kanca("kayit-soyad"), "Yilmaz");
    await userEvent.type(kanca("kayit-eposta"), "ayse@ornek.com");
    await userEvent.type(kanca("kayit-telefon"), "5321112233");
    await userEvent.click(kanca("kayit-onay-sozlesme"));
    await userEvent.click(kanca("kayit-onay-kvkk"));
    await userEvent.click(kanca("kayit-bilgi-gonder"));
    await userEvent.click(await kancaBekle("kayit-secim-yeni"));

    await userEvent.type(
      await kancaBekle("kayit-tesis-ad"), "Yesil Vadi Sitesi");
    await userEvent.click(kanca("kayit-rol-ozel-gonder"));

    // Sunucuya SOSYAL yolla gidilir: baglama jetonu + tesis adi.
    await waitFor(() =>
      expect(cagrilar.some((c) => c.yol.includes("/kayit/tesis-olustur")))
        .toBe(true),
    );
    const istek = cagrilar.find((c) => c.yol.includes("/kayit/tesis-olustur"))!;
    expect(istek.govde?.baglama_jetonu).toBe(JETON);
    expect(istek.govde?.tesis_ad).toBe("Yesil Vadi Sitesi");

    // VE KOD EKRANDA: kullanici onu okuyup saklayacak.
    expect(await kancaBekle("kayit-uretilen-kod")).toHaveTextContent(
      "YESI-260901",
    );
  });
});
