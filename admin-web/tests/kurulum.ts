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
