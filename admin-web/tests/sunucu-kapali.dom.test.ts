// @vitest-environment jsdom
// (P171 duzeltme) API KAPALIYKEN ADMIN-WEB AYAKTA VE ANLAMLI.
//
// =========================================================================
// KILITLENEN OLAY
// =========================================================================
// Goc 0066 dustu -> `api` baslamadi -> `admin-web` de baslamadi (ona
// `service_healthy` ile bagliydi) -> `docker ps` bos, alan adi 502,
// teshis icin log bile yok. Ortam SESSIZCE yok oldu.
//
// Karar: iki servisin BASARISIZLIK MODU AYRI. API'nin sema uyumsuzlugunda
// kapali kalmasi dogru (yanlis semaya yazmak veriyi bozar); admin-web ise
// veriye YAZMAZ, API'yi CAGIRIR — bir sayfa gostermeli.
//
// OLCULEN DORT SEY:
//  1. Bagimlilik kapisi GERCEKTEN kaldirildi (compose).
//  2. API'ye ulasilamayinca MERKEZI durum ekrani cizilir — her sayfa
//     kendi metnini yazmaz.
//  3. Sunucu geri gelince durum KENDILIGINDEN temizlenir; "tekrar dene"
//     de calisir.
//  4. Giris denemesi ANLAMLI hata verir — ozellikle "Giris basarisiz"
//     DEMEZ: o, yanlis parola demektir ve kullaniciyi yanlis yere baktirir.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { readFileSync } from "node:fs";
import React from "react";
import useSWR from "swr";

import { SunucuDurumu } from "@/components/SunucuDurumu";
import { jsonFetcher } from "@/lib/fetcher";

import { ciz } from "./yardimci";

// Giris formu `useRouter` kullaniyor; App Router taklidi olmadan cizim
// aninda patlar (olculdu: "invariant expected app router to be mounted").
vi.mock("next/navigation", () => ({
  usePathname: () => "/login",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.unstubAllGlobals());

describe("compose bagimlilik kapisi", () => {
  it("admin-web ARTIK api'nin sagligina bagli DEGIL", () => {
    const y = readFileSync("../infra/docker-compose.prod.yml", "utf8");
    const bolum = y.slice(y.indexOf("\n  admin-web:"));
    const sonrasi = bolum.slice(0, bolum.indexOf("\nnetworks:"));
    // `depends_on` bloklari servis basina; admin-web bolumunde HIC olmamali.
    expect(sonrasi).not.toMatch(/^\s{4}depends_on:/m);
    // Ama KENDI saglik kontrolu YERINDE kalmali: bagimliligi kaldirmak,
    // servisin sagliksiz kalmasini gormezden gelmek demek DEGIL.
    expect(sonrasi).toContain("healthcheck:");
  });

  it("api HALA migrate'e bagli — bu kapi KASITLI duruyor", () => {
    // Yari goc edilmis bir semaya karsi servis vermek kapali olmaktan
    // KOTUDUR: kod beklemedigi bir semaya YAZAR.
    const y = readFileSync("../infra/docker-compose.prod.yml", "utf8");
    const api = y.slice(y.indexOf("\n  api:"), y.indexOf("\n  worker:"));
    expect(api).toContain("service_completed_successfully");
  });
});

/** SWR ile veri ceken kucuk bir sayfa taklidi.
 *
 * `jsonFetcher` BILEREK kullaniliyor, sahte bir fetcher DEGIL: olculmek
 * istenen sey tam olarak GERCEK yol — `fetch` -> `jsonFetcher` -> hata
 * kodu -> merkezi ekran. Sahte fetcher, kodu elle atip zinciri atlardi
 * ve `jsonFetcher` bir gun kodu iliştirmeyi birakinca test yine gecerdi.
 */
function SahteSayfa() {
  const { data } = useSWR<{ ad: string }>("/api/deneme", jsonFetcher);
  return React.createElement("p", null, data ? data.ad : "yukleniyor");
}

/** Durum ekrani ciziliyor mu — BASLIK METNINDEN.
 *
 * `role="status"` ile aramak yetmiyor: `ToastProvider` da canli bolge
 * kuruyor ve BOS bir eslesme donduruyordu (olculdu). */
const durumEkraniVar = () =>
  screen.queryByText("Sunucuya ulaşılamıyor") !== null;

function Sarmal() {
  return React.createElement(SunucuDurumu, null, React.createElement(SahteSayfa));
}

describe("merkezi durum ekrani", () => {
  it("API'ye ulasilamayinca DURUM EKRANI cizilir, sayfa icerigi DEGIL", async () => {
    // `fetch` HIC ULASAMIYOR — tarayicinin gercek davranisi.
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));

    ciz(Sarmal);

    const baslik = await screen.findByText("Sunucuya ulaşılamıyor");
    // CANLI BOLGE: durum kullanici bir sey yapmadan degisebilir (sunucu
    // geri gelince) ve ekran okuyucu bunu duymali.
    expect(baslik.closest('[role="status"]')).not.toBeNull();
    // Sayfa icerigi YERINE cizilir, USTUNE degil: arkada yari gorunen bos
    // tablolar kullaniciya "veri yok" dedirtirdi, oysa "okunamadi".
    expect(screen.queryByText("yukleniyor")).toBeNull();
    // "Tekrar dene" YOLU VAR: cikissiz bir hata ekrani, kullaniciyi
    // sayfayi elle yenilemeye zorlardi.
    expect(screen.getByRole("button", { name: /Yeniden dene/i })).toBeTruthy();
  });

  it("SIRADAN bir hata durum ekranini ACMAZ", async () => {
    // Kod bakilmasaydi her 500 "sunucu kapali" gibi gorunur ve gercek
    // kusurlar bu ekranin arkasinda GIZLENIRDI.
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        json: async () => ({ error: { code: "server_error", message: "patladi" } }),
      } as unknown as Response),
    );

    ciz(Sarmal);

    await waitFor(() => expect(screen.getByText("yukleniyor")).toBeTruthy());
    expect(durumEkraniVar()).toBe(false);
  });

  it("SUNUCU GERI GELINCE icerik kendiliginden doner", async () => {
    const sahte = vi.fn().mockRejectedValue(new TypeError("Failed to fetch"));
    vi.stubGlobal("fetch", sahte);

    ciz(Sarmal);
    await screen.findByText("Sunucuya ulaşılamıyor");

    // Sunucu ayaga kalkti.
    sahte.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ ad: "veri geldi" }),
    } as unknown as Response);

    await userEvent.click(screen.getByRole("button", { name: /Yeniden dene/i }));

    await waitFor(() => expect(screen.getByText("veri geldi")).toBeTruthy());
    expect(durumEkraniVar()).toBe(false);
  });
});

describe("BFF: baglanti hatasi TEK BICIMDE dondurulur", () => {
  it("`callBackend` ag hatasini 503 + kod'a cevirir", async () => {
    // Onceden istisna route handler'a kadar cikip Next 500'u uretiyordu:
    // her sayfa kendi metnini gosteriyor, kullanici sunucunun KAPALI
    // oldugunu ogrenemiyordu.
    const kaynak = readFileSync("lib/backend.ts", "utf8");
    expect(kaynak).toContain("apiKapaliYaniti");
    expect(kaynak).toContain("status: 503");
    expect(kaynak).toContain("API_KAPALI_KODU");
  });

  it("giris yolu da AYNI kanaldan gecer (ozel bir yol yok)", () => {
    const kaynak = readFileSync("lib/backend.ts", "utf8");
    // `backendLogin` `callBackend` kullanmali; kendi `fetch`ini yazsaydi
    // giris ekrani "Giris basarisiz" (yani YANLIS PAROLA) derdi.
    const bolum = kaynak.slice(kaynak.indexOf("export async function backendLogin"));
    expect(bolum.slice(0, 400)).toContain("callBackend(");
  });
});

describe("giris ekrani API'siz", () => {
  it("sayfa API cagirmadan cizilir", () => {
    // `/login` yalniz `Host` basligini okur. Bir API cagrisi olsaydi API
    // kapaliyken giris ekrani da acilmazdi — yani kullanicinin elinde
    // HICBIR SEY kalmazdi.
    const kaynak = readFileSync("app/login/page.tsx", "utf8");
    expect(kaynak).not.toContain("fetch(");
    expect(kaynak).not.toContain("proxyJson");
  });

  it("API kapaliyken giris denemesi 'Giris basarisiz' DEMEZ", async () => {
    // EN PAHALI YANLIS METIN: "Giris basarisiz" YANLIS PAROLA demektir.
    // Kullanici parolasini defalarca dener, kilitlenir ve asil sorunu —
    // sunucunun kapali oldugunu — hic ogrenmez.
    //
    // BFF artik 503 + `sunucuya_ulasilamiyor` donduruyor ve form sunucudan
    // gelen METNI gosteriyor.
    const { GirisFormu } = await import("@/components/GirisFormu");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 503,
        json: async () => ({
          error: {
            code: "sunucuya_ulasilamiyor",
            message: "Sunucuya ulaşılamadı",
          },
        }),
      } as unknown as Response),
    );

    ciz(() =>
      React.createElement(GirisFormu, { yuzey: "tesis" } as never),
    );

    await userEvent.type(
      screen.getByLabelText(/Telefon/i),
      "05551112233",
    );
    // `getByLabelText` COKLU eslesme veriyor (goz dugmesinin de etiketi
    // parolaya atifta bulunuyor); alanin kendisi `id` ile hedefleniyor.
    const parola = document.getElementById("yz-parola") as HTMLInputElement;
    await userEvent.type(parola, "Parola1234");
    await userEvent.click(screen.getByRole("button", { name: /Giriş yap/i }));

    await waitFor(() =>
      expect(screen.getByText(/Sunucuya ulaşılamadı/)).toBeTruthy(),
    );
    expect(screen.queryByText(/Giriş başarısız/)).toBeNull();
  });
});

describe("admin-web saglik ucu", () => {
  it("API kapaliyken bile 200 doner ve durumu RAPOR eder", async () => {
    // 503 dondurseydi orkestratör konteyneri sagliksiz sayar, yeniden
    // baslatir ve yuk dengeleyiciden duserdi — yani API kapali diye
    // PANELI de kapatirdik. Bu turda duzeltilen kusurun tam kendisi.
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("ECONNREFUSED")));
    const { GET } = await import("@/app/api/saglik/route");

    const yanit = await GET();
    expect(yanit.status).toBe(200);
    const govde = (await yanit.json()) as { status: string; api: string };
    expect(govde.status).toBe("ok");
    expect(govde.api).toBe("erisilemiyor");
  });

  it("API ayaktayken erisilebilir bildirir", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 200 } as unknown as Response),
    );
    const { GET } = await import("@/app/api/saglik/route");

    const govde = (await (await GET()).json()) as { api: string };
    expect(govde.api).toBe("erisilebilir");
  });
});
