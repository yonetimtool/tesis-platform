// TUR 61 — `/tenants/[id]` icin CALISMA ANINDA tesis kimligi cozucu.
//
// Envanter (tur 49, C maddesi) 26 sayfanin 1'inin hicbir surus listesinde
// olmadigini yaziyordu: `/tenants/[id]`. Sebep basit — dinamik rota, sabit bir
// yol yazilamiyor. Cozum: surus listesine `/tenants/:id` yer tutucusu yazilir,
// oturum acildiktan sonra bu modul gercek bir kimlikle degistirir.
//
// KURULUM tamamlanmis bir tesis secilir: yer tutucu ("(Kurulum bekliyor)")
// tesisin detay sayfasi yonetici formunu ve tarihleri cizmez, yani olcum zayif
// kalir. Boyle bir tesis yoksa ilk kayit kullanilir.

/** @returns {Promise<string[]>} `:id` yer tutucusu cozulmus sayfa listesi. */
export async function tesisYollariCoz(ctx, KOK, sayfalar) {
  if (!sayfalar.some((y) => y.includes(":id"))) return sayfalar;
  const kimlik = await tesisKimligi(ctx, KOK);
  // Kimlik cozulemezse yer tutucu yollar ATILIR — uydurma bir id ile 404
  // sayfasini olcup "temiz" demek, olcmemekten daha kotudur.
  return kimlik
    ? sayfalar.map((y) => y.replace(":id", kimlik))
    : sayfalar.filter((y) => !y.includes(":id"));
}

/** OLCULMEYE DEGER bir tesisin kimligi.
 *
 * TUR 62 DUZELTMESI: ilk surum "kurulum tamamlanmis ilk tesis"i seciyordu.
 * Tur 61'de veritabanindaki 100 test artigi silinince aday kumesi degisti ve
 * surus YONETICISI OLMAYAN bir tesise dustu; detay sayfasi neredeyse bos
 * ciziliyordu ve `okuma-sirasi-surusu` hakli olarak "yalniz 2 metin ogesi —
 * olcum bos" dedi. Yani secim veritabanindaki tesadufe bagliydi.
 *
 * Simdi adaylarin DETAYI okunur ve YONETICISI OLAN ilk tesis secilir: o sayfa
 * yonetici kartini, telefonu ve durum rozetlerini cizer. Boyle biri yoksa
 * kurulumu tamamlanmis, o da yoksa ilk kayit kullanilir. */
export async function tesisKimligi(ctx, KOK) {
  try {
    const r = await ctx.request.get(`${KOK}/api/tenants`);
    if (!r.ok()) return null;
    const items = (await r.json()).items ?? [];
    if (items.length === 0) return null;
    // En cok 8 aday yoklanir (tam liste yuzlerce olabilir).
    for (const t of items.slice(0, 8)) {
      const d = await ctx.request.get(`${KOK}/api/tenants/${t.id}`);
      if (!d.ok()) continue;
      const govde = await d.json();
      if (govde?.yonetici) return t.id;
    }
    return (items.find((t) => t.kurulum_tamamlandi) ?? items[0]).id;
  } catch {
    return null;
  }
}
