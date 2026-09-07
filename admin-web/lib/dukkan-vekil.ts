import { NextResponse } from "next/server";

/**
 * (DUKKAN F6) DUKKAN KAMU UÇLARINA BFF VEKİLİ.
 *
 * =========================================================================
 * KİMLİK BAŞLIĞI İLETİLMİYOR — VE BU BİLİNÇLİ
 * =========================================================================
 * Dukkan'ın arama/profil uçları `security: []`. Yöneticinin Yönetiyor
 * jetonunu oraya iletmek İKİ SEBEPLE yanlış olurdu:
 *
 *   1. Yönetiyor jetonu Dukkan uçlarında GEÇERSİZ (`tur: "dukkan"`
 *      iddiası yok) — 401 alırdı.
 *   2. Gereksiz: uç zaten kimliksiz. Jeton göndermek, kimliği ihtiyaç
 *      olmayan bir yere taşımak olurdu.
 *
 * Mobilde aynı ayrım `AuthInterceptor.dukkanJetonu` ile çözülmüştü;
 * burada gereken şey daha basit: jetonu HİÇ göndermemek.
 */
const TABAN = process.env.API_BASE_URL ?? "http://api:8000";

export async function vekilGet(
  istek: Request,
  yol: string,
): Promise<NextResponse> {
  const sorgu = new URL(istek.url).search;
  let yanit: Response;
  try {
    yanit = await fetch(`${TABAN}${yol}${sorgu}`, {
      headers: { accept: "application/json" },
      cache: "no-store",
    });
  } catch {
    // SESSİZ BAŞARISIZLIK YOK: boş liste döndürmek, servis çökmüşken
    // yöneticiye "bölgende işletme yok" demek olurdu.
    return NextResponse.json(
            // MESAJ INGILIZCE DEGIL ANAHTAR: istemci `code`u okuyup KENDI
      // dilinde metin uretir. Buraya Turkce metin yazmak, 7 dilli bir
      // urunde dili SUNUCUDA sabitlemek olurdu — i18n taramasi bunu
      // dogru sekilde yakaladi.
      { error: { code: "dukkan_erisilemedi", message: "dukkan_erisilemedi" } },
      { status: 502 },
    );
  }
  const metin = await yanit.text();
  try {
    return NextResponse.json(JSON.parse(metin), { status: yanit.status });
  } catch {
    return NextResponse.json(
      { error: { code: "dukkan_gecersiz_yanit", message: "dukkan_gecersiz_yanit" } },
      { status: 502 },
    );
  }
}
