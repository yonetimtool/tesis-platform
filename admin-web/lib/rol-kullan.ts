"use client";

/**
 * (P166 §2) AKTIF ROL — tek kaynak, tek istek.
 *
 * Kenar cubugu bu cozumu P126.7'den beri kendi icinde tasiyordu: sunucudan
 * gelen `rol` (duzen, cerezden cozdu) BASLANGIC degeridir; access cerezi
 * dusmusse `null` gelir ve `/api/me` devreye girer.
 *
 * Sayfa aramasi da AYNI rolu bilmek zorunda (arama, menude gorunmeyen bir
 * sayfayi gostermemeli). Ayni mantigi ikinci kez yazmak, iki yerin
 * ayrisabilmesi demekti — o yuzden cikarildi.
 *
 * IKI ISTEK DEGIL TEK ISTEK: SWR anahtari `"/api/me"` ve onbellek anahtar
 * basina paylasilir; kenar cubugu ile arama ayni yaniti okur.
 */
import useSWR from "swr";

import { jsonFetcher } from "./fetcher";

export function useRol(rolBaslangic: string | null): string | null {
  const { data } = useSWR<{ role?: string }>(
    rolBaslangic ? null : "/api/me",
    jsonFetcher,
  );
  return rolBaslangic ?? data?.role ?? null;
}
