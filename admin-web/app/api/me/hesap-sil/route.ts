import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P167 §1.7) SELF-SERVIS HESAP SILME — vekil.
 *
 * Uc (`POST /me/hesap-sil`) P112'de MOBIL icin acilmisti (App Store
 * 5.1.1(v)) ve panelde karsiligi YOKTU: web'den giren bir yonetici
 * hesabini ancak telefonunu acarak silebiliyordu. Brief profil menusune
 * "Hesabimi sil" koydugu icin vekil de bu turda acildi.
 *
 * YENIDEN KIMLIK DOGRULAMA SUNUCUDA: govde `current_password` tasir ve
 * karari SUNUCU verir. Burada bir kontrol YAPILMAZ — istemcideki bir
 * kopya, sunucununkinden sapabilecek ikinci bir kural olurdu.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/me/hesap-sil", "POST", body);
}
