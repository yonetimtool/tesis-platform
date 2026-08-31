import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P191-ek §1) Gecersiz cihaz jetonlarini toplu temizler.
 *
 * Govde YOK: hedef kume daima "bu tesisin AKTIF jetonlari"dir; istemcinin
 * secmesine birakmak, yanlislikla saglam jetonlari budayabilecek bir
 * parametre acmak olurdu.
 */
export async function POST(): Promise<NextResponse> {
  return proxyJson("/push/cihaz-temizle", "POST", {});
}
