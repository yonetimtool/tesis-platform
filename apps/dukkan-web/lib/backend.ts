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

/**
 * GENEL VEKIL — metot, govde, sorgu dizesi ve KIMLIK BASLIGI aktarilir.
 *
 * =========================================================================
 * `Authorization` NEDEN ILETILIYOR
 * =========================================================================
 * Dukkan jetonu TARAYICIDA durur ve her istekte BFF uzerinden backend'e
 * gecmek zorunda. Basligi iletmezsek her korumali cagri 401 alir —
 * ve bu, backend kusursuz calisirken web'in bozuk gorunmesi demek
 * (P173/P189'daki 405 sinifi ile ayni aile: kirilan ARADA kalan katman).
 *
 * =========================================================================
 * SORGU DIZESI DE GECER
 * =========================================================================
 * `?q=`, `?durum=`, `?limit=` gibi parametreler dusurulseydi arama ve
 * kuyruk suzgecleri SESSIZCE calismaz, "hep ayni sonuc geliyor" diye
 * teshis edilmesi zor bir kusur olurdu.
 *
 * =========================================================================
 * HATA GOVDESI OLDUGU GIBI GECER
 * =========================================================================
 * Backend'in `{error:{code,message}}` zarfi yeniden yazilmaz. Burada
 * genel bir "bir hata olustu" uretmek, kullanicinin gordugu metni
 * backend'in soyledigi seyden koparirdi (P175'te olculen kusur) —
 * ozellikle `basvuru_eksik:kategori,hizmet_alani` gibi EYLEME DONUK
 * hatalarda kullanici ne yapacagini bilemezdi.
 */
export async function backendeIlet(
  istek: Request,
  yol: string,
): Promise<NextResponse> {
  const gelen = new URL(istek.url);
  const hedef = `${TABAN}${yol}${gelen.search}`;

  const basliklar: Record<string, string> = { accept: "application/json" };
  const yetki = istek.headers.get("authorization");
  if (yetki) basliklar.authorization = yetki;

  const tur = istek.headers.get("content-type");
  let govde: string | undefined;
  if (istek.method !== "GET" && istek.method !== "HEAD") {
    const metin = await istek.text();
    if (metin) {
      govde = metin;
      basliklar["content-type"] = tur ?? "application/json";
    }
  }

  // Istemci IP'si: backend'in hiz siniri (`/auth/telefon/kod`) bunu okur.
  // Iletilmezse TUM ziyaretciler tek sayaci (BFF'in IP'si) paylasir ve
  // besinci kod isteginden sonra kayit HERKESE kapanirdi —
  // `apps/tanitim-web/app/api/iletisim/route.ts` ayni tuzagi kaydediyor.
  const ip = istek.headers.get("x-forwarded-for") ?? istek.headers.get("x-real-ip");
  if (ip) basliklar["x-forwarded-for"] = ip;

  let yanit: Response;
  try {
    yanit = await fetch(hedef, {
      method: istek.method,
      headers: basliklar,
      body: govde,
      cache: "no-store",
    });
  } catch {
    return hataZarfi(502, "backend_erisilemedi", "Servise ulaşılamadı.");
  }

  const metin = await yanit.text();
  if (!metin) return new NextResponse(null, { status: yanit.status });
  try {
    return NextResponse.json(JSON.parse(metin), { status: yanit.status });
  } catch {
    return hataZarfi(502, "backend_gecersiz_yanit", "Servisten geçersiz yanıt alındı.");
  }
}
