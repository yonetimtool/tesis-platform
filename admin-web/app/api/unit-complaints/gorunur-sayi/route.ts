import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** (P222 §1) Panodaki "Şikayet Haritası" rozetinin sayisi.
 *
 * LISTE UCUNUN `meta.total` DEGERI DEGIL: o uc `sikayet_harita_saat`
 * penceresini uygulamaz ve rozet, tikladiginda acilan haritadan FARKLI
 * bir sayi gosterirdi (mobilde olculen kusur birebir buydu). */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/unit-complaints/gorunur-sayi", "GET");
}
