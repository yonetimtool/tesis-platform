// (P58) AD BULUNAMADIGINDA GOSTERILEN SEY.
//
// Arama listeleri (vardiya, nokta, kullanici, kategori, daire) ayri bir
// istekle gelir. O istek duserse ya da kayit listede yoksa, sayfalar
// `id.slice(0, 8)` yaziyordu — yani AD sutununda `3f2a91c8` gorunuyordu.
// Bu bir kimlik parcasidir ama ADA benzer: kullanici onu bir kod, bir
// daire numarasi ya da bir kisaltma sanabilir. Yanlis bilgi, bilgi
// yoklugundan kotudur.
//
// `#` oneki isaretler: bu bir KIMLIKTIR, ad degildir.
export function kisaKimlik(id: string): string {
  return `#${id.slice(0, 8)}`;
}
