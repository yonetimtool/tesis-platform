import { NextRequest, NextResponse } from "next/server";

import { anonimVekil } from "@/lib/backend";
import { oturumAc } from "@/lib/oturum-kapisi";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P155 §7) Davetle gelen kullanici PAROLA belirler; oturum acilir.
 *
 * TokenPair govdede DEGIL httpOnly cerezlere yazilir (set-password ile ayni
 * kural): jeton panelde JS'e asla gorunmez.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const yanit = await anonimVekil("/davet/parola", await req.json().catch(() => ({})));
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
