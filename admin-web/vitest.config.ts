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
  },
  resolve: {
    // tsconfig'deki "@/*" -> proje koku takma adi.
    alias: { "@": new URL("./", import.meta.url).pathname },
  },
});
