"use client";

import useSWR from "swr";

import { jsonFetcher } from "@/lib/fetcher";

/**
 * (P221) SUNUCUDAN GELEN OZELLIK BAYRAKLARI — web.
 *
 * =========================================================================
 * MOBILLE AYNI KURAL
 * =========================================================================
 * Bayrak SUNUCUDA; acmak icin yeni bir dagitim degil tek bir ortam
 * degiskeni yetiyor. VARSAYILAN KAPALI: ag hatasi, eski sunucu ya da
 * bozuk govde — hepsinde `false`.
 *
 * "Bilmiyorsak acalim" demek, hazir olmayan bir yuzeyi kullaniciya
 * gostermek olurdu.
 */
export interface OzellikBayraklari {
  dukkan: boolean;
  /** (P253 A2) Kendi karo dosyamiz (PMTiles); null = harita kapali. */
  harita_karo_url?: string | null;
}

/** (P253 A2) Harita karo adresi — sunucudan; yoksa null (harita cizilmez). */
export function useKaroUrl(): string | null {
  const { data } = useSWR<OzellikBayraklari>("/api/ozellikler", jsonFetcher);
  return typeof data?.harita_karo_url === "string" && data.harita_karo_url ? data.harita_karo_url : null;
}

export function useDukkanAcik(): boolean {
  const { data } = useSWR<OzellikBayraklari>("/api/ozellikler", jsonFetcher);
  // `data?.dukkan === true`: yukleme (undefined), hata (undefined) ve
  // beklenmedik tip — hepsi KAPALI.
  return data?.dukkan === true;
}
