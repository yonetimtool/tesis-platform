import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P244 §5) HAVA DURUMU — BFF ROTASI EKLENDI.
 *
 * =========================================================================
 * OLCULEN EKSIK
 * =========================================================================
 * Sunucuda `GET /weather` P233'ten beri VAR ve MOBIL onu kullaniyor
 * (`weatherProvider`), ama WEB'de karsilik gelen BFF rotasi HIC YOKTU —
 * yani panel hava durumunu isteyemiyordu bile. Bu, depoda kayitli bir
 * kusur SINIFI (P173/P189: "BFF eksik-rota"): sunucu ucu calisiyor,
 * web'in kapisi yok ve eksiklik yalniz o ekran yazilinca fark ediliyor.
 *
 * =========================================================================
 * 503 BIR HATA DEGIL, BIR DURUM
 * =========================================================================
 * Konum ayarlanmamissa ya da dis servis dusukse uc 503
 * `weather_unavailable` doner. Kahraman bandi bunu SESSIZCE yutar ve hava
 * blogunu CIZMEZ — bir karsilama satirini "hava alinamadi" hatasiyla
 * bolmek, kullaniciya yapabilecegi hicbir sey olmayan bir sorun
 * gostermek olurdu.
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/weather", "GET");
}
