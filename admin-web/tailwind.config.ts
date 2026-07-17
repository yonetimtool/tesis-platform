import type { Config } from "tailwindcss";

// Yönetio tasarim sistemi (Faz 1). Marka: navy #1E3A5F → teal #0E9594.
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
      colors: {
        ink: "#0f172a",
        muted: "#64748b",
        brand: {
          navy: "#1E3A5F",
          teal: "#0E9594",
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
      },
      boxShadow: {
        // Yumusak, katmanli golgeler (sert dusum yok) — navy tonlu.
        soft: "0 1px 2px rgba(15, 23, 42, 0.04), 0 1px 3px rgba(15, 23, 42, 0.06)",
        card: "0 1px 2px rgba(15, 23, 42, 0.04), 0 4px 12px -2px rgba(15, 23, 42, 0.08)",
        lift: "0 4px 10px -2px rgba(15, 23, 42, 0.08), 0 14px 28px -6px rgba(14, 149, 148, 0.16)",
        panel: "0 20px 60px -20px rgba(30, 58, 95, 0.45)",
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
