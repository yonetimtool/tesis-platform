import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P191 §3) Kamera baglanti testi — kaydetmeden dene.
 *
 * Govde ALANLARI SECILEREK gecirilir: istemcinin gonderdigi her seyi
 * arka uca aktarmak, semanin `extra="forbid"` kapisina takilan sessiz
 * 422'ler uretirdi.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const govde = (await req.json().catch(() => ({}))) as {
    stream_url?: string;
    tur?: string;
    camera_id?: string | null;
    stream_kullanici?: string | null;
    stream_parola?: string | null;
  };
  // (E2E 2026-09 / GUVENLIK-15) Kimlik alanlari da BEYAZ LISTEDE: vekil
  // onlari dusurseydi duzenleme testi yine kimliksiz giderdi (P213 §4'teki
  // "BFF suzgeci dusurur" sinifi). Yalniz DOLU olanlar tasinir.
  const ek: Record<string, string> = {};
  for (const ad of ["camera_id", "stream_kullanici", "stream_parola"] as const) {
    const v = govde[ad];
    if (typeof v === "string" && v) ek[ad] = v;
  }
  return proxyJson("/cameras/test-baglanti", "POST", {
    stream_url: govde.stream_url ?? "",
    tur: govde.tur ?? "rtsp",
    ...ek,
  });
}
