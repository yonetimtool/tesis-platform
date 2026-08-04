import { NextRequest, NextResponse } from "next/server";

import { REFRESH_COOKIE } from "./lib/cookies";
import { konakYuzeyi, kokRota, rotaYuzeyi } from "./lib/yuzey";

// Korumali route'lar: oturum (refresh cookie) yoksa /login'e yonlendir.
// Token GECERLILIGI BFF route handler'larinda (401 -> refresh) dogrulanir;
// burada yalnizca oturum varligi kontrol edilir.
//
// (P126.2) YUZEY KAPISI DA BURADA. Menuyu suzmek (P125) bir sayfayi
// ERISILEMEZ yapmaz: adres cubuguna `/dues` yazan biri panelde o sayfayi
// yine acardi. Kerem'in sarti acikti — "enforcement is server-side, not
// hidden nav". Middleware istegi SAYFA CIZILMEDEN kesiyor.
//
// BU BIR VERI SINIRI DEGIL, YUZEY SINIRIDIR: veriyi koruyan sey backend
// RBAC'tir (317 ucluk rol matrisi) ve o dokunulmadan duruyor. Buradaki
// kural "hangi is hangi adreste yapilir" sorusunun cevabidir.
export function middleware(req: NextRequest): NextResponse {
  const hasSession = Boolean(req.cookies.get(REFRESH_COOKIE)?.value);
  const { pathname } = req.nextUrl;

  if (!hasSession) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  // KONAK: `Host` basligi (Caddy iletir) yoksa istegin kendi URL'i.
  // Ikisi de gerekli — `NextRequest` bir URL'den kuruldugunda `Host`
  // basligi OLUSMAZ ve yalniz basliga bakmak her istegi "platform"
  // sayardi (testte olculdu).
  const yuzey = konakYuzeyi(req.headers.get("host") ?? req.nextUrl.host);

  // Kok (`/`) yuzeyin kendi baslangicina gider: panelde tesis panosu YOKTUR.
  if (pathname === "/") {
    const url = req.nextUrl.clone();
    url.pathname = kokRota(yuzey);
    return NextResponse.redirect(url);
  }

  // Rotanin yuzeyi — alt yollar dahil (`/reports/dues` -> `/reports/dues`,
  // `/tenants/abc` -> `/tenants`).
  const rota = rotaYuzeyi(pathname) ?? rotaYuzeyi(kokParca(pathname));
  // BILINMEYEN ROTA ENGELLENMEZ: siniflandirilmamis bir sayfayi kesmek,
  // yeni bir sayfayi sessizce olduren bir tuzak olurdu. Siniflandirmanin
  // TAM olmasini `tests/yuzey-ayrimi.test.ts` zorunlu tutuyor; kapinin isi
  // BILINEN yanlis yerlesimi kesmek.
  if (rota && rota !== yuzey) {
    const url = req.nextUrl.clone();
    url.pathname = kokRota(yuzey);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

/** `/reports/dues` -> `/reports/dues`; `/tenants/abc` -> `/tenants`. */
function kokParca(pathname: string): string {
  const p = pathname.split("/").filter(Boolean);
  return p.length ? `/${p[0]}` : "/";
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
    "/units/:path*",
    "/building-editor/:path*",
    "/tanimlar/:path*",
    "/sayac-okuma/:path*",
    "/dues/:path*",
    "/users/:path*",
    "/assets/:path*",
    "/tasks/:path*",
    "/announcements/:path*",
    "/settings/:path*",
    "/reports/:path*",
    // Sonradan eklenen sayfalar — bunlar bir sure KAPI DISINDA kalmisti
    // (oturumsuz kullanici panel kabugunu goruyordu; veri sizmiyordu cunku
    // /api/* 401 doner). tests/middleware.test.ts artik app/(protected)
    // agacini gezip her sayfanin burada bir girisi oldugunu dogruluyor.
    // --- P40 panel bolumu ---
    "/finans/:path*",
    "/raporlar/:path*",
    "/mesajlar/:path*",
    "/yonetisim/:path*",
    "/portal/:path*",
    "/yetki/:path*",
    "/audit/:path*",
    "/complaints/:path*",
    "/integrations/:path*",
    "/schematic/:path*",
    "/support/:path*",
    "/tenants/:path*",
    "/transparency/:path*",
    // --- P126.3 tesis calisma alani ---
    "/profil/:path*",
    "/aidatim/:path*",
    "/taleplerim/:path*",
    "/duyurular/:path*",
    // `/site-kurallari` DEGIL: public tenant portali `/site/[slug]`ta
    // yasiyor ve `portal-public` testi "matcher `/site` ile baslayan bir
    // giris ICERMEZ" diye muhafazakar bir kontrol yapiyor. O kontrolu
    // gevsetmek yerine rota yeniden adlandirildi: public bir rotayi
    // koruyan kapi olabildigince kati kalmali (ve `/kurallar` tesis
    // calisma alaninda zaten daha iyi bir adres).
    "/kurallar/:path*",
    "/etkinlikler/:path*",
    "/rezervasyonlarim/:path*",
    "/kvkk/:path*",
  ],
};
