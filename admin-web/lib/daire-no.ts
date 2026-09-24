/**
 * (E2E 2026-09 / TESIS-16 + ANA-4) Tekil daire no ONIZLEMESI.
 *
 * Sunucu (`units.daire_no_kanonik`) yalniz rakamdan olusan numarayi toplu
 * olusturmayla ayni bicime getirir: blok "A" + "11" -> "A-11". Form bunu
 * KAYITTAN ONCE gostersin ki yonetici "11 yazdim, A-11 oldu" diye
 * sasirmasin. Kural sunucuda; burasi yalniz ayna (baska blok onekli
 * numaranin reddi sunucunun blok listesini bildigi icin orada kalir).
 */
export function daireNoOnizle(no: string, blok: string | null | undefined): string {
  const temiz = no.trim();
  const b = (blok ?? "").trim();
  if (!b) return temiz;
  return /^[0-9]+$/.test(temiz) ? `${b}-${temiz}` : temiz;
}
