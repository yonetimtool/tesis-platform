import { NextRequest, NextResponse } from "next/server";

import { loginResponse, proxyJson } from "@/lib/backend";
import { istekMetni } from "@/lib/i18n/istek-metni";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.3) Self-servis parola degisimi — mevcut parola sunucuda dogrulanir.
 *
 * (P247 §4) PAROLA DEGISINCE TUM CIHAZLAR DUSER — BU CIHAZ DAHIL. Sunucu
 * bu ana kadarki butun jetonlari iptal edip YALNIZ bu istege taze bir cift
 * doner. Cifti cereze yazmazsak, eski (artik iptal) cerezle kalan bu sekme
 * bir sonraki istekte `/login`e duserdi. Jeton govdeye konmaz (giris
 * yolunun kurali); rol degismedigi icin yuzey kapisi gerekmez.
 */
export async function PATCH(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  const res = await proxyJson("/me/password", "PATCH", body);
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
  return loginResponse(veri.access_token, veri.refresh_token);
}
