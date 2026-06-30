// BFF cekirdegi: backend'e (FastAPI) sunucu tarafindan proxy.
// Token'lar httpOnly cookie'de; istemci ASLA gormez. 401'de TEK-UCUS (single-flight)
// refresh: backend refresh rotation yaptigi icin es zamanli yenilemeler tek cagrida
// birlestirilir (reuse-revoke onlenir).

import { cookies } from "next/headers";
import { NextResponse } from "next/server";

import { API_BASE } from "./config";
import {
  ACCESS_COOKIE,
  ACCESS_MAX_AGE,
  REFRESH_COOKIE,
  REFRESH_MAX_AGE,
  cookieOptions,
} from "./cookies";

interface TokenPair {
  access: string;
  refresh: string;
}

function setAuthCookies(res: NextResponse, access: string, refresh: string): void {
  res.cookies.set(ACCESS_COOKIE, access, cookieOptions(ACCESS_MAX_AGE));
  res.cookies.set(REFRESH_COOKIE, refresh, cookieOptions(REFRESH_MAX_AGE));
}

function clearAuthCookies(res: NextResponse): void {
  res.cookies.delete(ACCESS_COOKIE);
  res.cookies.delete(REFRESH_COOKIE);
}

async function callBackend(
  path: string,
  method: string,
  accessToken: string | undefined,
  body?: unknown,
): Promise<Response> {
  const headers: Record<string, string> = {};
  if (accessToken) headers["Authorization"] = `Bearer ${accessToken}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  return fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
    cache: "no-store",
  });
}

// --- single-flight refresh ------------------------------------------------- #
const inflight = new Map<string, Promise<TokenPair | null>>();

function refreshSingleFlight(rt: string): Promise<TokenPair | null> {
  const existing = inflight.get(rt);
  if (existing) return existing;
  const p = (async (): Promise<TokenPair | null> => {
    try {
      const res = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: rt }),
        cache: "no-store",
      });
      if (!res.ok) return null;
      const d = (await res.json()) as { access_token: string; refresh_token: string };
      return { access: d.access_token, refresh: d.refresh_token };
    } catch {
      return null;
    } finally {
      inflight.delete(rt);
    }
  })();
  inflight.set(rt, p);
  return p;
}

/** Backend'e dogrudan login (cookie set etmeyi cagiran route handler yapar). */
export async function backendLogin(body: {
  tenant_slug: string;
  email: string;
  password: string;
}): Promise<{ ok: boolean; status: number; data: unknown }> {
  const res = await callBackend("/auth/login", "POST", undefined, body);
  const data = await res.json().catch(() => null);
  return { ok: res.ok, status: res.status, data };
}

export function loginResponse(access: string, refresh: string): NextResponse {
  const res = NextResponse.json({ ok: true });
  setAuthCookies(res, access, refresh);
  return res;
}

export function logoutResponse(): NextResponse {
  const res = NextResponse.json({ ok: true });
  clearAuthCookies(res);
  return res;
}

/**
 * Korumali bir backend cagrisini proxy'le: access cookie ile dene; 401 ise
 * refresh (single-flight) + cookie rotasyonu + bir kez tekrar. refresh olunce
 * 401 + cookie temizle (istemci login'e doner).
 */
async function passthrough(res: Response): Promise<NextResponse> {
  // 204 / bos govde (orn. DELETE) -> govdesiz yanit.
  if (res.status === 204 || res.headers.get("content-length") === "0") {
    return new NextResponse(null, { status: res.status });
  }
  const data = await res.json().catch(() => null);
  return NextResponse.json(data, { status: res.status });
}

export async function proxyJson(
  path: string,
  method: string,
  body?: unknown,
): Promise<NextResponse> {
  const jar = cookies();
  const access = jar.get(ACCESS_COOKIE)?.value;
  const refresh = jar.get(REFRESH_COOKIE)?.value;

  let res = await callBackend(path, method, access, body);

  if (res.status === 401 && refresh) {
    const pair = await refreshSingleFlight(refresh);
    if (!pair) {
      const out = NextResponse.json(
        { error: { code: "unauthorized", message: "Oturum suresi doldu." } },
        { status: 401 },
      );
      clearAuthCookies(out);
      return out;
    }
    res = await callBackend(path, method, pair.access, body);
    const out = await passthrough(res);
    setAuthCookies(out, pair.access, pair.refresh);
    return out;
  }

  return passthrough(res);
}
