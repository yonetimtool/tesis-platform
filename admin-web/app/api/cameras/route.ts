import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P126.5 · P131) Kameralar — okuma + YONETIM.
 *
 * P126.5'te yonetim ACILMAMISTI: desteklenen-kaynak kurali mobilde
 * `CameraDraft` icinde yasiyordu ve TS'e ikinci kopya yazmak ayrisma
 * demekti. P131'de kural ORTAK VAKA DOSYASIYLA kilitlendi
 * (`contracts/kamera-url-kurali.json`; iki taraf da ayni dosyayi okuyan
 * testlere sahip), yani ayrisma artik SESSIZ degil — o yuzden acildi.
 *
 * Yetki BURADA DEGIL sunucuda: `POST/PATCH/DELETE /cameras` admin+yonetici
 * ister (routers/cameras.py). BFF yalniz iletir.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams({
    limit: sp.get("limit") ?? "50",
    offset: sp.get("offset") ?? "0",
  });
  // (P213 §6 DUZELTME) SUZGEC BURADA DUSUYORDU. §4'te Ozet sayfasi
  // `ana_ekranda=true` gondermeye baslamisti; bu rota yalnizca
  // limit/offset'i tasidigi icin suzgec BACKEND'E HIC ULASMIYOR, ozet
  // TUM kameralari cekiyordu. DOM testi istemci -> BFF adimini olcmustu,
  // BFF -> backend adimini degil (P200 dersi: taklit, olculen katmanin
  // ALTINA konmali). Beyaz liste: bilinmeyen parametre gecmez.
  for (const ad of ["ana_ekranda", "kayit_aktif"]) {
    const deger = sp.get(ad);
    if (deger !== null) qs.set(ad, deger);
  }
  return proxyJson(`/cameras?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/cameras", "POST", body);
}
