import { NextRequest, NextResponse } from "next/server";

import { proxyJson } from "@/lib/backend";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Admin-web gorsel yukleme proxy'si (WP-G): FormData 'file' -> backend presign
// -> presigned PUT (sunucu tarafinda) -> {foto_key}. Token httpOnly cookie'de;
// istemci presigned URL'i ASLA gormez (SSRF/imza sizma yuzeyi kapali).
export async function POST(req: NextRequest): Promise<NextResponse> {
  const form = await req.formData().catch(() => null);
  const file = form?.get("file");
  if (!(file instanceof File)) {
    return NextResponse.json(
      { error: { code: "no_file", message: "Dosya bulunamadı." } },
      { status: 400 },
    );
  }
  const contentType = file.type || "application/octet-stream";

  // 1) Backend'den presign (auth cookie ile — mevcut BFF deseni).
  const presignRes = await proxyJson("/uploads/presign", "POST", {
    content_type: contentType,
    dosya_adi: file.name,
  });
  if (!presignRes.ok) return presignRes; // hata + olasi cookie rotasyonu aynen
  const ticket = (await presignRes.json()) as {
    foto_key: string;
    upload_url: string;
  };

  // 2) Presigned URL'e sunucu tarafindan PUT (imza icin dogru Content-Type).
  try {
    const put = await fetch(ticket.upload_url, {
      method: "PUT",
      headers: { "Content-Type": contentType },
      body: Buffer.from(await file.arrayBuffer()),
      cache: "no-store",
    });
    if (!put.ok) {
      return NextResponse.json(
        { error: { code: "upload_failed", message: "Görsel yüklenemedi." } },
        { status: 502 },
      );
    }
  } catch {
    return NextResponse.json(
      { error: { code: "upload_failed", message: "Görsel yüklenemedi." } },
      { status: 502 },
    );
  }

  // 3) foto_key doner; presign sirasinda olasi cookie rotasyonunu koru.
  const out = NextResponse.json({ foto_key: ticket.foto_key });
  presignRes.cookies.getAll().forEach((c) => out.cookies.set(c));
  return out;
}
