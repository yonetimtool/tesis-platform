import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// (P243 §6d) Ilk giris turu gosterildi — kalici isaret.
//
// Govde YOK: isaretin tek bilgisi "gordu"dur ve sunucu damgayi kendisi
// basar. `localStorage` yerine hesapta durmasinin gerekcesi ucun
// sozlesmesinde (`openapi.yaml`): ofiste turu atlayan yonetici evdeki
// bilgisayarda onu yeniden gorurdu.
export async function POST(): Promise<NextResponse> {
  return proxyJson("/me/tur-goruldu", "POST", {});
}
