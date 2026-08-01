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

/** Geriye donuk sade bicim — kirpilma bilgisi GEREKMEYEN cagirilar icin. */
export async function fetchAllItems<T>(baseUrl: string, pageSize = 200): Promise<T[]> {
  return (await fetchAllPaged<T>(baseUrl, { pageSize })).items;
}

/** Idempotency-Key uretir (cift odeme kaydi korumasi). */
export function genIdempotencyKey(): string {
  const c = (globalThis as { crypto?: { randomUUID?: () => string } }).crypto;
  if (c && typeof c.randomUUID === "function") return c.randomUUID();
  return `k-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}
