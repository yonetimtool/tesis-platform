import type { Dil } from "@/lib/i18n/diller";

// (P113) HUKUKI BELGELER — gizlilik politikasi + kullanim kosullari.
//
// NEDEN SOZLUKTE DEGIL: `lib/i18n/sozluk` ARAYUZ dizgeleridir (dugme,
// etiket, hata). Bunlar BELGEDIR: bolumlu, uzun ve **hukuken baglayici**
// bir metin. Sozluge koymak, 40 satirlik paragraflari dugme etiketleriyle
// ayni dosyaya doldurmak ve `SozlukAnahtari` tipini okunmaz kilmak olurdu.
//
// KAYNAK DIL TURKCE'DIR ve **baglayici surum odur** (`kaynakBaglayici`).
// Diger diller bilgilendirme amaclidir — cok dilli hizmet sozlesmelerinde
// standart olan yol budur ve hukukcu incelemesi (Kerem, sonra) yalniz TR
// metne yapilacak.
export interface Bolum {
  baslik: string;
  paragraflar: string[];
}

export interface Belge {
  baslik: string;
  // "Son guncelleme" satirinin METNI (tarih dahil) — bicimleme dile gore
  // degisir; ISO tarih gostermek okuyucuya bir sey anlatmazdi.
  guncelleme: string;
  giris: string;
  bolumler: Bolum[];
  // Turkce disi surumlerde gosterilen "baglayici surum TR'dir" uyarisi;
  // TR'de bos birakilir.
  kaynakBaglayici: string;
}

export type BelgeSeti = Record<Dil, Belge>;
