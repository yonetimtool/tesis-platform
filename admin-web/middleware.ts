import { NextRequest, NextResponse } from "next/server";

import { ACCESS_COOKIE, REFRESH_COOKIE } from "./lib/cookies";
import { tokenRolu } from "./lib/rol-token";
import {
  konakYuzeyi,
  kokRota,
  kokRotaRol,
  rotaRoldeGorunur,
  rotaYuzeyi,
} from "./lib/yuzey";

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

  // (P127) TANITIM YUZEYI OTURUM KAPISININ DISINDADIR ve bu SIRA onemli:
  // kapi once calissaydi, markanin ana adresine giren HER ZIYARETCI
  // `/login`e duserdi — yani tanitim sitesi hic gorunmezdi.
  //
  // Kok alan adinda YALNIZ tanitim sayfalari vardir; korumali bir adres
  // elle yazilirsa (orn. yönetiyor.com/dues) kullanici KOKE dondurulur,
  // `/login`e DEGIL: giris o alan adinin isi degildir (panel.* ve app.*
  // vardir) ve orada bir giris formu gostermek yuzey ayrimini bozardi.
  const konakYuzey = konakYuzeyi(req.headers.get("host") ?? req.nextUrl.host);
  if (konakYuzey === "tanitim") {
    if (pathname === "/") return NextResponse.next();
    const url = req.nextUrl.clone();
    url.pathname = "/";
    return NextResponse.redirect(url);
  }
  // NOT (P155 §7/§8): `/davet/‹jeton›` bilincli olarak `config.matcher`DE
  // YOK — yani middleware ona HIC dokunmaz ve sayfa oturum kapisi olmadan
  // dogrudan sunulur (davetin web yedegi tanitim alan adinda public
  // olmali). Buraya bir istisna yazmak GEREKMEZ; matcher zaten disliyor.

  if (!hasSession) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  // KONAK: `Host` basligi (Caddy iletir) yoksa istegin kendi URL'i.
  // Ikisi de gerekli — `NextRequest` bir URL'den kuruldugunda `Host`
  // basligi OLUSMAZ ve yalniz basliga bakmak her istegi "platform"
  // sayardi (testte olculdu).
  const yuzey = konakYuzey;

  // (P126.7) ROL: access cerezinden okunur. YOKSA (15 dk'da duser) `null`
  // kalir ve rol kapisi UYGULANMAZ — kullaniciyi yenileme akisi calismadan
  // once disari atmak, oturumu acik birine "yetkin yok" demek olurdu.
  const rol = tokenRolu(req.cookies.get(ACCESS_COOKIE)?.value);

  // Kok (`/`) yuzeyin kendi baslangicina gider: panelde tesis panosu YOKTUR.
  // Hedef ROLE GORE secilir: sakini `/dashboard`a yollamak, goremedigi bir
  // sayfaya atip hemen geri yonlendirmek (dongu) demekti.
  if (pathname === "/") {
    const url = req.nextUrl.clone();
    url.pathname = rol ? kokRotaRol(yuzey, rol) : kokRota(yuzey);
    return NextResponse.redirect(url);
  }

  // Rotanin yuzeyi — alt yollar dahil (`/reports/dues` -> `/reports/dues`,
  // `/tenants/abc` -> `/tenants`).
  // ALT YOL TEK BIR ROTA ADINA INDIRGENIR: `/tasks/123` -> `/tasks`.
  // Bu ad hem yuzey hem ROL kapisinda kullanilir; iki farkli cozumleme
  // yapmak, derin baglantilarin rol kapisina takilmasi demekti (siniflandirma
  // `/tasks/123` icin `null` doner ve "rolde yok" sayilirdi).
  const rotaAdi = rotaYuzeyi(pathname) !== null ? pathname : kokParca(pathname);
  const rota = rotaYuzeyi(rotaAdi);
  // BILINMEYEN ROTA ENGELLENMEZ: siniflandirilmamis bir sayfayi kesmek,
  // yeni bir sayfayi sessizce olduren bir tuzak olurdu. Siniflandirmanin
  // TAM olmasini `tests/yuzey-ayrimi.test.ts` zorunlu tutuyor; kapinin isi
  // BILINEN yanlis yerlesimi kesmek.
  if (rota && rota !== yuzey) {
    const url = req.nextUrl.clone();
    url.pathname = rol ? kokRotaRol(yuzey, rol) : kokRota(yuzey);
    return NextResponse.redirect(url);
  }

  // (P126.7) ROL KAPISI — dogru yuzey ama YANLIS ROL.
  //
  // Menuyu role gore suzmek (AppShell) adresi yazan birini durdurmaz:
  // `app.*`ta `/finans` yazan bir sakin, bugune kadar sayfayi acar ve
  // BFF'ten 403 alirdi — yani kirik bir ekran. Kapi istegi sayfa
  // cizilmeden kesip rolun KENDI baslangicina yollar.
  //
  // YINE BIR YUZEY SINIRIDIR, VERI SINIRI DEGIL: veriyi backend RBAC
  // koruyor (`backend/tests/test_yuzey_yalitimi.py`). Rol `null` ise
  // (access cerezi dusmus) kapi UYGULANMAZ.
  if (rol && rota === yuzey && !rotaRoldeGorunur(rotaAdi, rol)) {
    const kok = kokRotaRol(yuzey, rol);
    if (pathname !== kok) {
      const url = req.nextUrl.clone();
      url.pathname = kok;
      return NextResponse.redirect(url);
    }
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
    // (P162) Site kurali ve etkinlik YONETIM ekranlari — sakin
    // gorunumlerinden ayri sayfalar, ayri rol kapisi.
    "/site-kurallari/:path*",
    "/etkinlik-yonetimi/:path*",
    "/settings/:path*",
    "/reports/:path*",
    // Sonradan eklenen sayfalar — bunlar bir sure KAPI DISINDA kalmisti
    // (oturumsuz kullanici panel kabugunu goruyordu; veri sizmiyordu cunku
    // /api/* 401 doner). tests/middleware.test.ts artik app/(protected)
    // agacini gezip her sayfanin burada bir girisi oldugunu dogruluyor.
    // --- P40 panel bolumu ---
    "/finans/:path*",
    // (P154 / Asama 7.1) Icra ayri ust bolum oldu.
    "/icra/:path*",
    "/raporlar/:path*",
    "/mesajlar/:path*",
    "/yonetisim/:path*",
    "/anketler/:path*",
    "/kurulum/:path*",
    "/ice-aktarim/:path*",
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
    // `/site-kurallari` DEGIL, `/kurallar`. Gerekce eskiden public tenant
    // portalinin `/site/[slug]`ta yasamasiydi; (P154 / Asama 7.2) o portal
    // KALDIRILDI ama ad DEGISTIRILMEDI: `/kurallar` tesis calisma alaninda
    // zaten daha iyi bir adres ve calisan bir rotayi yalnizca eski gerekce
    // dustu diye yeniden adlandirmak, kayitli baglantilari kirardi.
    "/kurallar/:path*",
    "/etkinlikler/:path*",
    "/rezervasyonlarim/:path*",
    "/kvkk/:path*",
    "/ziyaretciler/:path*",
    "/kargolar/:path*",
    "/davetler/:path*",
    "/olaylar/:path*",
    "/arac-gecisleri/:path*",
    "/gorevlerim/:path*",
    "/kameralar/:path*",
    "/dis-hizmetler/:path*",
    "/yonetim-iletisim/:path*",
  ],
};
