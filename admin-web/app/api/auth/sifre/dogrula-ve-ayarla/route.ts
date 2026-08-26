import { NextRequest, NextResponse } from "next/server";

import { backendGiris } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P181 Bölüm 2) ŞİFREMİ UNUTTUM — kod doğruysa yeni parolayı kur. Public
// (pre-auth): OTURUM AÇMAZ (jeton üretmez); kullanıcı yeni parolayla girer.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return backendGiris("/auth/sifre/dogrula-ve-ayarla", body, false);
}
