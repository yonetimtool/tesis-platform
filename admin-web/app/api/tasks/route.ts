import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest): Promise<NextResponse> {
  const sp = req.nextUrl.searchParams;
  const qs = new URLSearchParams();
  qs.set("limit", sp.get("limit") ?? "20");
  qs.set("offset", sp.get("offset") ?? "0");
  // (P160) `tip` GECISI KALDIRILDI: `GET /tasks` boyle bir parametre
  // ALMIYOR (FastAPI bilinmeyeni yok sayar), yani bu satir istegi
  // buyutup hicbir sey yapmiyordu. Gorev tipi 087f33f'te dinamik
  // `kategori_id`ye cevrilmisti; o parametre asagida zaten geciyor.
  const aktif = sp.get("aktif");
  if (aktif === "true" || aktif === "false") qs.set("aktif", aktif);
  const atanan = sp.get("atanan_user_id");
  if (atanan) qs.set("atanan_user_id", atanan);
  // (P244 §8c) `kategori_id` ve `durum` BURADA DUSUYORDU.
  //
  // Sayfa ikisini de GONDERIYOR (`qs.set("kategori_id", ...)`,
  // `qs.set("durum", ...)`) ve arka uc ikisini de destekliyor
  // (`list_tasks`: kategori UUID veya "diger"; durum = atandi |
  // baslandi | tamamlandi | gecikti — P230 §4). Vekil ikisini de
  // gecirmiyordu, yani KATEGORI SUZGECI HICBIR SEY YAPMIYORDU:
  // kullanici bir kategori seciyor, liste degismiyordu.
  //
  // Ustelik sayfadaki yorum "SUZGEC ARTIK GERCEK" diyordu — arka uc
  // icin dogruydu, yol icin degil. Depoda dorduncu kez ayni kusur
  // sinifi (P173/P189/P213 + bu turda §6 ve §8a).
  for (const ad of ["kategori_id", "durum"] as const) {
    const v = sp.get(ad);
    if (v) qs.set(ad, v);
  }
  return proxyJson(`/tasks?${qs.toString()}`, "GET");
}

export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = await req.json().catch(() => ({}));
  return proxyJson("/tasks", "POST", body);
}
