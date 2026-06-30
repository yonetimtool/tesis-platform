// Token cookie isimleri ve secenekleri. Edge middleware'den de import edilebilir
// olmasi icin next/headers gibi server-only modul KULLANMAZ.

export const ACCESS_COOKIE = "tesis_at";
export const REFRESH_COOKIE = "tesis_rt";

// /contracts/auth.md: access 15 dk, refresh 30 gun.
export const ACCESS_MAX_AGE = 15 * 60;
export const REFRESH_MAX_AGE = 30 * 24 * 60 * 60;

export interface CookieOptions {
  httpOnly: true;
  sameSite: "lax";
  secure: boolean;
  path: string;
  maxAge: number;
}

export function cookieOptions(maxAge: number): CookieOptions {
  return {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge,
  };
}
