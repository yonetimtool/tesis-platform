import { API_KAPALI_KODU } from "./backend-kodlari";
import { metin } from "./i18n/metin";
import { tarihSaatBicimi } from "./tarih";
// Istemci tarafi fetcher (SWR icin). Yalniz same-origin /api/* (BFF) cagrilir;
// 401 => oturum bitti, /login'e don.

export async function jsonFetcher<T>(url: string): Promise<T> {
  // AG HATASI: `fetch` baglanti kurulamayinca `TypeError: Failed to fetch`
  // atar ve bu HAM metin kullaniciya gosteriliyordu — her dilde, teknik ve
  // anlamsiz (tur 42 cevrimdisi surusu). Mobil tarafta ayni durum
  // `AkisHatasi.agHatasi` ile cevriliyor; panelin karsiligi budur.
  let res: Response;
  try {
    res = await fetch(url, { headers: { Accept: "application/json" } });
  } catch {
    // (P171 duzeltme) TARAYICI HIC ULASAMADI (cevrimdisi, panel kapali).
    // Kullanici acisindan bu, BFF'in "API'ye ulasamiyorum" demesiyle AYNI
    // durumdur: yapacagi sey beklemek ve tekrar denemek. Ayni kodu vermek,
    // merkezi durum ekraninin ikisini de yakalamasini saglar.
    throw kodluHata(metin("ortakBaglantiYok"), API_KAPALI_KODU);
  }
  if (res.status === 401) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error(metin("ortakOturumSuresiDoldu"));
  }
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const hata = (data as { error?: { message?: string; code?: string } } | null)
      ?.error;
    // (P175 §4) HANGI CAGRI PATLADI — REFERANS METINDE.
    //
    // "Veriler yuklenemedi" hangi ucun neden basarisiz oldugunu
    // SOYLEMIYORDU; bir ekran birden fazla uc cagirdiginda kullanici da
    // destek de nereden baslayacagini bilemiyordu. Yazma yolu
    // (`apiSend`) bunu P163'te cozmustu; okuma yolu cozmemisti.
    //
    // Referans = durum kodu + YOL. Istegi tek basina belirler ve sunucu
    // gunlugunde aranabilir. Kimlik ya da govde ICERMEZ — hata metni bir
    // sizinti yuzeyi degildir.
    throw kodluHata(
      hata?.message ?? govdesizMesaj(res.status, `GET ${url.split("?")[0]}`),
      hata?.code,
      res.status,
    );
  }
  return data as T;
}

/**
 * (P171 duzeltme) HATAYA SUNUCU KODUNU ILISTIR.
 *
 * Onceden yalnizca METIN atiliyordu ve cagiran taraf "bu hangi hata"
 * sorusunu ancak metne bakarak yanitlayabilirdi — yedi dilde degisen bir
 * metne. Kod degismez; merkezi durum ekrani ona bakiyor.
 */
/**
 * (P173) GOVDESIZ YANITTA ANLAMLI MESAJ — "Bir hata olustu" DEGIL.
 *
 * =========================================================================
 * OLCULEN OLAY
 * =========================================================================
 * `mesaj-ayarlari` ucu BFF beyaz listesinde yoktu: vekil kendi 404'unu
 * donuyor, `PUT`/`POST` icin ise Next 405 uretiyordu. Ikisinin de GOVDESI
 * YOK, yani `error.message` yok. Ekran genel "bir hata olustu" gosterip
 * susuyordu ve kullanicinin elinde HICBIR ipucu kalmiyordu — sunucu
 * log'unda da iz yoktu, cunku istek uc govdesine hic ulasmadi.
 *
 * 404 ve 405 GOVDESIZ geldiginde bu neredeyse her zaman AYNI ANLAMA
 * gelir: istemci ile sunucu SURUMLERI ayrismis ya da bir uc henuz
 * yayina alinmamis. Mesaj bunu soyluyor — "tekrar dene" demiyor, cunku
 * tekrar denemek ISE YARAMAZ.
 */
function govdesizMesaj(durum: number, referans: string): string {
  // 404/405: SURUM AYRISMASI. Ozel metin korunuyor — "tekrar dene"
  // demiyor, cunku tekrar denemek ISE YARAMAZ. Referans yine de
  // ekleniyor: hangi cagri oldugunu soylemek her durumda gerekli.
  if (durum === 404) return `${metin("ortakUcBulunamadi")} (${referans})`;
  if (durum === 405) {
    return `${metin("ortakYontemDesteklenmiyor")} (${referans})`;
  }
  // (P175 §4) Otekiler: durum kodu + referans. Istegi TEK BASINA
  // belirler ve sunucu gunlugunde aranabilir.
  return metin("ortakSunucuHatasi", { durum: String(durum), referans });
}

export function kodluHata(
  mesaj: string,
  kod?: string,
  durum?: number,
): Error {
  const e = new Error(mesaj) as Error & { kod?: string; durum?: number };
  if (kod) e.kod = kod;
  // (P175 §3) HTTP DURUMU DA TASINIR: yeniden deneme karari buna bakiyor.
  // 404/405 gibi bir yanit TEKRAR DENEMEKLE degismez; onlari denemek
  // sunucuya bosuna yuk bindirir.
  if (durum !== undefined) e.durum = durum;
  return e;
}

/** Bu hata "API'ye ulasilamiyor" mu — tek karar yeri. */
export function apiKapaliMi(e: unknown): boolean {
  return (e as { kod?: string } | null)?.kod === API_KAPALI_KODU;
}

/// Geriye uyumluluk sarmalayicisi: 12 cagri yeri degismesin diye imza
/// korundu, bicimleme DILE DUYARLI `lib/tarih.ts`e devredildi (tur 31).
export function formatDateTime(iso: string): string {
  return tarihSaatBicimi(iso);
}
