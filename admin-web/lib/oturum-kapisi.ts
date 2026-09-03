/**
 * (P154 / Asama 4) YUZEY KAPISI + OTURUM ACMA — TEK YER.
 *
 * NEDEN VAR: bir token cifti elde eden HER yol ayni iki isi yapmak
 * zorunda — (1) rolun bu yuzeye girip giremeyecegini sormak, (2) jetonlari
 * httpOnly cerezlere yazmak. Bu ikisi `login` rotasinda satir ici
 * yaziliydi ve sosyal giris UCUNCU bir yol getiriyor.
 *
 * Kapiyi kopyalamak, sosyal girisi kapinin ETRAFINDAN DOLASAN bir yol
 * yapardi: `panel.*` icin reddedilen bir rol, Google dugmesiyle iceri
 * girebilirdi. `login/route.ts`in kendi yorumu bu sinifi zaten kaydetmis:
 * "Iki giris rotasina kopyalanmisti; mutasyon denetimi telefon
 * rotasindaki dal bozuldugunda hicbir testin dusmedigini gosterdi."
 *
 * KARARIN KENDISI hâlâ `lib/yuzey.ts`te (`girisRedKarari`); burasi yalniz
 * onu cagirip yanita ceviriyor.
 */
import { NextRequest, NextResponse } from "next/server";

import { loginResponse } from "@/lib/backend";
import { cookieDomain } from "@/lib/cookies";
import { appKonagi, istekKonagi, konakOtesiAdres } from "@/lib/konak-adres";
import { istekMetni } from "@/lib/i18n/istek-metni";
import { tokenRolu } from "@/lib/rol-token";
import { girisRedKarari, konakYuzeyi, rolYuzeyeGirebilir } from "@/lib/yuzey";

/**
 * (P211 §2) YANLIS YUZEYDEKI YONETICI ICIN `app.*` KOK ADRESI.
 *
 * Port SIZDIRMAZ: adres once `NEXT_PUBLIC_APP_ADRESI`ten, olmazsa
 * iletilmis basliklardan kurulur (P201 dersi — `req.nextUrl` Next'in ic
 * dinleme portunu, `:3000`, adrese tasiyordu).
 */
export function appKokAdresi(req: NextRequest): string | null {
  return konakOtesiAdres("/", "", {
    ortamKok: process.env.NEXT_PUBLIC_APP_ADRESI ?? null,
    yedekKonak: appKonagi(istekKonagi(req.headers) ?? null),
    basliklar: req.headers,
  });
}

/**
 * Jeton ciftini yuzey kapisindan gecirir ve gecerse oturumu acar.
 *
 * JETONLAR GOVDEDE DONMEZ: panelde jeton hicbir zaman JS'e gorunmez
 * (mevcut giris yollarinin kurali). `loginResponse` httpOnly cerez yazar.
 */
export function oturumAc(
  req: NextRequest,
  access: string,
  refresh: string,
): NextResponse {
  const rol = tokenRolu(access);
  const yuzey = konakYuzeyi(req.headers.get("host"));
  if (!rolYuzeyeGirebilir(rol, yuzey)) {
    // (P211 §2) PANELE DUSEN TESIS ROLU: KAPI DEGIL, KOPRU.
    //
    // OLCULEN KUSUR: `panel.yonetiyor.com`da giris yapan yonetici 403 +
    // "panel platform icindir" mesaji aliyor ve ORADA KALIYORDU —
    // gidecegi adresi kimse soylemiyordu. Rol `app.*`a GIREBILIYORSA
    // dogru cevap "hayir" degil, "buraya degil, SURAYA".
    //
    // Oturum ACILIR: cerezler `COOKIE_DOMAIN` (.yonetiyor.com) ile ust
    // alan adina yazilir, yani app.* tarafinda kullanici ZATEN iceridedir
    // ve ikinci kez giris istenmez. Cerez alan adi ayarli DEGILSE
    // (yerel/dev) adres uretilemez, eski davranis (403) aynen kalir.
    const koprulu =
      yuzey === "platform" &&
      rolYuzeyeGirebilir(rol, "tesis") &&
      // CEREZ UST ALAN ADINA YAZILMIYORSA KOPRU KURULMAZ: app.* tarafinda
      // cerez OLMAZ, kullanici oraya varir varmaz `/login`e duserdi —
      // "mesaj gorup kalmak"tan daha kotu bir sonuc.
      Boolean(cookieDomain());
    const hedef = koprulu ? appKokAdresi(req) : null;
    if (hedef) return loginResponse(access, refresh, { yonlendir: hedef });
    const { anahtar, kod } = girisRedKarari(rol, yuzey);
    return NextResponse.json(
      {
        // KOD, ISTEMCININ NE CIZECEGINI belirler (orn. mobil-yalniz rolde
        // magaza baglantilari). Metne bakarak karar vermek, dil degisince
        // sessizce bozulurdu.
        error: { code: kod, message: istekMetni(req, anahtar) },
      },
      { status: 403 },
    );
  }
  return loginResponse(access, refresh);
}
