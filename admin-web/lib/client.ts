// Istemci mutasyon yardimcisi (POST/PATCH/DELETE -> BFF /api/*).
// 401 => oturum bitti -> /login. Hata zarfindan ({error:{message}}) mesaj cikarir.

export async function apiSend<T = unknown>(
  url: string,
  method: string,
  body?: unknown,
): Promise<T> {
  const res = await fetch(url, {
    method,
    headers: body !== undefined ? { "Content-Type": "application/json" } : undefined,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error("Oturum suresi doldu.");
  }
  if (res.status === 204) return undefined as T;
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const message =
      (data as { error?: { message?: string } } | null)?.error?.message ??
      "Bir hata olustu.";
    throw new Error(message);
  }
  return data as T;
}
