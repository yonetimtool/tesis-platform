import { NextResponse } from "next/server";

import { anonimGet } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P154 / Asama 4) Hangi sosyal giris dugmeleri cizilecek?
//
// KIMLIK GEREKTIRMEZ: giris ekraninda, oturum acilmadan cagrilir.
// Yapilandirilmamis bir saglayiciyi dugme olarak gostermek, kullaniciyi
// KESIN BASARISIZ bir yola sokmak olurdu.
export async function GET(): Promise<NextResponse> {
  return anonimGet("/auth/oauth/saglayicilar");
}
