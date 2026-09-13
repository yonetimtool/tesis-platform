import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Platform admini: tum tesisleri listeler (cross-tenant). Backend
// require_role("admin") + list_all_tenants() SECURITY DEFINER ile calisir.
//
// (P226) SORGU DIZESI TASINIR — ve TASINMADIGI ICIN ARAMA PROD'DA HIC
// SUZMEDI.
//
// Eski imza `GET()` idi: istegi HIC ALMIYORDU, dolayisiyla `?q=oltu`,
// `?kurulum=false`, `?arsivli=true` tarayicidan BFF'e geliyor ve burada
// SESSIZCE DUSUYORDU. Backend suzgecsiz listeyi donduruyor, panel de
// sekiz tesisin hepsini gosteriyordu.
//
// OLCUM HATASI DA BURADAYDI: dev'de aramayi BACKEND UCUNA DOGRUDAN
// sorarak olcmustum (`http://localhost:8000/tenants?q=...`) ve
// "calisiyor" demistim. Web testi ise `fetch`i TARAYICI sinirinda
// taklit ediyordu, yani tarayici->BFF adimini olcuyor, BFF->backend
// adimini HIC gormuyordu. Iki olcum de dogruydu ve ARADAKI HALKA
// olculmemisti.
//
// BEYAZ LISTE, ham yeniden yayin DEGIL: BFF'in gelen her parametreyi
// koru korune iletmesi, ileride eklenen bir uc parametresini de
// (orn. `limit`) farkinda olmadan acmak olurdu (P213 §3 dersi).
const IZINLI_SORGU = ["q", "kurulum", "arsivli"] as const;

export async function GET(req: NextRequest): Promise<NextResponse> {
  const gelen = new URL(req.url).searchParams;
  const sorgu = new URLSearchParams();
  for (const ad of IZINLI_SORGU) {
    const deger = gelen.get(ad);
    if (deger !== null && deger !== "") sorgu.set(ad, deger);
  }
  const ek = sorgu.toString();
  return proxyJson(`/tenants${ek ? `?${ek}` : ""}`, "GET");
}

// Yeni tesis (isimsiz) + yoneticisini acar. Parola bossa gecici kod doner.
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/tenants", "POST", body);
}
