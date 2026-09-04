import { NextRequest, NextResponse } from "next/server";
import { istekMetni } from "@/lib/i18n/istek-metni";

import { backendLogin } from "@/lib/backend";
import { oturumAc } from "@/lib/oturum-kapisi";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P212 §1) GIRIS VEKILI — SOZLESME `kimlik` + `password`.
 *
 * =========================================================================
 * OLCULEN KUSUR: ARAYUZ P205'E GECMISTI, VEKIL GECMEMISTI
 * =========================================================================
 * Form `{kimlik, password}` gonderiyor (tek alan: e-posta VEYA telefon),
 * bu rota ise HALA eski sozlesmeyi (`{tenant_slug, email, password}`)
 * dogruluyordu ve `tenant_slug` bos oldugu icin istek BACKEND'E HIC
 * GITMEDEN 400 "Tesis kodu, e-posta ve parola zorunlu." donuyordu.
 *
 * Yani web'de parolayla giris, kimlik ne olursa olsun (telefon da
 * e-posta da) KIRIKTI; mobilde ayni akis calisiyordu cunku o dogrudan
 * backend'e gidiyor. Backend ZATEN dogruydu (`LoginRequest.kimlik`,
 * slug opsiyonel, cok tesiste 409).
 *
 * `tenant_slug` ARTIK ZORUNLU DEGIL ve giriste SORULMAZ: yalnizca
 * kullanici tesis SECTIGINDE ikinci cagrida dolar.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  const body = (await req.json().catch(() => ({}))) as {
    kimlik?: string;
    /** Eski istemciler (ve eski testler) `email` gonderiyordu. */
    email?: string;
    password?: string;
    tenant_slug?: string;
  };
  const kimlik = (body.kimlik ?? body.email ?? "").trim();
  if (!kimlik || !body.password) {
    return NextResponse.json(
      { error: { code: "validation_error", message: istekMetni(req, "girisAlanZorunlu") } },
      { status: 400 },
    );
  }

  const { ok, status, data } = await backendLogin({
    kimlik,
    password: body.password,
    ...(body.tenant_slug ? { tenant_slug: body.tenant_slug } : {}),
  });

  if (!ok) {
    return NextResponse.json(
      data ?? { error: { code: "error", message: istekMetni(req, "girisBasarisiz") } },
      { status },
    );
  }

  const tokens = data as { access_token: string; refresh_token: string };

  // (P126.1) KAPI ARTIK YUZEYE GORE.
  //
  // `panel.*` platform sahibinindir; `app.*` tesis rollerinindir. Ayni Next
  // uygulamasi iki alan adindan sunuldugu icin karar KONAKTAN verilir
  // (bkz. infra/Caddyfile ve lib/yuzey.ts).
  //
  // BU BIR UX KAPISIDIR, GUVENLIK SINIRI DEGIL: gercek yetki her istekte
  // backend RBAC'ta zorlanir (contracts/auth.md §4). Ama yanlis yuzeye
  // giren kullaniciya isini yapamayacagi bir kabuk gostermek "sistem bozuk"
  // izlenimi uretir — kapi bunu onler ve NEDENINI soyler.
  // (P211 §2) KAPI ARTIK TEK YERDE (`lib/oturum-kapisi.ts`). Buradaki
  // kopya, panele dusen yoneticiyi app.*'a tasiyan KOPRUYU gormuyordu:
  // ayni kural iki dosyada yasarsa biri her zaman geride kalir (P129'da
  // olculmustu, yine oldu).
  return oturumAc(req, tokens.access_token, tokens.refresh_token);
}
