import { API_KAPALI_KODU } from "./backend-kodlari";
import { metin } from "./i18n/metin";
// Istemci mutasyon yardimcisi (POST/PATCH/DELETE -> BFF /api/*).
// 401 => oturum bitti -> /login. Hata zarfindan ({error:{message}}) mesaj cikarir.

/// Sunucu hata zarfini TASIYAN istisna (tur 22).
///
/// KONTROL AKISI METNE BAKMAZ: eskiden `tenants` sayfasi
/// `/telefon|zaten kayitli|conflict/i.test(mesaj)` ile karar veriyordu —
/// sunucu metni tur 14'te 7 dile cevrilince o regex Turkce disi her dilde
/// SESSIZCE calismaz oldu. Artik `code`/`status` bakilir (mobil tur 11'de
/// ayni hata `e.code === "conflict"` ile duzeltilmisti).
/** Sunucunun dondugu ALAN DUZEYINDE hata — `422` govdesindeki `details`. */
export interface AlanHatasi {
  /** Alan yolu (`blok`, `kat_sayisi`, ...). */
  alan: string;
  /** Pydantic'in kendi (Ingilizce) teknik metni. */
  mesaj: string;
}

export class ApiHatasi extends Error {
  constructor(
    message: string,
    readonly code?: string,
    readonly status?: number,
    /**
     * (P162) ALAN AYRINTILARI ARTIK KAYBOLMUYOR.
     *
     * OLCULEN KUSUR: sunucu 422'de `error.details[]` ile HANGI ALANIN
     * NEDEN reddedildigini soyluyordu (`errors.py` bunu bilerek
     * dolduruyor) ama istemci YALNIZ `error.message`i okuyup gerisini
     * atiyordu. Kullaniciya kalan tek cumle "Istek govdesi gecersiz"
     * oluyordu — hangi alanin sorunlu oldugu EKRANDA HIC GORUNMUYORDU.
     * Toplu daire olusturmadaki "Bir hata olustu" sikayetinin kaynagi
     * tam olarak buydu.
     */
    readonly alanlar?: AlanHatasi[],
  ) {
    super(message);
    this.name = "ApiHatasi";
  }
}

/** (P101) 401 ISLEME — HAM `fetch` KULLANAN CAGRI YERLERI ICIN.
 *
 * `apiSend`, `jsonFetcher` ve `fetchAllPaged` 401'de giris ekranina
 * yonlendirir. Ama uc cagri yeri ham `fetch` kullaniyor (FormData ya da
 * ikili govde gerektirdikleri icin) ve 401'i SIRADAN bir hata gibi
 * isliyordu: kullaniciya "Yanit kaydedilemedi (401)" gibi bir KOD
 * gosteriliyor, oturumun bittigi soylenmiyor ve sayfa olu kaliyordu.
 * Ayni gercek dort yerde, ucu farkli davraniyordu.
 *
 * `true` donerse cagiran BASKA BIR SEY YAPMAMALI: yonlendirme baslatildi.
 */
export function oturumDustu(res: Response): boolean {
  if (res.status !== 401) return false;
  if (typeof window !== "undefined") window.location.href = "/login";
  return true;
}

/** (P102) HAM `fetch` ICIN ORTAK GIRIS: ag hatasi CEVRILIR, 401 ISLENIR.
 *
 * P101 401'i ortakladi ama ikinci bir sapma kaldi: ag koptugunda tarayici
 * `TypeError: Failed to fetch` atar ve ham `fetch` kullanan cagri yerleri
 * bunu OLDUGU GIBI gosteriyordu — her dilde, teknik ve anlamsiz. Oysa
 * `apiSend`/`jsonFetcher` ayni durumu `ortakBaglantiYok` diye cevirir
 * (tur 42'de tam bu kusur olculmustu). Ayni gercek, yine iki davranis.
 *
 * `null` donerse cagiran BASKA BIR SEY YAPMAMALI: oturum bitti ve
 * yonlendirme baslatildi.
 */
export async function agIstegi(
  url: string,
  init?: RequestInit,
): Promise<Response | null> {
  let res: Response;
  try {
    res = await fetch(url, init);
  } catch {
    // (P171 duzeltme) KOD ILISTIRILIR: merkezi durum ekrani metne
    // degil koda bakar. Tarayicinin hic ulasamamasi, BFF'in "API'ye
    // ulasamiyorum" demesiyle kullanici acisindan AYNI durumdur.
    throw new ApiHatasi(metin("ortakBaglantiYok"), API_KAPALI_KODU);
  }
  return oturumDustu(res) ? null : res;
}

/** (P103) Hata zarfindaki SUNUCU MESAJINI oku; yoksa [yedek] metni doner.
 *
 * Backend `{error:{code,message}}` zarfinda KULLANICI DILINDE ve sebebe
 * ozel bir metin doner. Ham `fetch` kullanan cagri yerleri bunu ATIP
 * "... (413)" gibi bir KOD gosteriyordu; kullanici neden olmadigini
 * ogrenemiyordu. `apiSend` zaten zarfi okur — bu, ayni davranisi ikili
 * govde kullanan yerlere tasir.
 *
 * Govde okunamazsa (vekil/ag katmani duz metin dondurebilir) yedek metin
 * kullanilir: zarf YOKLUGU bir hata degil, beklenen bir durumdur.
 */
export async function sunucuMesaji(res: Response, yedek: string): Promise<string> {
  const veri: unknown = await res.json().catch(() => null);
  const mesaj = (veri as { error?: { message?: string } } | null)?.error?.message;
  return mesaj && mesaj.trim() ? mesaj : yedek;
}

export async function apiSend<T = unknown>(
  url: string,
  method: string,
  body?: unknown,
  headers?: Record<string, string>,
): Promise<T> {
  const h: Record<string, string> = { ...(headers ?? {}) };
  if (body !== undefined) h["Content-Type"] = "application/json";
  // Ag hatasi: ham "Failed to fetch" yerine cevrilmis metin (tur 42) —
  // `jsonFetcher` ile ayni davranis.
  let res: Response;
  try {
    res = await fetch(url, {
      method,
      headers: Object.keys(h).length ? h : undefined,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch {
    // (P171 duzeltme) KOD ILISTIRILIR: merkezi durum ekrani metne
    // degil koda bakar. Tarayicinin hic ulasamamasi, BFF'in "API'ye
    // ulasamiyorum" demesiyle kullanici acisindan AYNI durumdur.
    throw new ApiHatasi(metin("ortakBaglantiYok"), API_KAPALI_KODU);
  }
  if (res.status === 401) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error(metin("ortakOturumSuresiDoldu"));
  }
  if (res.status === 204) return undefined as T;
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const zarf = (data as {
      error?: {
        code?: string;
        message?: string;
        details?: { field?: string; message?: string }[];
      };
    } | null)?.error;
    // (P163 §2) GOVDESIZ YANITTA DA ANLAMLI MESAJ.
    //
    // OLCULEN KUSUR: 405 ve 500 gibi yanitlarda govde YOK ya da JSON
    // DEGIL; `data` `null` oluyor, `zarf` tanimsiz kaliyor ve kullaniciya
    // "Bir hata olustu" yaziliyordu. O cumle hicbir sey soylemez —
    // kullanici da destek de nereden baslayacagini bilemez.
    //
    // Artik durum kodu ve REFERANS yaziliyor. Referans = metot + yol:
    // hatayi ureten istegi TEK BASINA belirler ve sunucu gunlugunde
    // aranabilir. Kimlik ya da govde ICERMEZ — hata metni bir sizinti
    // yuzeyi degildir.
    const referans = `${method} ${url}`;
    throw new ApiHatasi(
      zarf?.message ??
        metin("ortakSunucuHatasi", { durum: String(res.status), referans }),
      zarf?.code,
      res.status,
      zarf?.details?.map((d) => ({ alan: d.field ?? "", mesaj: d.message ?? "" })),
    );
  }
  return data as T;
}

/** Sayfali bir BFF list ucundaki TUM kayitlari ceker (rapor/aggregate icin).
 *
 * (P65) UST SINIR VAR ve SESSIZ DEGIL. Eskiden dongu `total`a kadar
 * kosardi: 200.000 odemesi olan bir sitede tarayici **1.000 ardisik istek**
 * atar, sayfa dakikalarca kilitli gorunurdu. Artik [enCok] kayitta durur ve
 * `kesildi` bayragini doner — cagiran bunu KULLANICIYA SOYLEMEK zorundadir.
 * Sessiz kirpma, eksik bir raporu tam sanmak demektir.
 */
export interface TumKayitSonuc<T> {
  items: T[];
  /** Ust sinira takildi mi — rapor EKSIKTIR ve bu soylenmelidir. */
  kesildi: boolean;
}

export async function fetchAllPaged<T>(
  baseUrl: string,
  { pageSize = 200, enCok = 5000 }: { pageSize?: number; enCok?: number } = {},
): Promise<TumKayitSonuc<T>> {
  const out: T[] = [];
  let offset = 0;
  let kesildi = false;
  const sep = baseUrl.includes("?") ? "&" : "?";
  for (;;) {
    if (out.length >= enCok) {
      kesildi = true;
      break;
    }
    const res = await fetch(`${baseUrl}${sep}limit=${pageSize}&offset=${offset}`);
    if (res.status === 401) {
      if (typeof window !== "undefined") window.location.href = "/login";
      throw new Error(metin("ortakOturumSuresiDoldu"));
    }
    const data: unknown = await res.json().catch(() => null);
    if (!res.ok) {
      const m = (data as { error?: { message?: string } } | null)?.error?.message ?? metin("ortakHataOlustu");
      throw new Error(m);
    }
    const d = data as { items?: T[]; meta?: { total?: number } } | null;
    const items = d?.items ?? [];
    out.push(...items);
    const total = d?.meta?.total ?? out.length;
    offset += pageSize;
    if (items.length === 0 || offset >= total) break;
  }
  return { items: out, kesildi };
}

// (P65) `fetchAllItems` KALDIRILDI. Once geriye donuk uyum icin
// birakilmisti; ama ust siniri o sarmalayicinin ARKASINA koymak, "sessiz
// kirpma yapma" kuralini kendi elimle bozmakti: dort cagiran da 5.000'de
// kirpilir ve HICBIRI bunu soylemezdi. Sinir varsa cagiran onu GORMELI —
// bu yuzden tek giris `fetchAllPaged`tir ve `kesildi` doner.

/** Idempotency-Key uretir (cift odeme kaydi korumasi). */
export function genIdempotencyKey(): string {
  const c = (globalThis as { crypto?: { randomUUID?: () => string } }).crypto;
  if (c && typeof c.randomUUID === "function") return c.randomUUID();
  return `k-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

/**
 * (P162 §4.1) SUNUCU HATASINI KULLANICININ ANLAYACAGI HALE GETIRIR.
 *
 * OLCULEN KUSUR: sunucu 422'de `error.details[]` ile hangi alanin neden
 * reddedildigini soyluyor, ama ekranda yalnizca ust cumle ("Istek govdesi
 * gecersiz") gorunuyordu. Kullanici hangi alani duzeltecegini
 * BILEMIYORDU — toplu daire olusturmadaki "Bir hata olustu" sikayetinin
 * kaynagi buydu.
 *
 * ALAN ADLARI CEVRILMEZ ve bu bilincli: `blok`, `kat_sayisi` gibi adlar
 * SOZLESME adlaridir; onlari yerellestirmek, kullanicinin gordugu adla
 * belgelerdeki adi ayirirdi. Cevrilen sey UST CUMLEDIR (sunucu zaten
 * istegin dilinde doner).
 */
export function alanliHataMetni(hata: unknown, varsayilan: string): string {
  if (!(hata instanceof ApiHatasi)) {
    return hata instanceof Error ? hata.message : varsayilan;
  }
  const alanlar = hata.alanlar ?? [];
  if (alanlar.length === 0) return hata.message;
  const ayrinti = alanlar
    .filter((a) => a.alan)
    .map((a) => `${a.alan}: ${a.mesaj}`)
    .join(" · ");
  return ayrinti ? `${hata.message} — ${ayrinti}` : hata.message;
}
