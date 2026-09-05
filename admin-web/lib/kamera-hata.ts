// (P215) CANLI YAYIN HATASI — KAMERA SORUNU MU, SUNUCU YAPILANDIRMASI MI?
//
// ===========================================================================
// OLCULEN KUSUR (sahadan)
// ===========================================================================
// Prod'da `mediamtx` ile `api` FARKLI docker aglarindaydi ve her canli
// yayin istegi 502 donuyordu. Kullanicinin gordugu tek sey su idi:
//     "Yayin acilamadi. Adresi ve ag erisimini kontrol edin."
// Yani yonetici HICBIR SORUNU OLMAYAN kamerayi duzeltmeye calisti. Sunucu
// tanili bir mesaj DONDURUYORDU ("gecide ulasilamiyor") ama oynatici onu
// HIC OKUMUYORDU: hls.js'in olumcul hatasini sabit bir metne ceviriyordu.
//
// ===========================================================================
// AYRIM `code` ILE, METINLE DEGIL
// ===========================================================================
// Mesaj metnine bakmak dil degisince sessizce kirilir. Sunucu ayrimi
// makine okunur yapiyor (backend `SUNUCU_YAPILANDIRMA`):
//     server_config -> SUNUCUDA ag/port/yapilandirma. Kameraya DOKUNMA.
//     digerleri     -> KAMERAYA ulasilamiyor: adres, kimlik, ag izni.
export type YayinHataSinifi = "sunucu" | "kamera";

/** Sunucu kaynakli oldugu KESIN olan kodlar (backend ile TEK KAYNAK). */
const SUNUCU_KODLARI = new Set(["server_config"]);

export function hataSinifi(kod: string | null | undefined): YayinHataSinifi {
  return kod && SUNUCU_KODLARI.has(kod) ? "sunucu" : "kamera";
}

/** Sunucunun TANILI mesajini ogrenmek icin playlist'i BIR KEZ ceker.
 *
 * NEDEN AYRI ISTEK: hls.js hata nesnesinde yanit GOVDESINI vermiyor
 * (yalnizca durum kodu). Tanili metin govdede; onu almadan kullaniciya
 * "adresinizi kontrol edin" demek, yanlis yere bakmasini soylemekti.
 *
 * Basarisiz olursa `null` doner ve cagiran genel metne duser — teshis
 * denemesi, oynatmayi bozan bir sey OLMAMALI.
 */
export async function yayinHatasiniCoz(
  url: string,
): Promise<{ sinif: YayinHataSinifi; mesaj: string } | null> {
  try {
    const yanit = await fetch(url, { cache: "no-store" });
    if (yanit.ok) return null; // hata gecici olabilir; susmak dogru
    const govde = (await yanit.json()) as
      | { error?: { code?: string; message?: string } }
      | undefined;
    const kod = govde?.error?.code;
    const mesaj = govde?.error?.message;
    if (!mesaj) return null;
    return { sinif: hataSinifi(kod), mesaj };
  } catch {
    return null;
  }
}
