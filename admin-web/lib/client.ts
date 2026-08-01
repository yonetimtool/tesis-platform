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
export class ApiHatasi extends Error {
  constructor(
    message: string,
    readonly code?: string,
    readonly status?: number,
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
    throw new ApiHatasi(metin("ortakBaglantiYok"));
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
    throw new ApiHatasi(metin("ortakBaglantiYok"));
  }
  if (res.status === 401) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error(metin("ortakOturumSuresiDoldu"));
  }
  if (res.status === 204) return undefined as T;
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const zarf = (data as {
      error?: { code?: string; message?: string };
    } | null)?.error;
    throw new ApiHatasi(
      zarf?.message ?? metin("ortakHataOlustu"),
      zarf?.code,
      res.status,
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
