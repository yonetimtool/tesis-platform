import { NextResponse } from "next/server";

/**
 * BFF — TARAYICI BACKEND'E DOGRUDAN GITMEZ.
 *
 * =========================================================================
 * NEDEN BFF
 * =========================================================================
 * `apps/tanitim-web/lib/backend.ts` ile AYNI desen ve ayni gerekce:
 *
 *  1. KOKEN. Backend'i tarayiciya acmak, `dukkan.yonetiyor.com` icin yeni
 *     bir CORS kokeni tanimlamak demekti. Panel ve tanitim sitesi de BFF
 *     kullaniyor; ucuncu yuzey ayni deseni izler.
 *  2. IC AG. `API_BASE_URL` compose ic agindaki `http://api:8000`;
 *     tarayicidan zaten erisilemez.
 *  3. TEK OKUMA YOLU. Backend'in `{error:{code,message}}` zarfi yeniden
 *     yazilmadan iletilir. Burada genel bir "bir hata olustu" uretmek,
 *     kullanicinin gordugu metni backend'in soyledigi seyden KOPARIRDI —
 *     P175'te tam olarak bu sinif bir kusur olculdu.
 */
const TABAN = process.env.API_BASE_URL ?? "http://api:8000";

export function hataZarfi(
  durum: number,
  kod: string,
  mesaj: string,
): NextResponse {
  return NextResponse.json(
    { error: { code: kod, message: mesaj } },
    { status: durum },
  );
}

/** Backend'e GET vekili. Yanit govdesi ve durumu OLDUGU GIBI gecer. */
export async function backendenAl(yol: string): Promise<NextResponse> {
  let yanit: Response;
  try {
    yanit = await fetch(`${TABAN}${yol}`, {
      headers: { accept: "application/json" },
      // SEO sayfalari ISR ile onbelleklenir; BFF'in kendisi onbellege
      // ALMAZ. Iki katmanda onbellek, "hangi veri ne kadar bayat"
      // sorusunu okunarak yanitlanamaz kilardi.
      cache: "no-store",
    });
  } catch {
    // SESSIZ BASARISIZLIK YOK: bos liste dondurmek, backend cokmusken
    // kullaniciya "bu bolgede hic isletme yok" demek olurdu.
    return hataZarfi(502, "backend_erisilemedi", "Servise ulaşılamadı.");
  }

  const metin = await yanit.text();
  try {
    return NextResponse.json(JSON.parse(metin), { status: yanit.status });
  } catch {
    return hataZarfi(502, "backend_gecersiz_yanit", "Servisten geçersiz yanıt alındı.");
  }
}

/**
 * SUNUCU BILESENLERI icin dogrudan okuma (BFF rotasi uzerinden DEGIL).
 *
 * SSR/ISR sirasinda kendi BFF rotamiza HTTP istegi yapmak, sunucunun
 * kendine ag uzerinden baglanmasi olurdu: gercek bir atlama, ek gecikme
 * ve sifir kazanc. Sunucu zaten ic agda; dogrudan `api`ye gider.
 *
 * BFF rotalari TARAYICI icin var (arama kutusu, mahalle secici).
 */
export async function sunucudanAl<T>(yol: string, saniye = 3600): Promise<T | null> {
  try {
    const yanit = await fetch(`${TABAN}${yol}`, {
      headers: { accept: "application/json" },
      next: { revalidate: saniye },
    });
    if (!yanit.ok) return null;
    return (await yanit.json()) as T;
  } catch {
    return null;
  }
}
