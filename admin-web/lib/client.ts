// Istemci mutasyon yardimcisi (POST/PATCH/DELETE -> BFF /api/*).
// 401 => oturum bitti -> /login. Hata zarfindan ({error:{message}}) mesaj cikarir.

export async function apiSend<T = unknown>(
  url: string,
  method: string,
  body?: unknown,
  headers?: Record<string, string>,
): Promise<T> {
  const h: Record<string, string> = { ...(headers ?? {}) };
  if (body !== undefined) h["Content-Type"] = "application/json";
  const res = await fetch(url, {
    method,
    headers: Object.keys(h).length ? h : undefined,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error("Oturum süresi doldu.");
  }
  if (res.status === 204) return undefined as T;
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const message =
      (data as { error?: { message?: string } } | null)?.error?.message ??
      "Bir hata oluştu.";
    throw new Error(message);
  }
  return data as T;
}

/** Sayfali bir BFF list ucundaki TUM kayitlari ceker (rapor/aggregate icin). */
export async function fetchAllItems<T>(baseUrl: string, pageSize = 200): Promise<T[]> {
  const out: T[] = [];
  let offset = 0;
  const sep = baseUrl.includes("?") ? "&" : "?";
  for (;;) {
    const res = await fetch(`${baseUrl}${sep}limit=${pageSize}&offset=${offset}`);
    if (res.status === 401) {
      if (typeof window !== "undefined") window.location.href = "/login";
      throw new Error("Oturum süresi doldu.");
    }
    const data: unknown = await res.json().catch(() => null);
    if (!res.ok) {
      const m = (data as { error?: { message?: string } } | null)?.error?.message ?? "Hata";
      throw new Error(m);
    }
    const d = data as { items?: T[]; meta?: { total?: number } } | null;
    const items = d?.items ?? [];
    out.push(...items);
    const total = d?.meta?.total ?? out.length;
    offset += pageSize;
    if (items.length === 0 || offset >= total) break;
  }
  return out;
}

/** Idempotency-Key uretir (cift odeme kaydi korumasi). */
export function genIdempotencyKey(): string {
  const c = (globalThis as { crypto?: { randomUUID?: () => string } }).crypto;
  if (c && typeof c.randomUUID === "function") return c.randomUUID();
  return `k-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}
