// (P131) KAMERA ADRESI DOGRULAMA — mobil `camera_models.dart`in TS aynasi.
//
// NEDEN IKINCI BIR UYGULAMA VAR: kural ISTEMCI tarafidir. Sunucu bir web
// SAYFASI adresini (`https://youtube.com/watch?v=…`) reddedemez — onun icin
// gecerli bir HTTPS adresidir; oynatilamayacagini bilen taraf OYNATAN
// taraftir. Web'de kamera yonetimi acilinca (P131) kural burada da
// gerekti.
//
// AYRISMA NASIL ENGELLENIYOR: kural degil VAKALAR paylasiliyor —
// `contracts/kamera-url-kurali.json`. Mobil ve web testleri AYNI dosyayi
// okur; biri ayrisirsa kendi testi duser. P126.5'te "TS'e ikinci kopya
// yazmak ayrisma demektir" diye yonetimi ACMAMISTIM; dogru cozum kopyayi
// engellemek degil, KOPYALARIN AYRISMASINI olcmekmis.
import type { CameraTur } from "./types";

/** Yayin adresi UST SINIRI — sunucudaki `URL_UST_SINIR` ile AYNI sayi. */
export const KAMERA_URL_UST_SINIR = 2048;

/** Dogrulama sonucu — METIN DEGIL KIMLIK (cizim katmani ceviriyi secer). */
export type KameraUrlHatasi =
  | "bos"
  | "cokUzun"
  | "webSayfasi"
  | "httpSemasiGerekli"
  | "rtspSemasiGerekli";

/** Bilinen web sayfasi barindiricilari — MEDYA AKISI degil, icinde
 *  oynatici BULUNAN bir sayfa dondururler. Liste TAM DEGIL ve olamaz;
 *  amaci sahada gercekten yapistirilan uc-bes adresi yakalamak. */
const WEB_BARINDIRICILARI = new Set([
  "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
  "vimeo.com", "www.vimeo.com", "player.vimeo.com",
  "dailymotion.com", "www.dailymotion.com",
  "twitch.tv", "www.twitch.tv",
  "facebook.com", "www.facebook.com", "fb.watch",
  "instagram.com", "www.instagram.com",
]);

/** Tur basina izinli sema(lar) — sunucudaki `_TUR_SEMALARI` ile ayni. */
const TUR_SEMALARI: Record<CameraTur, string[]> = {
  hls: ["http://", "https://"],
  mp4: ["http://", "https://"],
  rtsp: ["rtsp://"],
};

/** Adres dogrudan bir MEDYA dosyasina mi isaret ediyor?
 *  Sorgu dizesi ATILIR: `.../stream.m3u8?token=abc` gecerli bir HLS
 *  adresidir ve sorguyu saymak onu reddederdi. */
function medyaUzantisi(u: URL): boolean {
  const yol = u.pathname.toLowerCase();
  return yol.endsWith(".m3u8") || yol.endsWith(".mp4") || yol.endsWith(".m3u");
}

/** Adres bir web SAYFASI mi (oynatilamaz)? YALNIZ http(s) icin anlamli. */
export function webSayfasiMi(url: string): boolean {
  const u = url.trim();
  if (!u.startsWith("http://") && !u.startsWith("https://")) return false;
  let uri: URL;
  try {
    uri = new URL(u);
  } catch {
    return false;
  }
  if (!uri.hostname) return false;
  if (medyaUzantisi(uri)) return false;
  return WEB_BARINDIRICILARI.has(uri.hostname.toLowerCase());
}

/** Yayin adresi dogrulamasi; hata yoksa `null`. */
export function yayinUrlHatasi(url: string, tur: CameraTur): KameraUrlHatasi | null {
  const u = url.trim();
  if (!u) return "bos";
  // UZUNLUK SEMADAN ONCE: 3 KB'lik bir yapistirmada "https ile baslamali"
  // demek yaniltici olurdu — adres zaten https ile BASLIYOR olabilir.
  if (u.length > KAMERA_URL_UST_SINIR) return "cokUzun";
  // WEB SAYFASI KONTROLU SEMA KONTROLUNDEN ONCE: youtube adresi sema
  // kontrolunu GECER; once o calisirsa kullanici uyari almadan OYNAMAYAN
  // bir kamera kaydeder ve hatayi kamerada arar — oysa hata kayittadir.
  if (webSayfasiMi(u)) return "webSayfasi";
  if (TUR_SEMALARI[tur].some((s) => u.startsWith(s))) return null;
  return tur === "rtsp" ? "rtspSemasiGerekli" : "httpSemasiGerekli";
}

/** Anlik kare adresi — YALNIZ http(s), web sayfasi DEGIL. Bos gecerlidir
 *  (kare ozelligi kapali demektir). */
export function anlikKareHatasi(url: string | null | undefined): KameraUrlHatasi | null {
  const u = (url ?? "").trim();
  if (!u) return null;
  if (u.length > KAMERA_URL_UST_SINIR) return "cokUzun";
  if (webSayfasiMi(u)) return "webSayfasi";
  if (u.startsWith("http://") || u.startsWith("https://")) return null;
  return "httpSemasiGerekli";
}

/** Restream (HLS gecidi) adresi — YALNIZ http(s). Bos gecerlidir.
 *
 *  WEB SAYFASI KONTROLU YOK ve bu mobildeki kararla AYNI: gecit adresi
 *  operator tarafindan uretilir (Frigate/go2rtc), tarayicidan yapistirilan
 *  bir sayfa adresi degildir. */
export function restreamHatasi(url: string | null | undefined): KameraUrlHatasi | null {
  const u = (url ?? "").trim();
  if (!u) return null;
  if (u.length > KAMERA_URL_UST_SINIR) return "cokUzun";
  if (u.startsWith("http://") || u.startsWith("https://")) return null;
  return "httpSemasiGerekli";
}

/** Istemci bu kamerayi oynatabilir mi? (sunucudaki `oynatilabilir_mi`
 *  ile ayni kural — yanit alani gelmezse geri dusus icin.) */
export function oynatilabilirMi(tur: CameraTur, restreamUrl?: string | null): boolean {
  if (restreamUrl && restreamUrl.trim()) return true;
  return tur === "hls" || tur === "mp4";
}

/**
 * (P191-ek §3) ADRESTEN TUR TURET — yonetici "tur" secmek zorunda kalmasin.
 *
 * OLCULEN KUSUR: form UC ayri adres (yayin/restream/anlik kare) VE bir de
 * "yayin turu" istiyordu. Yonetici hangisini dolduracagini bilemez; oysa
 * bilgi ADRESIN KENDISINDE duruyor — `rtsp://` bir RTSP kamerasidir,
 * `.m3u8` bir HLS yayinidir. Kullaniciya zaten yazdigi seyi ikinci kez
 * sormak, yanlis cevaplanabilecek bir soru eklemekti (ve yanlis tur
 * sunucuda 422 uretiyordu).
 *
 * TAHMIN DEGIL, KURAL: sema ve uzanti bakilir. Belirsiz http(s) adresi
 * `hls` sayilir — sahada http(s) ile verilen kamera adreslerinin
 * neredeyse tamami HLS'tir ve kullanici gelismis ayarlardan degistirebilir.
 * Bos/taninmayan girdide `null` doner (cagiran mevcut secimi KORUR;
 * kullanici yazarken turu sifirlamak, yazdigi seyi altindan cekmek olurdu).
 */
export function adrestenTur(url: string): CameraTur | null {
  const u = url.trim().toLowerCase();
  if (!u) return null;
  if (u.startsWith("rtsp://")) return "rtsp";
  if (!u.startsWith("http://") && !u.startsWith("https://")) return null;
  let yol = u;
  try {
    yol = new URL(u).pathname;
  } catch {
    // Yarim yazilmis adres — uzantiya ham metinden bakilir.
  }
  if (yol.endsWith(".mp4")) return "mp4";
  return "hls";
}
