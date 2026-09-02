import { NextRequest, NextResponse } from "next/server";

import { loginResponse, proxyJson } from "@/lib/backend";
import { tokenRolu } from "@/lib/rol-token";
import { girisRedKarari, konakYuzeyi, rolYuzeyeGirebilir } from "@/lib/yuzey";
import { istekMetni } from "@/lib/i18n/istek-metni";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P203 §2) TESIS DEGISTIR — arka uc YENI JETON verir, BFF CEREZE YAZAR.
 *
 * =========================================================================
 * JETONLAR GOVDEYE KONMAZ
 * =========================================================================
 * Giris yolunun AYNI kurali: web'de jeton httpOnly cerezde durur.
 * Yanitta dondurmek, XSS'in oturumu tasimasina izin vermek olurdu.
 *
 * =========================================================================
 * YUZEY KAPISI BURADA DA UYGULANIR
 * =========================================================================
 * Yeni jetonun ROLU farklidir (kisi otekinde sakin olabilir). Kapiyi
 * yalniz giriste uygulamak, tesis degistirerek girilemeyecek bir yuzeye
 * DUSMEK demekti: kullanici `panel.*`ta sakin jetonuyla kalir ve her
 * ekranda 403 gorurdu — P126.1'de olculen kusurun aynisi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const govde = await req.json().catch(() => ({}));
  const res = await proxyJson("/me/tesis-degistir", "POST", govde);
  if (!res.ok) return res;

  const veri = (await res.json().catch(() => null)) as {
    access_token?: string;
    refresh_token?: string;
  } | null;
  if (!veri?.access_token || !veri.refresh_token) {
    return NextResponse.json(
      { error: { code: "error", message: istekMetni(req, "ortakHataOlustu") } },
      { status: 502 },
    );
  }

  const rol = tokenRolu(veri.access_token);
  const yuzey = konakYuzeyi(req.headers.get("host"));
  if (!rolYuzeyeGirebilir(rol, yuzey)) {
    const { anahtar, kod } = girisRedKarari(rol, yuzey);
    return NextResponse.json(
      { error: { code: kod, message: istekMetni(req, anahtar) } },
      { status: 403 },
    );
  }
  return loginResponse(veri.access_token, veri.refresh_token);
}
