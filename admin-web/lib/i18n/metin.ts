// React DISI kod icin metin cozucu (tur 18).
//
// `useT()` yalniz bilesen icinde calisir; `lib/fetcher.ts` ve `lib/client.ts`
// gibi modullerde hata metni de gerekir. Bunlar tarayicida calistigi icin
// dili cookie'den okuyabilirler (bkz. `tarayiciDili`).
import { tarayiciDili } from "./diller";
import { SOZLUKLER, type SozlukAnahtari } from "./sozluk";

export function metin(anahtar: SozlukAnahtari): string {
  return SOZLUKLER[tarayiciDili()][anahtar];
}
