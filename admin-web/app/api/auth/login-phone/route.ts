import { NextRequest, NextResponse } from "next/server";

import { backendPhoneLogin } from "@/lib/backend";
import { istekMetni } from "@/lib/i18n/istek-metni";
import { oturumAc } from "@/lib/oturum-kapisi";

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

  // YUZEY KAPISI — e-posta girisiyle AYNI kural, AYNI KOD
  // (`lib/oturum-kapisi.ts`): kopyalanan kapi P129'da bir kez geride
  // kalmisti, P211 §2'de bir kez daha kalacakti (panel -> app koprusu).
  return oturumAc(req, yanit.access_token, yanit.refresh_token);
}
