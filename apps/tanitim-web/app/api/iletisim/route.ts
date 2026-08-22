import { NextRequest, NextResponse } from "next/server";

import { backendeGonder, hataZarfi, istemciIp } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P177 §2) ILETISIM FORMU — MEVCUT UCA VEKIL.
 *
 * Backend ucu YENI DEGIL: `POST /public/tanitim-iletisim` P127.2'de
 * yazildi, `tanitim_iletisim` tablosuna SECURITY DEFINER fonksiyonla
 * yaziyor ve IP basina saatte 5 gonderim hiz siniri var. Ikinci bir
 * iletisim ucu acmak, ayni veriyi iki tabloya bolmek olurdu.
 *
 * IP BASLIGI ILETILIR: backend'in hiz siniri `X-Forwarded-For`un ilk
 * degerini okuyor. BFF'ten cikan istek ic agdan geldigi icin, baslik
 * eklenmezse TUM ziyaretciler tek bir sayaci (BFF'in IP'si) paylasir ve
 * besinci mesajdan sonra form herkese kapanirdi.
 */
export async function POST(istek: NextRequest): Promise<NextResponse> {
  let govde: unknown;
  try {
    govde = await istek.json();
  } catch {
    return hataZarfi(400, "gecersiz_govde", "İstek okunamadı.");
  }
  const ip = istemciIp(istek.headers);
  return backendeGonder("/public/tanitim-iletisim", govde, {
    ...(ip ? { "x-forwarded-for": ip } : {}),
  });
}
