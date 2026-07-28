import { metin } from "./i18n/metin";
import { tarihSaatBicimi } from "./tarih";
// Istemci tarafi fetcher (SWR icin). Yalniz same-origin /api/* (BFF) cagrilir;
// 401 => oturum bitti, /login'e don.

export async function jsonFetcher<T>(url: string): Promise<T> {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (res.status === 401) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error(metin("ortakOturumSuresiDoldu"));
  }
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const message =
      (data as { error?: { message?: string } } | null)?.error?.message ??
      metin("ortakHataOlustu");
    throw new Error(message);
  }
  return data as T;
}

/// Geriye uyumluluk sarmalayicisi: 12 cagri yeri degismesin diye imza
/// korundu, bicimleme DILE DUYARLI `lib/tarih.ts`e devredildi (tur 31).
export function formatDateTime(iso: string): string {
  return tarihSaatBicimi(iso);
}
