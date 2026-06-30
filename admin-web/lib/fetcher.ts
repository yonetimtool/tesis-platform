// Istemci tarafi fetcher (SWR icin). Yalniz same-origin /api/* (BFF) cagrilir;
// 401 => oturum bitti, /login'e don.

export async function jsonFetcher<T>(url: string): Promise<T> {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (res.status === 401) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error("Oturum suresi doldu.");
  }
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const message =
      (data as { error?: { message?: string } } | null)?.error?.message ??
      "Bir hata olustu.";
    throw new Error(message);
  }
  return data as T;
}

export function formatDateTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString("tr-TR", {
      dateStyle: "short",
      timeStyle: "short",
    });
  } catch {
    return iso;
  }
}
