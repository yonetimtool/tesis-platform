"use client";

import { useEffect, useState } from "react";

/**
 * (P220 §3) Bir degeri GECIKMELI yansitir (debounce).
 *
 * =========================================================================
 * NEDEN GEREKLI
 * =========================================================================
 * Bildirim aramasi SUNUCUDA yapiliyor (istemcide filtrelemek yalniz acik
 * sayfayi suzerdi — kullanici 3. sayfadaki kaydi bulamazdi). Her tusa
 * basista istek atmak iki soruna yol acardi:
 *
 *   * gereksiz yuk: "kargo" yazmak bes istek demek,
 *   * TITREYEN LISTE: her yanit geldiginde liste yeniden ciziliyor ve
 *     kullanici yazarken ekran altinda kayiyor.
 *
 * Gecikme, yazmayi BITIRMESINI bekliyor.
 *
 * `deger` degistiginde onceki zamanlayici IPTAL edilir; boylece hizli
 * yazan kullanici icin yalniz SON deger sunucuya gider.
 */
export function useGecikmeli<T>(deger: T, ms = 300): T {
  const [gecikmeli, setGecikmeli] = useState(deger);
  useEffect(() => {
    const z = setTimeout(() => setGecikmeli(deger), ms);
    return () => clearTimeout(z);
  }, [deger, ms]);
  return gecikmeli;
}
