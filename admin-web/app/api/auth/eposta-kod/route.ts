import { NextRequest, NextResponse } from "next/server";

import { backendGiris } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P172 §5) E-POSTA KODU — iste / dogrula.
 *
 * =========================================================================
 * TEK ROTA, IKI ADIM
 * =========================================================================
 * `?adim=iste` ve `?adim=dogrula`. Iki ayri dosya acmak, ayni kimlik
 * oncesi kurallari (oturum cerezi TASINMAZ, yanit oldugu gibi gecer) iki
 * yerde tutmak olurdu.
 *
 * OTURUM CEREZI TASINMAZ: kullanicinin HENUZ oturumu yok. `proxyJson`
 * cerez okur ve gerektiginde jeton yeniler — burada ikisi de anlamsiz.
 *
 * DOGRULAMA BASARILIYSA CEREZLER KURULUR: parolali giris yolunun aynisi;
 * jetonlar httpOnly cerezde durur, istemci ASLA gormez.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const adim = req.nextUrl.searchParams.get("adim");
  if (adim !== "iste" && adim !== "dogrula") {
    return NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const body = await req.json().catch(() => ({}));
  return backendGiris(
    adim === "iste"
      ? "/auth/giris/eposta-kod-iste"
      : "/auth/giris/eposta-kod-dogrula",
    body,
    // YALNIZ dogrulama adimi token uretir; isteme adimi bilgisiz bir
    // yanit doner ve cerez kurmaz.
    adim === "dogrula",
  );
}
