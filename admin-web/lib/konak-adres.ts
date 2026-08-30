// (P191 §1) KONAK-OTESI YONLENDIRME ADRESLERI — TEK KAYNAK.
//
// OLCULEN KUSUR (prod): panel.yonetiyor.com/kayit -> middleware konak-otesi
// yonlendirme uretiyor ve adres `http://app.yonetiyor.com:3000/kayit`
// cikiyordu. Tarayici ERR_CONNECTION_TIMED_OUT: 3000 dis dunyaya KAPALI ve
// sema `http`. Kanit (Next 14.2, dev sunucu 3111 portunda, Host basligi
// panel.yonetiyor.com):
//
//   curl -H 'Host: panel.yonetiyor.com' http://127.0.0.1:3111/kayit
//   location: http://app.yonetiyor.com:3111/kayit      <-- IC PORT SIZDI
//
// IKI AYRI TUZAK VAR:
//   1) `req.nextUrl` ters vekilin ARKASINDAKI adrestir — Next onu dinlenen
//      konak/porttan kurar (`localhost:3000`), `Host` basligindan degil.
//      Ayni konak icinde bu gorunmez (Next ayni-origin yonlendirmeyi
//      GORELI yazar: `location: /login`), yalniz konak DEGISTIGINDE
//      mutlak adres uretilir ve ic port disari sizar.
//   2) `URL.prototype.host` ATAMASI PORTU SIFIRLAMAZ. WHATWG kuralina gore
//      `u.host = "app.example.com"` (portsuz dize) mevcut portu OLDUGU GIBI
//      BIRAKIR — `hostname` atamasi da ayni. Yani "konagi degistirdim"
//      demek portu temizlemek DEGILDIR.
//
// COZUM: konak-otesi hedef adresler ISTEKTEN DEGIL, ORTAM DEGISKENINDEN
// kurulur. Degisken yoksa (yerel gelistirme, test) iletilmis BASLIKLARDAN
// (`x-forwarded-proto` / `x-forwarded-host`) turetilir — `req.nextUrl`den
// ASLA. Her iki yolda da port ATILIR ve sema `https`e sabitlenir: bu
// adresler yalnizca gercek alan adlarinda (panel./app.) uretiliyor ve orada
// port YOKTUR.
//
// NEXT_PUBLIC_* ONEKI ZORUNLU: middleware edge calisma zamaninda kosar ve
// `process.env` orada DERLEME ANINDA gomulur. Public olmayan bir ad
// (`APP_ADRESI`) edge paketine girmez, calisma zamaninda `undefined` kalir
// ve sessizce yedege duserdik. Degiskenler compose'ta build arg olarak
// gecilir (infra/docker-compose.prod.yml).

/** Sondaki `/` atilmis, portsuz kok adres; gecersizse null. */
export function kokAdresNormalize(deger: string | null | undefined): string | null {
  const ham = (deger ?? "").trim();
  if (!ham) return null;
  let u: URL;
  try {
    u = new URL(ham);
  } catch {
    return null;
  }
  if (u.protocol !== "http:" && u.protocol !== "https:") return null;
  // PORT ATILIR: bu adresler ters vekilin ONUNDEKI kanonik adreslerdir.
  u.port = "";
  return `${u.protocol}//${u.hostname}`;
}

const YEREL = ["localhost", "127.0.0.1", "0.0.0.0", "::1", ""];

/** `panel.<alan>` -> `app.<alan>`; ilk etiket TAM `panel` degilse null. */
export function appKonagi(host: string | null | undefined): string | null {
  const h = (host ?? "").toLowerCase().split(":")[0];
  if (YEREL.includes(h)) return null;
  const [etiket, ...kalan] = h.split(".");
  if (etiket !== "panel" || kalan.length === 0) return null;
  return ["app", ...kalan].join(".");
}

/** `app.<alan>` -> `panel.<alan>`; ilk etiket TAM `app` degilse null. */
export function panelKonagi(host: string | null | undefined): string | null {
  const h = (host ?? "").toLowerCase().split(":")[0];
  if (YEREL.includes(h)) return null;
  const [etiket, ...kalan] = h.split(".");
  if (etiket !== "app" || kalan.length === 0) return null;
  return ["panel", ...kalan].join(".");
}

/**
 * Istegin GERCEK (vekil onundeki) konagi — `req.nextUrl` DEGIL.
 *
 * Oncelik `x-forwarded-host` > `host`. Caddy ikisini de iletir; ilki
 * zincirde birden fazla vekil varsa dogru olandir. Port ATILIR.
 */
export function istekKonagiHam(basliklar: Headers): string | null {
  const ham =
    basliklar.get("x-forwarded-host")?.split(",")[0]?.trim() ||
    basliklar.get("host")?.trim() ||
    "";
  return ham.toLowerCase() || null;
}

/** Aynisi ama PORTSUZ (yuzey siniflandirmasi ve konak esdegerleri icin). */
export function istekKonagi(basliklar: Headers): string | null {
  const h = istekKonagiHam(basliklar)?.split(":")[0];
  return h || null;
}

/**
 * AYNI KONAKTAKI mutlak adres — `req.nextUrl`den DEGIL, iletilmis
 * basliklardan.
 *
 * Next ayni-origin yonlendirmeleri bugun GORELI yaziyor (`location: /login`)
 * ve o yuzden ic portun buradan sizdigi GORULMEDI. Ama bu Next'in ic
 * normalizasyonuna bagli bir sanstir; adresi dogru kurup o sansa
 * dayanmiyoruz. PORT KORUNUR (yerel gelistirmede `localhost:3000` istemcinin
 * gercekten kullandigi adrestir), yalnizca konak-otesi adreslerde atilir.
 *
 * Baslik yoksa (bir URL'den kurulmus `NextRequest` — testler) null doner ve
 * cagiran `req.nextUrl.clone()` yedegini kullanir.
 */
export function ayniKonakAdresi(
  basliklar: Headers,
  yol: string,
  arama: string,
  varsayilanSema: string,
): string | null {
  const konak = istekKonagiHam(basliklar);
  if (!konak) return null;
  const proto = (basliklar.get("x-forwarded-proto")?.split(",")[0] ?? "").trim().toLowerCase();
  const sema = proto === "http" || proto === "https" ? proto : varsayilanSema.replace(":", "");
  const yolNormal = yol.startsWith("/") ? yol : `/${yol}`;
  return `${sema}://${konak}${yolNormal}${arama ?? ""}`;
}

export type KonakOtesiSecenek = {
  /** Ortam degiskeninden gelen kanonik kok adres (varsa kazanir). */
  ortamKok: string | null | undefined;
  /** Yedek turetme icin hedef konak (orn. `app.yonetiyor.com`). */
  yedekKonak: string | null;
  basliklar: Headers;
};

/**
 * Konak-otesi MUTLAK adres uretir; uretilemiyorsa null (cagiran yonlendirme
 * YAPMAZ ve eski davranisini surdurur).
 *
 * SONUC HICBIR ZAMAN PORT TASIMAZ — `tests/konak-adres.test.ts` bunu her
 * girdi bicimi icin dogruluyor.
 */
export function konakOtesiAdres(
  yol: string,
  arama: string,
  { ortamKok, yedekKonak, basliklar }: KonakOtesiSecenek,
): string | null {
  const kok = kokAdresNormalize(ortamKok) ?? yedekKokAdres(yedekKonak, basliklar);
  if (!kok) return null;
  const yolNormal = yol.startsWith("/") ? yol : `/${yol}`;
  return `${kok}${yolNormal}${arama ?? ""}`;
}

function yedekKokAdres(konak: string | null, basliklar: Headers): string | null {
  if (!konak) return null;
  const proto = (basliklar.get("x-forwarded-proto")?.split(",")[0] ?? "").trim().toLowerCase();
  // VARSAYILAN `https`: bu yedek YALNIZ gercek alan adlarinda calisir
  // (`appKonagi`/`panelKonagi` yerel konaklarda null doner) ve orada TLS
  // vardir. `http` uretmek, tarayiciyi bir kez daha 301'e sokardi.
  const sema = proto === "http" || proto === "https" ? proto : "https";
  return `${sema}://${konak.split(":")[0]}`;
}
