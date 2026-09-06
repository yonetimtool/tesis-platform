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


// ===========================================================================
// (P216) KODEK: "YAYIN URETILDI" ile "BU TARAYICI OYNATABILIR" AYRI SEYLER
// ===========================================================================
// MediaMTX `fmp4` varyantiyla H265'i HLS'e KOYABILIYOR (olculdu: playlist
// 200, `CODECS="hvc1.4.10.L63.9e.8"`). Ama oynatma tarayiciya bagli:
// Safari donanim destegiyle oynar, Chrome platform/donanima gore DEGISIR,
// Firefox cogu kurulumda oynatmaz.
//
// KARARI SUNUCU VEREMEZ. "H265 gordum, 502 doneyim" demek Safari
// kullanicisina ve MOBIL uygulamaya da yayini kapatmak olurdu — ikisi de
// oynatabiliyor. Dogru yer istemci: `MediaSource.isTypeSupported` KENDI
// tarayicisinin gercek yanitini verir, tahmin degil.

/** Playlist'in ilk `CODECS="..."` degeri (yoksa null). */
export function playlistKodegi(playlist: string): string | null {
  return /CODECS="([^"]+)"/.exec(playlist)?.[1] ?? null;
}

/** Bu TARAYICI o kodegi oynatabilir mi? Bilinemiyorsa `null`.
 *
 * `null` DENEMEYE IZIN VERIR: MSE yoksa (Safari yerel HLS yolu) ya da
 * kodek dizesi okunamadiysa susup oynatmayi denemek dogrudur — yanlis
 * bir "oynatamazsiniz" mesaji, calisan bir yayini kapatmak olurdu.
 */
export function tarayiciOynatabilirMi(kodek: string | null): boolean | null {
  if (!kodek) return null;
  if (typeof MediaSource === "undefined" || !MediaSource.isTypeSupported) {
    return null;
  }
  return MediaSource.isTypeSupported(`video/mp4; codecs="${kodek}"`);
}

/** Oynatmadan ONCE: playlist'i cek, kodegi oku, bu tarayici oynatabilir mi?
 *
 * NEDEN ONCEDEN: hls.js desteklenmeyen kodekte once yukler, sonra
 * bocalar ve genel bir "ag hatasi" uretir. Kullanicinin gordugu sey
 * "acilamadi" olur ve NEDEN acilmadigini kimse soylemez.
 *
 * Hata durumunda `null` -> cagiran normal yoluna devam eder.
 */
export async function kodekOnKontrolu(
  url: string,
): Promise<{ kodek: string; oynatilir: boolean } | null> {
  try {
    const yanit = await fetch(url, { cache: "no-store" });
    if (!yanit.ok) return null;
    const kodek = playlistKodegi(await yanit.text());
    const oynatilir = tarayiciOynatabilirMi(kodek);
    if (!kodek || oynatilir === null) return null;
    return { kodek, oynatilir };
  } catch {
    return null;
  }
}
