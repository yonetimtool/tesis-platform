import { defineConfig } from "vitest/config";

/**
 * DOM YOK ve bu bilincli: bu paketteki testler SAF MANTIK ve KAYNAK
 * TARAMASIDIR (fiyat hesabi, bos-mesaj kurali, dis istek yasagi, hukuki
 * metin esitligi). React bilesenlerini jsdom altinda kosmak, panelde
 * zaten kurulu olan bir alt yapiyi (testing-library + jsdom + kurulum
 * dosyalari) ikinci kez kurmak olurdu; karsiliginda buradaki dort
 * kuralin hicbiri daha iyi dogrulanmazdi.
 */
export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
  },
  // `tsconfig.json` `jsx: "preserve"` der (Next kendi derleyicisini
  // kullanir). Vitest'e ACIKCA soylenmezse `.tsx` kaynagi ayristirilamaz.
  // Vitest 4 rolldown/oxc uzerinde kosar; `esbuild` anahtari YOK SAYILIR —
  // panelin `vitest.config.ts`inde ayni tuzak yazili.
  oxc: { jsx: { runtime: "automatic", importSource: "react" } },
  resolve: {
    alias: { "@": new URL("./", import.meta.url).pathname },
  },
});
