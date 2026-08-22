import { NextRequest, NextResponse } from "next/server";

import { backendeGonder, hataZarfi, istemciIp } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P177 §4) Yonetici kaydi — adim "tesis".
 *
 * Govde DOGRULANMADAN gecirilir: alan alan dogrulama BACKEND'dedir ve
 * burada ikinci bir sema tutmak, ikisinin ayrismasi demekti (bir alan
 * eklenince burasi sessizce dusururdu). BFF'in isi kimlik/koken ve IP —
 * icerik degil.
 *
 * IP + USER-AGENT ONAY KAYDI ICIN iletilir; tarayici bunlari kendisi
 * bildiremez.
 */
export async function POST(istek: NextRequest): Promise<NextResponse> {
  let govde: unknown;
  try {
    govde = await istek.json();
  } catch {
    return hataZarfi(400, "gecersiz_govde", "İstek okunamadı.");
  }
  const ip = istemciIp(istek.headers);
  const ajan = istek.headers.get("user-agent");
  return backendeGonder("/auth/kayit/yonetici-tesis", govde, {
    ...(ip ? { "x-istemci-ip": ip } : {}),
    ...(ajan ? { "x-istemci-ajan": ajan.slice(0, 300) } : {}),
  });
}
