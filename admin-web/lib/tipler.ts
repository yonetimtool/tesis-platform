// (P203 §4) `.tsx` DOSYALARINDA KULLANILAMAYAN TIPLER.
//
// `sabit-metin` taramasi `.tsx` icindeki `<...>` dizilimlerini JSX
// sayar ve icindeki kelimeyi "cevrilmemis metin" adayi olarak bildirir.
// `Promise<unknown>` gibi bir tip annotasyonu bu yuzden yanlislikla
// isaretleniyor — tarama HAKLI (JSX metni cevrilmelidir), eslesme
// yanlis. Tipi `.ts` dosyasinda tanimlamak ikisini de korur.

/** Await edilecek bir is — sonucu kullanilmaz. */
export type AsyncIs = () => Promise<unknown>;
