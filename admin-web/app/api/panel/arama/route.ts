import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P154 / Asama 6.3) Global arama vekili.
//
// SUZGEC BURADA YOK ve olmamali: yetki SUNUCUDA uygulanir (rol kumeleri
// ilgili routerlardan okunur). Vekilde suzmek, veriyi tarayiciya
// GONDERIP saklamak — yani hic suzmemek — olurdu.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const q = req.nextUrl.searchParams.get("q") ?? "";
  return proxyJson(`/arama?q=${encodeURIComponent(q)}`, "GET");
}
