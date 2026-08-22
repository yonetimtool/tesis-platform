/**
 * (P177 §7) HATA SERIDI — BOS MESAJ HICBIR SEY CIZMEZ.
 *
 * =========================================================================
 * P175'IN KUSURU BURADA TEKRARLANMIYOR
 * =========================================================================
 * Panelde (`admin-web/components/ui/durumlar.tsx`) bu bilesenin ilk
 * surumu `mesaj` yokken de kart ciziyor ve genel bir "Veriler
 * yuklenemedi." metnine dusuyordu. Sonuc: 28 dosyada 39 cagri yeri
 * KALICI bir sahte hata kartI tasiyordu — kurulum sihirbazi veri dogru
 * geldigi hâlde her acilista hata gosteriyordu.
 *
 * BURADAKI KURAL DAHA DAR ve sartnamenin istedigi bicimde: `mesaj`
 * null, undefined, bos dizge ya da yalniz bosluk ise bilesen `null`
 * doner. "Hata var ama metni yok" diye bir durum YOKTUR — cagiran hata
 * metnini vermek zorundadir. Genel bir yedek metin BILEREK konmadi:
 * P175'teki sahte hatayi tam olarak o yedek uretiyordu.
 *
 * `role="alert"` yalniz GERCEKTEN cizildiginde DOM'a girer, yani ekran
 * okuyucu bos bir uyari bolgesi duyurmaz.
 */
export function HataDurumu({ mesaj }: { mesaj?: string | null }) {
  if (typeof mesaj !== "string" || mesaj.trim() === "") return null;
  return (
    <p
      role="alert"
      className="rounded-[10px] border border-hata/30 bg-hataZemin px-4 py-3 text-kucuk font-semibold text-hata"
    >
      {mesaj}
    </p>
  );
}
