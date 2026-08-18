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
    throw kodluHata(hata?.message ?? metin("ortakHataOlustu"), hata?.code);
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
export function kodluHata(mesaj: string, kod?: string): Error {
  const e = new Error(mesaj) as Error & { kod?: string };
  if (kod) e.kod = kod;
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
