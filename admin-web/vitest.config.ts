import { defineConfig } from "vitest/config";

// Panelin BIRIM testleri: saf mantik (lib/) + middleware + (P43) React
// BILESEN testleri.
//
// (P43) IKI ORTAM, TEK KOSUM: saf mantik ve middleware `node` ortaminda
// kalir (hizli ve jsdom'un yan etkilerinden bagimsiz); `*.dom.test.tsx`
// dosyalari DOSYA BASINDAKI `@vitest-environment jsdom` yorumuyla jsdom'a
// gecer. Ortam secimi dosyanin KENDISINDE durur: merkezi bir glob listesi,
// yeni bir dosya eklenip listeye yazilmadiginda testin sessizce YANLIS
// ortamda kosmasi demekti (ve o hata "document is not defined" olarak
// baska bir yerde patlardi). Hepsini jsdom'a almak, `next/server`
// kullanan middleware testini gereksizce tarayici taklidine sokardi;
// hepsini node'da birakmak ise sayfa testini IMKANSIZ kilardi — envanterin
// "panel UI birim kapsami %26,8" maddesi tam olarak bu kararin
// ertelenmesinden dogmustu.
export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    setupFiles: ["tests/kurulum.ts"],
    // Next derlemesi ve uretilen tipler test kapsamina girmesin.
    exclude: ["node_modules/**", ".next/**"],
    // TUR 68 — KAPSAM PAYDASI.
    //
    // Eski v8 varsayilani YALNIZ testlerin IMPORT ETTIGI dosyalari sayiyordu;
    // bu yuzden rapor "%95,7" gosteriyordu ama paydasi 211 satirdi: yalniz
    // `lib/`. Panelin ASIL kodu (26 sayfa + bilesenler) hic sayilmiyordu ve
    // "kapsam yuksek" izlenimi veriyordu. Payda, asagidaki `include`
    // desenleriyle TUM kaynak dosyalari kapsar; boylece birim testlerin
    // gercekte nereye dokundugu gorulur (UI'yi Playwright surusleri kapsiyor,
    // birim testler kapsamiyor).
    //
    // Bu paydayi eskiden `all: true` sagliyordu. O SECENEK ARTIK YOK: Vitest
    // (kurulu surum 4.1.10) `include` ile eslesen her dosyayi paydaya koymayi
    // VARSAYILAN yaptigi icin `all`i kaldirdi ve `CoverageOptions` tipinde
    // artik tanimli degil. Satir kaldirildi cunku `next build` (Docker prod
    // derlemesinin kostugu komut) bu dosyayi da tip denetiminden geciriyor ve
    // "'all' does not exist in type 'CoverageOptions'" ile PATLIYORDU.
    // Payda korundu, olculdu: 724 ifade / 620 satir (kaldirma oncesi ve
    // sonrasi AYNI).
    coverage: {
      provider: "v8",
      include: ["app/**/*.{ts,tsx}", "components/**/*.{ts,tsx}", "lib/**/*.{ts,tsx}"],
      exclude: ["**/*.d.ts", "app/**/layout.tsx", "app/**/loading.tsx"],
      reporter: ["text-summary"],
    },
  },
  // (P43) JSX YOK — ve bu BILINCLI.
  //
  // Bilesen testleri once `.tsx` yazildi; Vitest 4 (rolldown) JSX'i
  // ayristirmadi ve `@vitejs/plugin-react` gerekti. Eklenti kuruldugunda
  // `next build` PATLADI: eklentinin `.d.ts` dosyasi bu depodaki
  // TypeScript surumunun ayristiramadigi bir sozdizimi kullaniyor
  // (`as "module.exports"`), tsconfig `**/*.ts` ile vitest.config.ts'i de
  // denetledigi icin hata URUN DERLEMESINE tasindi.
  //
  // Karar: test bagimliligi urun derlemesini KIRAMAZ. Testler JSX yerine
  // `createElement` kullanir; eklenti ve `vite` bagimliligi kaldirildi.
  //
  // SAYFALARIN KENDISI yine `.tsx`tir ve donusturulmesi gerekir: tsconfig
  // `jsx: "preserve"` (Next kendi derleyicisini kullanir) oldugu icin
  // Vitest'e ACIKCA soylenir. Bu ayar YALNIZ test kosumunu etkiler; urun
  // derlemesi Next'in kendi ayarindan gecer.
  // Vitest 4 rolldown/oxc kullanir; `esbuild` anahtari YOK SAYILIR.
  oxc: { jsx: { runtime: "automatic", importSource: "react" } },
  resolve: {
    // tsconfig'deki "@/*" -> proje koku takma adi.
    alias: { "@": new URL("./", import.meta.url).pathname },
  },
});
