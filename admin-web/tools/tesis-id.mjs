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
  let kimlik = null;
  try {
    const r = await ctx.request.get(`${KOK}/api/tenants`);
    if (r.ok()) {
      const items = (await r.json()).items ?? [];
      kimlik = (items.find((t) => t.kurulum_tamamlandi) ?? items[0])?.id ?? null;
    }
  } catch {
    kimlik = null;
  }
  // Kimlik cozulemezse yer tutucu yollar ATILIR — uydurma bir id ile 404
  // sayfasini olcup "temiz" demek, olcmemekten daha kotudur.
  return kimlik
    ? sayfalar.map((y) => y.replace(":id", kimlik))
    : sayfalar.filter((y) => !y.includes(":id"));
}
