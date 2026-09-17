import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P240 §1) BANA gelen ve kapanmamis alarmlar — tam ekran uyarinin kaynagi.
//
// AYRI KLASOR, `[id]` DEGIL: Next.js'te statik segment dinamik olani
// GOLGELER, yani `aktif` bir alarm kimligi sanilmaz. Ters sirada
// yazilsaydi `/panik/aktif` istegi `/panik/{id}`ye duser ve 404 alirdik
// (P237'de ayni tuzaga dusuldu).
export async function GET(): Promise<NextResponse> {
  return proxyJson("/panik/aktif", "GET");
}
