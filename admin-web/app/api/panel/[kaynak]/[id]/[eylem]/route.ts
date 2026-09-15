import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";
import { okumaYolu, yazmaYolu } from "@/lib/panel-vekil";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const YOK = NextResponse.json({ error: { code: "not_found" } }, { status: 404 });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * (P192) UC-EYLEM VEKILI — `POST /api/panel/{kaynak}/{id}/{eylem}`.
 *
 * =====================================================================
 * NEDEN GENEL BIR ROTA (ve neden eylem yine BEYAZ LISTE)
 * =====================================================================
 * P189'da `iptal` icin AYRI bir dosya acilmisti; P192 uc eylem daha
 * getirdi (`ertele`, `onayla`, `reddet`). Her biri icin ayri dosya
 * acmak, ayni on satiri dorduncu kez kopyalamak ve besincisini
 * unutunca yine 405 almak demekti — bu tam olarak
 * `docs/` notlarindaki "BFF eksik rota" sinifi.
 *
 * Ama eylem adi ISTEMCIDEN geldigi icin BEYAZ LISTE sart: serbest
 * birakmak, `.../{id}/../../users` gibi bir parcanin backend yoluna
 * sizmasi demekti (kaynak beyaz listesinin varlik sebebiyle ayni).
 */
const EYLEMLER = new Set([
  // (P189) Finansal hareketi ters kayitla iptal et.
  "iptal",
  // (P192 §2.3) Onay bekleyen hareketi onayla / reddet.
  "onayla",
  "reddet",
  // (P192 §4.1) Aidat planinin bir donemini atla.
  "ertele",
  // (P193 §3) Yanlis yazilmis tahakkuku ters kayitla duzelt. Uc P192'den
  // beri var; panelde dugmesi yoktu.
  "ters-kayit",
]);

export async function POST(
  req: NextRequest,
  { params }: { params: { kaynak: string; id: string; eylem: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  if (!EYLEMLER.has(params.eylem)) return YOK;
  const kok = yazmaYolu(params.kaynak) ?? okumaYolu(params.kaynak);
  if (!kok) return YOK;
  const body = await req.json().catch(() => ({}));
  return proxyJson(`${kok}/${params.id}/${params.eylem}`, "POST", body);
}

/**
 * (P237 §3) OKUNABILIR ALT KAYNAKLAR — `GET /api/panel/{kaynak}/{id}/{alt}`.
 *
 * =====================================================================
 * NEDEN AYRI DOSYA ACILMADI
 * =====================================================================
 * Ilk deneme `app/api/panel/anketler/[id]/oylar/route.ts` idi ve
 * `bff-yol-eslesmesi` kilidi onu CURUTTU: statik `anketler` klasoru
 * acmak, `/api/panel/anketler` isteginin genel `[kaynak]` vekiline
 * DUSMESINI engelliyor (Next statik segmenti once cozer ve geri
 * donmez) — yani anket LISTESI ve OLUSTURMA 404 olurdu.
 *
 * Beyaz liste yine SART: alt kaynak adi istemciden geliyor ve serbest
 * birakmak `.../{id}/../../users` gibi bir parcanin backend yoluna
 * sizmasi demekti (EYLEMLER ile ayni gerekce).
 */
const OKUNABILIR_ALT = new Set([
  // Kim neye oy verdi — ANONIM ankette arka uc 409 doner (veri YOK).
  "oylar",
]);

export async function GET(
  req: NextRequest,
  { params }: { params: { kaynak: string; id: string; eylem: string } },
): Promise<NextResponse> {
  if (!UUID.test(params.id)) return YOK;
  if (!OKUNABILIR_ALT.has(params.eylem)) return YOK;
  const kok = okumaYolu(params.kaynak);
  if (!kok) return YOK;
  return proxyJson(
    `${kok}/${params.id}/${params.eylem}${req.nextUrl.search}`,
    "GET",
  );
}
