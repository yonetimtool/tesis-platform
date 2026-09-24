import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";
import { oturumAc } from "@/lib/oturum-kapisi";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P154 / Asama 3) Parola belirleme — kaydin SON adimi.
 *
 * Sunucu tam bir token cifti doner; onu govdede istemciye vermek yerine
 * `loginResponse` ile httpOnly cerezlere yaziyoruz. Panelde jeton HICBIR
 * ZAMAN JS'e gorunmez (mevcut giris yollarinin aynisi); govdede dondurmek
 * o kurali yalniz bu ekran icin delerdi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil(
    "/auth/set-password",
    await req.json().catch(() => ({})),
  );
  if (!yanit.ok) return yanit;
  const govde = (await yanit.json()) as {
    access_token?: string;
    refresh_token?: string;
  };
  if (!govde.access_token || !govde.refresh_token) return yanit;
  // (E2E 2026-09) NORMAL GIRISLE AYNI ROL KAPISI. Onceden jeton dogrudan
  // cereze yaziliyordu: davetle kaydini tamamlayan mobil-yalniz rol
  // (tesis gorevlisi, guvenlik, sakin) web yonetici paneline aliniyor ve
  // bos menu + 403 veren kartlar goruyordu (P129 karari deliniyordu).
  // Kayit YINE TAMAMDIR (parola sunucuda kuruldu); kapi yalniz web
  // oturumunu acmaz ve `mobil_uygulama` koduyla magazaya yonlendirir.
  return oturumAc(req, govde.access_token, govde.refresh_token);
}
