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
import { webRolu, type RolDurumu } from "./rol-gecisi";

/** (P247 §2) `GET /me` vekili — aktif rol + gecilebilecek roller. */
export const ROL_DURUMU_UC = "/api/me/rol-gecis";

export function useRol(rolBaslangic: string | null): string | null {
  const { data } = useSWR<{ role?: string }>(
    rolBaslangic ? null : "/api/me",
    jsonFetcher,
  );
  // (P247 §2) `resident` IKI ANLAMA GELEBILIR: saf sakin ya da yoneticinin
  // SAKIN MODU. Profil yaniti asil rolu tasimaz; ayrim `GET /me`nin
  // `roller` alanindan yapilir. Ayrim gelene kadar `null` (hicbir sey
  // cizilmez) — "bilmiyorsak gosterelim" demek, bir kare icin yanlis
  // menu cizmek olurdu.
  const belirsiz = !rolBaslangic && data?.role === "resident";
  const { data: durum } = useSWR<RolDurumu>(
    belirsiz ? ROL_DURUMU_UC : null,
    jsonFetcher,
  );
  if (rolBaslangic) return rolBaslangic;
  if (belirsiz) return durum ? webRolu(durum) : null;
  return data?.role ?? null;
}
