import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P247 §2) Sakinin "nereye, ne kadar, hangi kodla" odeyecegi — IBAN,
 * benzersiz odeme kodu, onerilen tutar. Web'de yalniz yoneticinin SAKIN
 * MODUNDA acilan Aidatim sayfasi okur (saf sakin web'e girmez, P129);
 * mobilin "Ode" ekraniyla ayni uc. Kapsam sunucuda (kendi borcu).
 */
export async function GET(): Promise<NextResponse> {
  return proxyJson("/me/odeme-bilgileri", "GET");
}
