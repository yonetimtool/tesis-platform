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

const Plan = dynamic(() => import("./plan-haritasi"), {
  ssr: false,
  loading: () => <Iskelet className="h-full w-full" />,
});

export function PlanHaritasiYukleyici(props: PlanHaritasiProps) {
  return <Plan {...props} />;
}
