import type { Config } from "tailwindcss";

// ==========================================================================
// (P177 §7) TANITIM SITESI TASARIM DILI — PANELDEN AYRI, BILINCLI OLARAK.
// ==========================================================================
// Panel (`admin-web`) P160-P176 boyunca metalik/neumorphic bir dile
// oturdu: katmanli golgeler, ic-golge kabartmalar, koyu tema. O dil
// CALISMA ALANI icindir — gunde saatlerce bakilan bir arayuz.
//
// Tanitim sitesi bir KARSILAMA yuzeyidir ve isi baskadir: ziyaretci
// saniyeler icinde "bu ne, ben hangi kapidan girerim" sorusunu
// yanitlamali. Bu yuzden burada golge YOK, kabartma YOK, koyu tema YOK;
// duz zeminler, 1 px kenarlik ve tipografi tasiyor.
//
// IKI DIL BIRBIRINE TASINMAZ. Panelin token'lari buraya kopyalanmadi ve
// buradakiler panele goturulmeyecek; ikisi ayri paketler, ayri
// `tailwind.config.ts`ler.
//
// RENKLER LOGODAN ORNEKLENDI (bkz. docs/P177-kararlar.md): olculen iki
// aile — mavi #2C65AC ve lacivert #0D2352. Sartnamenin verdigi
// #2060A0 / #102060 / #EAF1FA bu olcumun yuvarlatilmis hâlidir ve
// KANONIK kabul edildi; olculen tonlar gradyan duraklarinda yasiyor.
//
// KONTRAST: her metin/zemin cifti olculdu, hepsi WCAG AA (>=4.5) —
// degerler kararlar belgesinde. Form denetimlerinin kenarligi ayri bir
// ton (`--cizgi-denetim`) cunku 1.4.11 denetim sinirlari icin 3:1 ister
// ve dekoratif kart kenarligi (#CFDDEF, 1.38) bunu tutmuyor.
const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
    "./config/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Zeminler
        zemin: "#EAF1FA",       // sayfa zemini (sartname)
        kart: "#FFFFFF",
        zeminKoyu: "#102060",   // koyu bolum zemini
        // Marka
        lacivert: "#102060",
        mavi: "#2060A0",
        maviKoyu: "#1A4E85",    // hover/basili
        maviAcik: "#B9D4F0",    // koyu zeminde metin (olculdu 9.83)
        // Metin
        baslik: "#102060",
        govde: "#34435F",       // 8.73 zeminde
        soluk: "#4A5A78",       // 6.10 zeminde
        // Cizgiler
        cizgi: "#CFDDEF",       // DEKORATIF (kart/bolum ayraci)
        cizgiDenetim: "#6E88AB",// FORM DENETIMI (3.64 beyazda — 1.4.11)
        // Tek vurgu — YALNIZ "ucretsiz" rozetinde. Ikinci bir kullanim
        // yeri acilirsa once burasi tartisilmali: tek vurgu, tek anlam.
        yesil: "#0E6E4E",
        yesilZemin: "#E3F4EC",
        hata: "#A3122B",
        hataZemin: "#FBE9EC",
      },
      fontFamily: {
        // TEK AILE: Inter (yerel, P175'ten). Ikinci bir yazi tipi
        // eklemek dis bir dosya indirmek ya da depoya yeni bir font
        // koymak demekti; sartname aga bagimlilik yasakliyor.
        // KISILIK MUAMELEDEN gelir: ekranda 800 agirlik + siki harf
        // araligi (baslik), 700 + genis aralikli versal (etiket).
        sans: ["Inter", "Inter Yedek", "system-ui", "sans-serif"],
      },
      fontSize: {
        etiket: ["0.75rem", { lineHeight: "1", fontWeight: "700", letterSpacing: "0.16em" }],
        dev: ["clamp(2.25rem, 7vw, 4.25rem)", { lineHeight: "1.0", fontWeight: "800", letterSpacing: "-0.035em" }],
        bolum: ["clamp(1.625rem, 3.6vw, 2.5rem)", { lineHeight: "1.1", fontWeight: "800", letterSpacing: "-0.03em" }],
        kartbaslik: ["1.125rem", { lineHeight: "1.35", fontWeight: "700", letterSpacing: "-0.01em" }],
        govde: ["1rem", { lineHeight: "1.65" }],
        kucuk: ["0.875rem", { lineHeight: "1.6" }],
      },
      borderRadius: { blok: "18px", kart: "14px", chip: "999px" },
      maxWidth: { icerik: "1180px", metin: "68ch" },
      spacing: { bolum: "clamp(4rem, 9vw, 7rem)" },
    },
  },
  plugins: [],
};

export default config;
