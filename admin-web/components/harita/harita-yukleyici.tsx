"use client";

/**
 * (P160) HARITA SARMALAYICISI — tembel yukleme.
 *
 * `leaflet` + `react-leaflet` birlikte ~150 kB ve Leaflet SUNUCUDA
 * CALISMAZ: modul yuklenirken `window` arar. `next/dynamic` + `ssr:false`
 * zorunlu, ve bu karar sahnenin DISINDA verilmeli — ayni dosyada olsaydi
 * modul zaten yuklenmis olurdu (3D yukleyicideki ayrimin aynisi).
 *
 * WEBGL KONTROLU YOK ve gerekmiyor: Leaflet DOM/canvas ile cizer, 3D
 * sahnelerin aksine ozel bir cihaz destegi istemez.
 */
import dynamic from "next/dynamic";

import { Iskelet } from "../ui/durumlar";
import type { PlanHaritasiProps } from "./plan-haritasi";
import type { KonumHaritasiProps } from "./konum-haritasi";

const Plan = dynamic(() => import("./plan-haritasi"), {
  ssr: false,
  loading: () => <Iskelet className="h-full w-full" />,
});

// IKINCI HARITA, AYNI DOSYA — 3D yukleyicisindeki karar. Iki ayri
// yukleyici dosyasi, ayni `ssr:false` kuralini iki yerde tutmak olurdu.
const Konum = dynamic(() => import("./konum-haritasi"), {
  ssr: false,
  loading: () => <Iskelet className="h-full w-full" />,
});

export function PlanHaritasiYukleyici(props: PlanHaritasiProps) {
  return <Plan {...props} />;
}

/** COGRAFI harita (OSM karolari) — bkz. `konum-haritasi.tsx` dosya basi. */
export function KonumHaritasiYukleyici(props: KonumHaritasiProps) {
  return <Konum {...props} />;
}
