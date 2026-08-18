import { NextResponse } from "next/server";

import { API_BASE } from "@/lib/config";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * (P171 duzeltme) ADMIN-WEB SAGLIGI — API'YE BAGLI DEGIL.
 *
 * =========================================================================
 * NEDEN HER ZAMAN 200
 * =========================================================================
 * Bu uc `admin-web`in KENDI sagligini bildirir. API'ye ulasilamamasi
 * admin-web'in hasta oldugu anlamina GELMEZ: panel ayakta, sayfalar
 * ciziliyor, kullanici giris ekranini ve durum ekranini goruyor.
 *
 * 503 dondurseydi orkestratorumuz konteyneri sagliksiz sayar, yeniden
 * baslatir ve yuk dengeleyiciden duserdi — yani API kapali oldugu icin
 * PANELI DE kapatirdik. Bu turda duzelttigimiz kusurun tam olarak
 * kendisi.
 *
 * =========================================================================
 * AMA API DURUMU RAPOR EDILIR
 * =========================================================================
 * Teshis icin gerekli: "alan adi aciliyor ama veri gelmiyor" diyen bir
 * operator, tek bir cagriyla nedenini gorebilmeli. Bu, `backend`
 * `/health`indeki sema alaninin ayni ilkesi (P124): OLC, RAPOR ET,
 * KARAR VERME.
 *
 * KISA ZAMAN ASIMI: API kapaliysa baglanti denemesi dakikalarca asili
 * kalabilir; saglik ucunun kendisi yavaslarsa teshis araci teshis
 * edilemez hale gelir.
 */
const ZAMAN_ASIMI_MS = 2000;

export async function GET(): Promise<NextResponse> {
  let api: "erisilebilir" | "erisilemiyor" = "erisilemiyor";
  let ayrinti: string | null = null;

  try {
    const iptal = AbortSignal.timeout(ZAMAN_ASIMI_MS);
    const r = await fetch(`${API_BASE}/health`, {
      cache: "no-store",
      signal: iptal,
    });
    // 503 DE ERISILEBILIRDIR: API cevap veriyor ama kendini bozuk
    // biliyor (ornegin veritabani yok). Bu ikisi FARKLI arizalardir ve
    // ayirt edilmezse operator yanlis yerde arar.
    api = "erisilebilir";
    ayrinti = `HTTP ${r.status}`;
  } catch (e) {
    ayrinti = e instanceof Error ? e.name : null;
  }

  return NextResponse.json({ status: "ok", api, ayrinti });
}
