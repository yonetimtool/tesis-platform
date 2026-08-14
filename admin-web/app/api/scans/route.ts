import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P160 / Asama 5) OKUTMA RAPORU — `GET /scans`.
 *
 * UC YENI DEGIL: `backend/app/routers/scans.py` bu raporu bastan beri
 * sunuyordu (admin + yonetici). EKSIK OLAN BFF KOPRUSUYDU — yani panel
 * "hangi nokta bugun okutuldu" sorusunu soramiyordu. Rota sahnesi tam
 * bunu soruyor: bir noktanin "okutuldu" mu yoksa "bekliyor" mu oldugunu
 * ALARMDAN turetmek mumkun degil (alarm yalniz GECIKEN/ATLANAN icin
 * uretiliyor); okutulanlarin listesi ancak buradan gelir.
 *
 * TARIH SUZGECI GECIRILIR ama dogrulanmaz: sunucu `YYYY-MM-DD` bekliyor
 * ve gecersiz degeri kendisi reddediyor. Burada ikinci bir bicim kurali
 * yazmak, iki yerde iki farkli tanim demekti.
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  const tarih = sp.get("tarih");
  if (tarih) qs.set("tarih", tarih);
  // (P34) Yalniz konumsuz okutmalar — sunucudaki suzgecin aynisi.
  if (sp.get("konumsuz") === "true") qs.set("konumsuz", "true");
  const ek = qs.toString();
  return proxyJson(`/scans${ek ? `?${ek}` : ""}`, "GET");
}
