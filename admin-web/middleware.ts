import { NextRequest, NextResponse } from "next/server";

import { REFRESH_COOKIE } from "./lib/cookies";

// Korumali route'lar: oturum (refresh cookie) yoksa /login'e yonlendir.
// Token GECERLILIGI BFF route handler'larinda (401 -> refresh) dogrulanir;
// burada yalnizca oturum varligi kontrol edilir.
export function middleware(req: NextRequest): NextResponse {
  const hasSession = Boolean(req.cookies.get(REFRESH_COOKIE)?.value);
  const { pathname } = req.nextUrl;

  if (!hasSession) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  // /login ve /api/* haric korunan sayfalar:
  matcher: [
    "/",
    "/dashboard/:path*",
    "/notifications/:path*",
    "/shifts/:path*",
    "/checkpoints/:path*",
    "/patrol-plans/:path*",
  ],
};
