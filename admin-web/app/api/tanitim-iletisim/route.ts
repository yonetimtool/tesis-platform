import { NextRequest, NextResponse } from "next/server";

import { API_BASE } from "@/lib/config";

// (P127.2) Tanitim formu — PUBLIC uc, oturum YOK.
//
// `proxyJson` KULLANILMAZ: o yardimci oturum cerezlerini okur ve 401'de
// yenileme akisini tetikler. Burada kimlik yoktur; istegi oldugu gibi
// iletmek dogru olan. Ziyaretcinin IP'si `X-Forwarded-For` ile TASINIR —
// hiz siniri sunucuda IP basinadir ve olmadan tum ziyaretciler tek bir
// sayaci (BFF'in IP'si) paylasirdi.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.text();
  const iletilenIp =
    req.headers.get("x-forwarded-for") ??
    req.headers.get("x-real-ip") ??
    "";
  const res = await fetch(`${API_BASE}/public/tanitim-iletisim`, {
    // FETCH-DENETIMSIZ: bu bir VEKILDIR — yukari akisin durumu ISTEMCIYE
    // AYNEN iletilir (asagida `status: res.status`). `res.ok` denetleyip
    // kendi hatamizi uretmek, sunucunun 429 (hiz siniri) ve 422
    // (dogrulama) cumlelerini YUTARDI; kullanici "gonderilemedi" der ama
    // NEDENINI ogrenemezdi.
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(iletilenIp ? { "X-Forwarded-For": iletilenIp } : {}),
      // Hata metni ISTEGIN DILINDE gelsin (sunucu bu basliga bakar).
      ...(req.headers.get("accept-language")
        ? { "Accept-Language": req.headers.get("accept-language") as string }
        : {}),
    },
    body,
    cache: "no-store",
  });
  const metin = await res.text();
  return new NextResponse(metin || "{}", {
    status: res.status,
    headers: { "Content-Type": "application/json" },
  });
}
