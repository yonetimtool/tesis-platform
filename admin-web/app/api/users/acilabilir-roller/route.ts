import { NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

// (P130) Acilir listenin KAYNAGI. Statik segment `[id]`den ONCE eslesir
// (Next yonlendirmesi sabit segmenti onceler), yani `/users/{uuid}` yolunu
// golgelemez.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(): Promise<NextResponse> {
  return proxyJson("/users/acilabilir-roller", "GET");
}
