import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P170 §2) YASAL METNI OKUMA — TESIS YUZEYINDE KALDI.
//
// Yonetim panele tasindi; okuma tasinmadi ve tasinmamali: metin
// kullanicinin KENDI verisi hakkindadir, okuyamamak aydinlatmanin
// kendisini imkansiz kilardi. Backend'de rol suzgeci YOK (bilinen tum
// roller) — kapi oturumun kendisidir.
export async function GET(req: NextRequest): Promise<NextResponse> {
  const tur = req.nextUrl.searchParams.get("tur");
  // TUR BEYAZ LISTEDEN GECMEZ, SUNUCUDA DOGRULANIR: burada ikinci bir
  // liste tutmak, bir tur eklendiginde unutulacak bir kopya olurdu.
  // Sunucu bilinmeyen turu 422 ile reddediyor.
  return proxyJson(
    tur ? `/kvkk/metin?tur=${encodeURIComponent(tur)}` : "/kvkk/metin",
    "GET",
  );
}
