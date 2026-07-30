import { defineConfig } from "vitest/config";

// Panelin BIRIM testleri: saf mantik (lib/) + middleware yonlendirmesi.
// React/sayfa testleri BU TURUN DISINDA (jsdom + Testing Library gerektirir);
// bu yuzden ortam "node" ve ek bagimlilik yok. `window`a dokunan modullerde
// (fetcher/client) global test icinde stub'lanir.
export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
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
  resolve: {
    // tsconfig'deki "@/*" -> proje koku takma adi.
    alias: { "@": new URL("./", import.meta.url).pathname },
  },
});
