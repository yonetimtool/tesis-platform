import { NextResponse } from "next/server";

/**
 * (P177) BFF — TARAYICI BACKEND'E DOGRUDAN GITMEZ.
 *
 * =========================================================================
 * NEDEN BFF, NEDEN DOGRUDAN CAGRI DEGIL
 * =========================================================================
 * Uc sebep, ucu de olculebilir:
 *
 *  1. IP ADRESI. Sartname §4 onaylarin "zaman damgasi + IP" ile
 *     saklanmasini istiyor. Tarayici kendi IP'sini BILEMEZ; onu yalniz
 *     sunucu gorur. Onay kaydinin ispat degeri de buna bagli (KVKK'da
 *     ispat yukumlulugu veri sorumlusundadir).
 *  2. KOKEN. Backend'i tarayiciya acmak, tanitim alan adi icin yeni bir
 *     CORS kokeni tanimlamak demekti. Panel de ayni sebeple BFF
 *     kullaniyor; iki yuzey ayni deseni izler.
 *  3. IC AG. `API_BASE_URL` compose ic agindaki `http://api:8000`;
 *     tarayicidan zaten erisilemez.
 *
 * =========================================================================
 * HATA GOVDESI OLDUGU GIBI GECER
 * =========================================================================
 * Backend'in `{kod, mesaj}` govdesi yeniden yazilmadan iletilir. Burada
 * genel bir "bir hata olustu" uretmek, kullanicinin gordugu metni
 * backend'in soyledigi seyden KOPARIRDI — P175'te tam olarak bu sinif
 * bir kusur olculdu (sahte hata metni).
 */
const TABAN = process.env.API_BASE_URL ?? "http://api:8000";

/**
 * BFF'IN KENDI HATASI DA BACKEND'IN ZARFIYLA doner:
 * `{ "error": { "code": ..., "message": ... } }`.
 *
 * NEDEN ONEMLI: istemci tek bir okuma yolu bilmeli. Iki farkli zarf
 * (biri backend'den, biri BFF'ten) olsaydi, form hangisinin geldigini
 * her cagrida sinamak zorunda kalir ve biri unutuldugunda kullanici BOS
 * bir hata kutusu gorurdu — P175'te olculen sinif.
 */
export function hataZarfi(
  durum: number,
  kod: string,
  mesaj: string,
): NextResponse {
  return NextResponse.json({ error: { code: kod, message: mesaj } }, { status: durum });
}

/** Ters vekil arkasindaki GERCEK istemci adresi. */
export function istemciIp(basliklar: Headers): string | null {
  const xff = basliklar.get("x-forwarded-for");
  if (xff) {
    // Ilk deger EN DIS istemcidir; sonrakiler vekil zinciridir.
    const ilk = xff.split(",")[0]?.trim();
    if (ilk) return ilk;
  }
  return basliklar.get("x-real-ip");
}

export async function backendeGonder(
  yol: string,
  govde: unknown,
  ekBasliklar: Record<string, string> = {},
): Promise<NextResponse> {
  let yanit: Response;
  try {
    yanit = await fetch(`${TABAN}${yol}`, {
      method: "POST",
      headers: { "content-type": "application/json", ...ekBasliklar },
      body: JSON.stringify(govde),
      cache: "no-store",
    });
  } catch {
    // SESSIZ BASARI YOK: API'ye ULASILAMADIGINI soyleriz. "Kaydınız
    // alındı" demek, alinmamis bir kaydi alinmis gostermek olurdu.
    return hataZarfi(
      502,
      "sunucuya_ulasilamadi",
      "Sunucuya ulaşılamadı. Lütfen birazdan tekrar deneyin.",
    );
  }

  const metin = await yanit.text();
  const tip = yanit.headers.get("content-type") ?? "";
  if (!tip.includes("application/json")) {
    return hataZarfi(
      yanit.ok ? 502 : yanit.status,
      "beklenmeyen_yanit",
      "Sunucudan beklenmeyen bir yanıt geldi.",
    );
  }
  return new NextResponse(metin, {
    status: yanit.status,
    headers: { "content-type": "application/json" },
  });
}
