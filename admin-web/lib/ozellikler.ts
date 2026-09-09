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
}

export function useDukkanAcik(): boolean {
  const { data } = useSWR<OzellikBayraklari>("/api/ozellikler", jsonFetcher);
  // `data?.dukkan === true`: yukleme (undefined), hata (undefined) ve
  // beklenmedik tip — hepsi KAPALI.
  return data?.dukkan === true;
}
