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
    // Varsayilan olarak v8 yalniz testlerin IMPORT ETTIGI dosyalari sayar; bu
    // yuzden rapor "%95,7" gosteriyordu ama paydasi 211 satirdi: yalniz
    // `lib/`. Panelin ASIL kodu (26 sayfa + bilesenler) hic sayilmiyordu ve
    // "kapsam yuksek" izlenimi veriyordu. `all: true` ile TUM kaynak dosyalar
    // paydaya girer; boylece birim testlerin gercekte nereye dokundugu
    // gorulur (UI'yi Playwright surusleri kapsiyor, birim testler kapsamiyor).
    coverage: {
      provider: "v8",
      all: true,
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
