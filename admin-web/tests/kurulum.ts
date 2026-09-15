// (P43) Test kurulumu — HER IKI ORTAMDA da yuklenir.
//
// `@testing-library/jest-dom` matcher'lari yalniz jsdom'da anlamlidir ama
// import edilmesi node ortaminda da zararsizdir; ortam basina AYRI kurulum
// dosyasi tutmak, birinde eklenen bir ayarin digerinde unutulmasi demekti.
import "@testing-library/jest-dom/vitest";

import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// TEMIZLIK ZORUNLU: RTL'in otomatik temizligi yalniz `globals: true` ile
// devreye girer; bu depo `globals` KULLANMIYOR (testler import ediyor).
// Temizlik olmadan ikinci test birinci testin DOM'unu de gorur ve
// "Found multiple elements" ile duser — yani hata testin kendisinde degil
// KURULUMDA olurdu. Node ortaminda `cleanup` zararsizca no-op'tur.
afterEach(() => {
  cleanup();
});

// (P52) `matchMedia` jsdom'da YOKTUR ve tema anahtari onu `useEffect`
// icinde cagirir: kabugu (AppShell) cizen her test, urun kodunda hicbir
// sorun olmadigi halde duserdi. Varsayilan ACIK TEMA ("dark" eslesmiyor)
// — testin gordugu tema, testin konusu degildir.
if (typeof window !== "undefined" && !window.matchMedia) {
  window.matchMedia = ((sorgu: string) => ({
    matches: false,
    media: sorgu,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  })) as typeof window.matchMedia;
}

// (P132.5) REACT DISI METIN COZUCUSU icin AKTIF SOZLUK.
//
// Uretimde `I18nProvider` ilk cizimde sozlugu `lib/i18n/metin`e yayinlar
// (yedi sozlugun istemci paketine girmemesi icin — olculen kazanc rota
// basina ~122 KB). Testlerde saglayici HER ZAMAN olmaz: `client.ts` ve
// `fetcher.ts` testleri React'siz kosar ve hata METNINI olcer. Kurulum,
// uretimdeki "ilk cizim olmus" durumunu taklit eder.
import { aktifSozluguAyarla } from "@/lib/i18n/metin";
import { SOZLUKLER } from "@/lib/i18n/sozluk";

aktifSozluguAyarla(SOZLUKLER.tr);

// (P237 §3) `ResizeObserver` KUKLASI — jsdom onu HIC tanimlamiyor.
//
// OLCULEN KUSUR: anket sonuc panosu `Grafik`i (recharts) cizince
// `ReferenceError: ResizeObserver is not defined` firliyor ve hata TESTIN
// ICINDE degil, dinamik parca yuklendikten SONRA atildigi icin test
// "beklenmedik bos DOM" olarak dusuyordu. Grafik cizen HER sayfa testi
// bu duvara carpardi.
//
// Kukla OLCMEZ, SUSTURMAZ: yalnizca tarayicida var olan bir arayuzu
// jsdom'da VAR EDER. Genislik olcumune dayanan bir sey test etmiyoruz
// (jsdom zaten yerlesim hesaplamaz — P236'nin merkezi dersi).
if (typeof globalThis.ResizeObserver === "undefined") {
  globalThis.ResizeObserver = class {
    observe(): void {}
    unobserve(): void {}
    disconnect(): void {}
  } as unknown as typeof ResizeObserver;
}
