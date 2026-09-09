import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P220 §4) SITE SAKINLERI — `/users`DEN AYRI UC, AYRI SORU.
 *
 * `/users` "kimin hesabi var ve rolu ne" sorusunu yanitliyor (tum
 * roller: admin, yonetici, guvenlik, denetci, sakin). Bu uc "KIM NEREDE
 * OTURUYOR" sorusunu yanitliyor ve `unit_no` + `blok` tasiyor —
 * `UserOut` tasimiyor.
 *
 * SUZGEC BEYAZ LISTEYLE TASINIYOR: gelen sorgu dizesini oldugu gibi
 * gecirmek, ileride eklenecek bir sunucu parametresini istemeden
 * disariya acardi. Yalniz bilinen ikisi geciyor.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  const q = sp.get("q");
  // EN AZ 2 KARAKTER kurali SUNUCUDA da var; burada da uygulamak
  // gereksiz bir istek turunu daha en basta kesiyor.
  if (q && q.trim().length >= 2) qs.set("q", q.trim());
  const blok = sp.get("blok");
  if (blok) qs.set("blok", blok);
  const ek = qs.toString();
  return proxyJson(`/residents${ek ? `?${ek}` : ""}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/residents", "POST", body);
}
