// React DISI kod icin metin cozucu (tur 18).
//
// `useT()` yalniz bilesen icinde calisir; `lib/fetcher.ts` ve `lib/client.ts`
// gibi modullerde hata metni de gerekir.
//
// (P132.5) BURASI YEDI SOZLUGU ISTEMCIYE TASIYAN SON YOLDU. Modul
// `SOZLUKLER`i STATIK import ediyordu ve `fetcher.ts` uzerinden HER korumali
// sayfaya giriyordu: olculdu, rota basina ~122 KB. Artik sozluk import
// EDILMEZ; `I18nProvider` aktif sozlugu buraya YAYINLAR (tek yon: React ->
// React disi). Boylece istemci yalniz kullandigi dili tasir.
//
// SOZLUK HENUZ YAYINLANMAMISSA ANAHTAR DONER (bos dizge DEGIL): ilk cizimden
// once cagrilan bir hata metni, ekranda anahtar gosterir — sessizce bos
// kalmasindan iyidir ve testte gorunur.
import type { Sozluk, SozlukAnahtari } from "./sozluk";

let _aktif: Sozluk | null = null;

/** `I18nProvider` cagirir; React disi kod bundan sonra metni cozebilir. */
export function aktifSozluguAyarla(sozluk: Sozluk): void {
  _aktif = sozluk;
}

export function metin(
  anahtar: SozlukAnahtari,
  params?: Record<string, string | number>,
): string {
  const ham = _aktif ? _aktif[anahtar] : String(anahtar);
  // (P163 §2) PARAMETRE IKAMESI — `useT` ile AYNI kural (`{alan}`).
  //
  // Gerekce: govdesiz bir yanitta (405/500) kullaniciya durum kodu ve
  // referans gosterilecek; ikisi de metnin ICINE girer. Ayri bir
  // birlestirme yazmak, iki farkli ikame kurali demekti.
  if (!params) return ham;
  return ham.replace(/\{(\w+)\}/g, (tam, alan) =>
    alan in params ? String(params[alan]) : tam,
  );
}
