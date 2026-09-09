// @vitest-environment jsdom
// (P222 §2) SSO KAYDINDA E-POSTA SAGLAYICIDAN DOLAR — VE SALT OKUNURDUR.
//
// =========================================================================
// OLCULEN DURUM
// =========================================================================
// Sunucu e-postayi ZATEN biliyor ve `POST /auth/oauth/sonuc` yanitinda
// `eposta` alaniyla donuyordu. Kayilan yer ISTEMCIYDI: `/giris/oauth`
// sonucu `sessionStorage`a birakirken YALNIZ `ad`i tasiyordu, `eposta`yi
// DUSURUYORDU. Kullanici, sunucunun bildigi adresi elle yaziyordu.
//
// =========================================================================
// NEDEN SALT OKUNUR
// =========================================================================
// Sunucu adresi HER SSO YOLUNDA imzali `baglama_jetonu`nun ICINDEN okur
// (`kayit.tesis_olustur`, `oauth.rol_tamamla`); formda yazilan deger
// HICBIR YERDE kullanilmaz. Duzenlenebilir birakmak, yazilanin SESSIZCE
// yok sayilmasi demekti. Ayrica elle yazilan adres DOGRULANMAMIS olurdu
// ve dogrulanmamis adresle allowlist eslesmesi hesap ele gecirmedir
// (P180 dersi).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import OauthDonusPage from "@/app/giris/oauth/page";
import KayitPage from "@/app/kayit/page";
import { OAUTH_KAYIT_SONUC } from "@/components/SosyalGiris";

import { ciz } from "./yardimci";

// SORGU DIZESI TEST BASINA DEGISIR: `/giris/oauth` `?oauth=<id>`
// olmadan hic istek atmaz ve testin sebebi gorunmeden duserdi.
const sorgu = { deger: "" };

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/kayit",
  useSearchParams: () => new URLSearchParams(sorgu.deger),
}));

const json = (govde: unknown) =>
  new Response(JSON.stringify(govde), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });

function sonucBirak(ek: Record<string, unknown>) {
  sessionStorage.setItem(
    OAUTH_KAYIT_SONUC,
    JSON.stringify({
      rol: "yonetici",
      baglamaJetonu: "jeton",
      saglayici: "google",
      ad: "Ayse Yilmaz",
      ...ek,
    }),
  );
}

afterEach(() => {
  sorgu.deger = "";
  sessionStorage.clear();
  vi.restoreAllMocks();
});

function agSahtele() {
  globalThis.fetch = (async () => json({ saglayicilar: [] })) as typeof fetch;
}

// `data-test`, `data-testid` DEGIL: depo bu adi kullaniyor ve
// `findByTestId` onu GORMEZ (ilk yazimda uc test bu yuzden dustu).
const EPOSTA = '[data-test="kayit-eposta"]';

async function epostaAlani(): Promise<HTMLInputElement> {
  return (await waitFor(() => {
    const el = document.querySelector(EPOSTA);
    if (!el) throw new Error("e-posta alani yok");
    return el as HTMLInputElement;
  })) as HTMLInputElement;
}

describe("P222 SSO kaydinda e-posta", () => {
  it("SAGLAYICIDAN GELEN adres alana DOLAR", async () => {
    agSahtele();
    sonucBirak({ eposta: "ayse@ornek.com" });
    ciz(KayitPage);
    const alan = await epostaAlani();
    expect(alan.value).toBe("ayse@ornek.com");
  });

  it("alan SALT OKUNUR — kullanici baska adres yazamaz", async () => {
    agSahtele();
    sonucBirak({ eposta: "ayse@ornek.com" });
    ciz(KayitPage);
    const alan = await epostaAlani();
    expect(alan.readOnly).toBe(true);
  });

  it("APPLE PRIVATE RELAY adresi de DOLAR ve uyarisi gorunur", async () => {
    // P180 karari: relay adresi DOGRULANMIS sayilir. Ama o adrese posta
    // GONDERILEMEZ ve kullanici bunu kaydolmadan once bilmeli.
    agSahtele();
    sonucBirak({
      eposta: "abc123@privaterelay.appleid.com",
      relay: true,
      saglayici: "apple",
    });
    ciz(KayitPage);
    const alan = await epostaAlani();
    expect(alan.value).toBe("abc123@privaterelay.appleid.com");
    expect(screen.getByText(/Apple adresinizi gizledi/)).toBeInTheDocument();
  });

  it("SAGLAYICI E-POSTA VERMEDIYSE sebep soylenir ve cikis sunulur", async () => {
    // Apple e-postayi YALNIZ ilk yetkilendirmede verir; kullanici kaydi
    // yarida birakip tekrar denerse adres GELMEZ. Bos + salt okunur bir
    // alan kullaniciyi cikissiz birakirdi (sunucu 422 `eposta_gerekli`).
    agSahtele();
    sonucBirak({ eposta: undefined, saglayici: "apple" });
    ciz(KayitPage);
    expect(
      await screen.findByText(/e-posta adresi paylaşmadı/),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "E-posta ile devam et" }),
    ).toBeInTheDocument();
  });

  it("PAROLA yolunda alan DUZENLENEBILIR kalir", async () => {
    // Salt okunurlugu tum kayda yaymak, e-posta ile kaydolan kullanicinin
    // KENDI adresini yazamamasi demekti — bu test o asiri duzeltmeyi
    // yakalar.
    agSahtele();
    ciz(KayitPage);
    // rol -> yontem -> e-posta ile kaydol
    await userEvent.click(await screen.findByText("Yönetici"));
    await userEvent.click(
      await screen.findByRole("button", { name: "E-posta ile kaydol" }),
    );
    const alan = await epostaAlani();
    expect(alan.readOnly).toBe(false);
  });

  // ASIL REGRESYON NOKTASI: yukaridaki testler `sessionStorage`i ELLE
  // kuruyor, yani "adresi oraya KIM koyuyor" sorusunu olcmuyorlar.
  // Kusur tam oradaydi: `/giris/oauth` sunucudan gelen `eposta`yi
  // birakmadan atiyordu. Bu test o halkayi surer.
  it("/giris/oauth sunucudan gelen EPOSTAYI sessionStorage'a TASIR", async () => {
    sorgu.deger = "oauth=sonuc-1";
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      if (String(girdi).includes("/api/auth/oauth/sonuc")) {
        return json({
          durum: "kayit",
          saglayici: "google",
          eposta: "ayse@ornek.com",
          relay: false,
          ad: "Ayse Yilmaz",
          baglama_jetonu: "jeton",
        });
      }
      return json({});
    }) as typeof fetch;

    ciz(OauthDonusPage);
    await waitFor(() => {
      const ham = sessionStorage.getItem(OAUTH_KAYIT_SONUC);
      expect(ham).toBeTruthy();
      expect(JSON.parse(ham as string).eposta).toBe("ayse@ornek.com");
    });
  });
});
