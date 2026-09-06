import type { Config } from "tailwindcss";

/**
 * ==========================================================================
 * DUKKAN TASARIM DILI
 * ==========================================================================
 * Bu yuzeyin isi `tanitim-web` ile ayni sinifta: ZIYARETCI karsilama.
 * Panel (`admin-web`) metalik/koyu bir calisma alani dili kullanir; o dil
 * gunde saatlerce bakilan bir arayuz icindir ve buraya TASINMAZ.
 *
 * armut.com'un URUN KALIBI aliniyor (ihtiyaci anlat -> teklif al ->
 * karsilastir; kategori izgarasi; bolge sayfalari) ama GORSEL DILI
 * alinmiyor: marka varliklari hukuken korunuyor ve birebir CSS kopyasi
 * mevcut test kilitlerini kirar. Renkler Yonetio ailesinden.
 */
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        marka: {
          DEFAULT: "#2060A0",
          koyu: "#102060",
          acik: "#EAF1FA",
        },
        vurgu: "#0F9D8F",
      },
    },
  },
  plugins: [],
};

export default config;
