// (P104) SUNUCU TARAFI metin cozucu — BFF rota islerleri icin.
//
// `metin()` tarayici icindir: dili `document.cookie`den okur ve sunucuda
// `document` YOKTUR, yani her zaman VARSAYILAN dile duser. BFF rotalari
// kullaniciya DOGRUDAN metin dondurur (`{error:{message}}`) ve orada
// "her zaman Turkce" demek, ingilizce arayuzde Turkce hata gostermek
// demekti — P46/P54'un ayni sinifi, bu kez SUNUCUDA.
//
// Dil ISTEKTEN okunur: ayni cerez, ayni cozumleme.
import { DIL_COOKIE, VARSAYILAN_DIL, acceptLanguageCoz, dilMi } from "./diller";
import { SOZLUKLER, type SozlukAnahtari } from "./sozluk";

/** Istegin dilini coz: cerez > Accept-Language > varsayilan. */
export function istekDili(req: {
  cookies: { get(ad: string): { value: string } | undefined };
  headers: { get(ad: string): string | null };
}): keyof typeof SOZLUKLER {
  const cerez = req.cookies.get(DIL_COOKIE)?.value;
  if (dilMi(cerez)) return cerez;
  const kabul = req.headers.get("accept-language");
  return kabul ? acceptLanguageCoz(kabul) : VARSAYILAN_DIL;
}

/** Istegin dilinde sozluk metni. */
export function istekMetni(
  req: Parameters<typeof istekDili>[0],
  anahtar: SozlukAnahtari,
): string {
  return SOZLUKLER[istekDili(req)][anahtar];
}
