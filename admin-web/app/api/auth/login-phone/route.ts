import { NextRequest, NextResponse } from "next/server";

import { backendPhoneLogin, loginResponse } from "@/lib/backend";
import { istekMetni } from "@/lib/i18n/istek-metni";
import { tokenRolu } from "@/lib/rol-token";
import {
  konakYuzeyi,
  girisRedKarari,
  rolYuzeyeGirebilir,
} from "@/lib/yuzey";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * TELEFONLA GIRIS — `app.*` (tesis calisma alani) icin.
 *
 * NEDEN AYRI BIR UC: `app.*` mobil uygulamanin web ikizidir ve tesis
 * kullanicilari mobilde TELEFON + PAROLA ile giriyor. Ayni kisiye web'de
 * tesis kodu + e-posta sormak, mobilde sorulmayan iki bilgiyi istemek
 * olurdu — ve `resident` hesaplarinin cogunda e-posta HIC YOK (sunucu
 * semasinda `email` sakinde opsiyoneldir).
 *
 * TENANT KODU YOK: telefon global benzersiz; tenant sunucuda numaradan
 * cozulur.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = (await req.json().catch(() => ({}))) as {
    phone?: string;
    password?: string;
  };
  if (!body.phone || !body.password) {
    return NextResponse.json(
      {
        error: {
          code: "validation_error",
          message: istekMetni(req, "girisAlanZorunlu"),
        },
      },
      { status: 400 },
    );
  }

  const { ok, status, data } = await backendPhoneLogin({
    phone: body.phone,
    password: body.password,
  });
  if (!ok) {
    return NextResponse.json(
      data ?? {
        error: { code: "error", message: istekMetni(req, "girisBasarisiz") },
      },
      { status },
    );
  }

  const yanit = data as {
    password_setup_required?: boolean;
    access_token?: string | null;
    refresh_token?: string | null;
  };

  // ILK GIRIS (gecici kod): sunucu oturum VERMEZ, yalniz `setup_token` doner.
  // Web'de parola belirleme ekrani YOK — bu yuzden sessizce "giris basarisiz"
  // demek yerine NE YAPILACAGI soylenir. Sessiz kalmak, dogru kodu giren
  // kullaniciya "parolan yanlis" dedirtirdi.
  if (yanit.password_setup_required || !yanit.access_token || !yanit.refresh_token) {
    return NextResponse.json(
      {
        error: {
          code: "password_setup_required",
          message: istekMetni(req, "girisParolaBelirlemeGerek"),
        },
      },
      { status: 409 },
    );
  }

  // YUZEY KAPISI — e-posta girisiyle AYNI kural (bkz. login/route.ts).
  // Telefonla giris `app.*` icindir; platform sahibi panele e-posta ile girer.
  const rol = tokenRolu(yanit.access_token);
  const yuzey = konakYuzeyi(req.headers.get("host"));
  if (!rolYuzeyeGirebilir(rol, yuzey)) {
    // (P129) UC AYRI DURUM, UC AYRI CUMLE — karar TEK YERDE (lib/yuzey.ts).
    // Iki giris rotasina kopyalanmisti; mutasyon denetimi telefon
    // rotasindaki dal bozuldugunda hicbir testin dusmedigini gosterdi.
    const { anahtar, kod } = girisRedKarari(rol, yuzey);
    return NextResponse.json(
      {
        error: {
          // KOD, ISTEMCININ NE CIZECEGINI belirler: mobil-yalniz rolde
          // giris ekrani magaza baglantilarini gosterir. Metne bakarak
          // karar vermek, dil degisince sessizce bozulurdu.
          code: kod,
          message: istekMetni(req, anahtar),
        },
      },
      { status: 403 },
    );
  }

  return loginResponse(yanit.access_token, yanit.refresh_token);
}
