import type { Config } from "tailwindcss";

// Yönetiyor tasarim sistemi (Faz 1). Marka: navy #1E3A5F → teal #0E9594.
// Koyu mod merkezi olarak globals.css'te notrr Tailwind siniflarini yeniden
// esleyerek yonetilir (mevcut sistem korunur); burada MARKA + golge + hareket
// token'lari eklenir.
const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      // ====================================================================
      // (P169 §1) KIRILMA NOKTALARI — TEK SISTEM
      // ====================================================================
      // Brief dort bant istiyor:
      //   sm  <640      telefon
      //   md  640-1023  tablet dikey
      //   lg  1024-1439 tablet yatay / kucuk dizustu
      //   xl  >=1440    masaustu
      //
      // OLCULDU: bu sinirlarin UCUNDEN IKISI Tailwind'de ZATEN DOGRU.
      // `sm`=640 ve `lg`=1024 brief'in sinirlariyla BIREBIR ayni; yalniz
      // `xl` 1280 ve brief 1440 istiyor.
      //
      // PARALEL BIR SISTEM KURULMADI (`tel/tabD/tabY/mas` gibi yeni adlar).
      // Sebep olculebilir: kod tabaninda 84 `sm:`, 36 `lg:`, 10 `md:`
      // kullanimi var. Ikinci bir sozluk eklemek, ayni ekranda iki farkli
      // kirilma dilinin yan yana yasamasi ve her okuyanin "bu hangi
      // sistem" diye durmasi olurdu.
      //
      // `md` (768) BRIEF'IN BIR SINIRI DEGIL — brief'in "md bandi"
      // 640-1023'tur ve Tailwind'de bu zaten `sm:` ile baslayip `lg:`de
      // biten banttir. 768 fazladan bir ara esik olarak KALIYOR: on
      // kullanim yeri var ve hepsi tablo kolonu gizleme gibi ince
      // ayarlar.
      screens: {
        // (P169 §5) `coarse:` — PARMAKLA kullanilirken. Genislikten AYRI
        // bir soru: dokunmatik bir dizustu genistir ama fare yoktur.
        // Hover'a bagli kalan seritleri dokunmatikte ACIK cizmek icin.
        coarse: { raw: "(pointer: coarse)" },
        // TEK DEGISIKLIK: 1280 -> 1440. Tek kullanim yeri var
        // (`finans-ozeti` kart izgarasi) ve orada uc kolona GEC gecmek
        // dogru: 1280'de uc para karti yan yana sikisiyordu.
        xl: "1440px",
      },
      colors: {
        ink: "#0f172a",
        // (P132.8) `muted` KALDIRILDI. Acik temada `metin.muted` ile AYNI
        // degerdeydi (#6B7280) ama koyu temasi ayrisimisti (#94a3b8, mobil
        // kaynak #9CA3AF diyor) — yani ayni rol, iki ad, iki davranis.
        // 110 kullanim `text-metin-muted`e gecirildi; ad burada birakilsaydi
        // ayrisma sessizce geri gelirdi.
        // ------------------------------------------------------------------
        // (P132) MOBIL TASARIM SISTEMI — kaynak: mobile/lib/src/core/theme/
        // home_tokens.dart. Degerler ELLE UYDURULMADI, oradan kopyalandi;
        // ikisi ayrisirsa `tests/tasarim-token.test.ts` duser (Dart dosyasini
        // okuyup karsilastirir).
        //
        // NEDEN MOBIL KAYNAK: onaylanmis tasarim odur ve iki urunun ayni
        // gorunmesi istendi. Web'in eski navy/teal accent'i MARKA olarak
        // kalir (logo, giris ekrani gradyani); ETKILESIM rengi artik mavi.
        // Iki farkli vurgu rengi, tam olarak sikayet edilen "yarim kalmis"
        // hissini uretiyordu.
        // ------------------------------------------------------------------
        // Vurgu paleti — TEMA BAGIMSIZ (anlam tasir: yesil=olumlu,
        // kirmizi=ihlal). Metin kullanimi icin koyu temada `.dark`
        // karsiliklari globals.css'te degiskenle cozulur.
        primary: "#2563EB",
        accent: {
          blue: "#2563EB",
          green: "#16A34A",
          orange: "#F59E0B",
          purple: "#8B5CF6",
          red: "#EF4444",
        },
        // (P132.6) VURGUNUN "OKUNUR" HÂLI — YALNIZ METIN icin.
        //
        // Kontrast testi kusuru yakaladi: %12 tint zemin uzerinde HAM vurgu
        // metin olarak AA'yi TUTMUYOR (olculdu: blue 4.37 · green 2.89 ·
        // orange 1.96 · purple 3.64 · red 3.23). Mobilde bunun karsiligi
        // `okunurVurgu()` fonksiyonudur (acik tema: L -0.22, 0.24-0.34
        // bandi, S x1.05); web'de ayni donusum ONCEDEN hesaplanip token
        // olarak durur — calisma aninda renk hesaplamak, her cizimde ayni
        // sonucu yeniden uretmek olurdu.
        //
        // TON KORUNUR: yesil=olumlu / kirmizi=ihlal anlami bozulmaz.
        // DOLGU ve IKON HAM RENKTE kalir; sorun yalniz METINDEDIR.
        // Tint zemindeki olculen degerler: 8.96 / 5.59 / 5.32 / 10.32 / 6.91.
        vurguInk: {
          blue: "#0A3696",
          green: "#0C6E30",
          orange: "#8D5A02",
          purple: "#3705A8",
          red: "#A30A0A",
        },
        // Yuzey/metin — acik tema degerleri; koyu tema globals.css'te
        // ayni degisken adlariyla yeniden tanimlanir (tek yer).
        yuzey: {
          // (P166 §7.2) Mobil `home_tokens.dart` ile AYNI — parite testi
          // ikisini kilitliyor. Zemin koyulasti ki beyaz kart AYRISSIN.
          bg: "#EAEEF5",
          card: "#FFFFFF",
          divider: "#E4E9F1",
          placeholder: "#E5E7EB",
        },
        metin: {
          heading: "#111827",
          body: "#374151",
          // (P166 §7.2) Zemin koyulastigi icin yeniden olculdu (eski
          // #6B7280 yeni zeminde 4.15 ile AA altina duserdi).
          muted: "#626976",
          // (P132.6) IKINCIL METIN SAYFA ZEMININDE. Kontrast testi olctu:
          // #6B7280 beyaz KART uzerinde 4.83 (gecer) ama sayfa zemininde
          // (#F4F6FA) 4.47 — esigin ALTINDA. Ayni token'i iki yuzeyde
          // kullanmak, sayfa zeminindeki her ikincil satiri esigin altina
          // dusuruyordu. Bu ton sayfa zemini icindir: 4.91.
          mutedBg: "#636C7A",
        },
        brand: {
          navy: "#1E3A5F",
          // MARKA teali (gradyan/dolgu). Metin ve dugme zemini icin
          // KULLANILMAZ: beyazla kontrasti 3.66, acik teal zeminle 3.25 —
          // ikisi de WCAG AA esigi 4.5'in ALTINDA (tur 30 axe denetimi).
          teal: "#0E9594",
          // Erisilebilir koyu ton: beyazla 5.15, acik teal zeminle 4.58.
          // Dugme zemini ve acik zemindeki METIN bunu kullanir.
          tealInk: "#0B7A79",
          // Koyu zeminde okunur kalan acik teal (accent pop).
          tealLight: "#2CC4B7",
        },
      },
      fontFamily: {
        // Yerel sistem yigini — build-time font indirmesi YOK (guvenli + hizli).
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "Roboto",
          "Helvetica Neue",
          "Arial",
          "sans-serif",
        ],
      },
      borderRadius: {
        // Olcek: 8 / 12 / 16 (Tailwind lg/xl/2xl ile hizali).
        lg: "0.5rem",
        xl: "0.75rem",
        "2xl": "1rem",
        // (P132) Mobil token'lari: kart 16, ikon kutusu 14, chip 8.
        kart: "16px",
        ikon: "14px",
        chip: "8px",
        // (P133) "Tint blok" dili — Kerem'in onayladigi yon: kahraman blok
        // 20px, ikincil bloklar 16px (`kart` ile ayni). Deger mobil
        // kaynaktan DEGIL bu turun onayindan gelir; token testi de bunu
        // ayirt eder (`kart/ikon/chip` mobille karsilastirilir, `blok`
        // karsilastirilmaz).
        blok: "20px",
      },
      spacing: {
        // (P132) Mobil olcu sabitleri — ayni adlarla.
        kart: "16px",      // cardPadding
        bolum: "20px",     // sectionGap
        izgara: "12px",    // gridGap
        ikonkutu: "56px",  // iconBox
        satirikon: "40px", // rowIconBox
      },
      fontSize: {
        // (P132) HomeText olcegi — mobil ile AYNI punto/agirlik.
        selam: ["26px", { lineHeight: "1.15", fontWeight: "700" }],
        bolum: ["18px", { lineHeight: "1.3", fontWeight: "700" }],
        kartbaslik: ["14px", { lineHeight: "1.2", fontWeight: "600" }],
        sayac: ["13px", { lineHeight: "1.3", fontWeight: "500" }],
        satiralt: ["12px", { lineHeight: "1.35", fontWeight: "400" }],
        chip: ["11px", { lineHeight: "1.2", fontWeight: "600", letterSpacing: "0.2px" }],
        deger: ["20px", { lineHeight: "1.1", fontWeight: "700" }],
        etiket: ["13px", { lineHeight: "1.3", fontWeight: "600" }],
        para: ["22px", { lineHeight: "1.15", fontWeight: "700" }],
      },
      boxShadow: {
        // Yumusak, katmanli golgeler (sert dusum yok) — navy tonlu.
        soft: "0 1px 2px rgba(15, 23, 42, 0.04), 0 1px 3px rgba(15, 23, 42, 0.06)",
        card: "0 1px 2px rgba(15, 23, 42, 0.04), 0 4px 12px -2px rgba(15, 23, 42, 0.08)",
        lift: "0 4px 10px -2px rgba(15, 23, 42, 0.08), 0 14px 28px -6px rgba(14, 149, 148, 0.16)",
        panel: "0 20px 60px -20px rgba(30, 58, 95, 0.45)",
        // (P132) Mobil kartlarda GOLGE YOKTUR — 1px %4 siyah kenarlik
        // kullanilir. Web'de de ayni: golge eklemek iki urunu ayristirirdi.
        // Bu token yalniz YUZEN katmanlar icindir (cekmece, acilir menu).
        yuzen: "0 10px 30px -10px rgba(17, 24, 39, 0.25)",
      },
      backgroundImage: {
        "brand-gradient": "linear-gradient(135deg, #1E3A5F 0%, #0E9594 100%)",
      },
      keyframes: {
        // Login panelindeki yumusak orb'lerin yavas suzulmesi (GPU: transform).
        drift: {
          "0%, 100%": { transform: "translate3d(0,0,0) scale(1)" },
          "50%": { transform: "translate3d(24px,-32px,0) scale(1.08)" },
        },
        driftAlt: {
          "0%, 100%": { transform: "translate3d(0,0,0) scale(1)" },
          "50%": { transform: "translate3d(-28px,24px,0) scale(0.94)" },
        },
      },
      animation: {
        drift: "drift 18s ease-in-out infinite",
        driftAlt: "driftAlt 22s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};

export default config;
