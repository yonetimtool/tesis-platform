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
import { istekMetni } from "@/lib/i18n/istek-metni";
import { tokenRolu } from "@/lib/rol-token";
import { girisRedKarari, konakYuzeyi, rolYuzeyeGirebilir } from "@/lib/yuzey";

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
